import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import '../models/landmark.dart';
import '../services/landmark_service.dart';
import '../services/geofence_service.dart';
import 'add_landmark_screen.dart';
import 'dart:ui' as ui;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../main.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final LandmarkService _service = LandmarkService();
  final GeofenceService _geofenceService = GeofenceService();
  final FlutterTts _flutterTts = FlutterTts();
  final MapController _mapController = MapController();
  List<Landmark> _loadedLandmarks = [];
  
  late Future<List<Landmark>> _future;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<CompassEvent>? _compassStream;
  final Set<String> _triggeredLandmarks = {};
  
  LatLng? _currentPosition; 
  double _heading = 0.0; // Dynamic device heading (degrees)
  List<LatLng> _routePoints = [];
  String? _routeDistance;
  bool _isSearchVisible = false;
  Landmark? _activeDestination; 
  
  bool _followUser = false; 
  Timer? _adminTimer;
  StreamSubscription? _taskDataSubscription; 

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'makheritage_bg_service',
        channelName: 'MakHeritage Location Tracking',
        channelDescription: 'Tracks location in the background to narrate nearby landmarks.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic, // Replaced String with Enum
          name: 'launcher',             // Removed 'ic_' since the prefix handles it
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  void _initForegroundTaskListener() {
    _taskDataSubscription = FlutterForegroundTask.receivePort?.listen((data) {
      if (data is! Map) return;

      final lat = data['lat'] as double?;
      final lng = data['lng'] as double?;

      if (lat != null && lng != null) {
        final position = Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );

        if (mounted) {
          setState(() {
            _currentPosition = LatLng(lat, lng);
          });

          if (_followUser) {
            _mapController.move(_currentPosition!, _mapController.camera.zoom);
          }

          if (_activeDestination != null) {
            _drawRouteTo(_activeDestination!);
          }
        }

        if (_loadedLandmarks.isNotEmpty) {
          _geofenceService.checkProximity(position, _loadedLandmarks, _handleProximityTrigger);
        }
      }
    });
  }

  static const LatLng _makerereCenter = LatLng(0.3315, 32.5675);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initTts();
    _initCompass();
    _initForegroundTask();
    _initForegroundTaskListener(); // ADDED
    _future = _service.fetchLandmarks().then((landmarks) {
      _loadedLandmarks = landmarks; // ADDED
      _startTracking(landmarks);
      return landmarks;
    });
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-GB");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _initCompass() {
    _compassStream = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      
      final double? direction = event.heading;
      if (direction != null) {
        setState(() {
          _heading = direction;
          
          // Smoothly spin the whole map if in locking follow mode
          if (_followUser && _currentPosition != null) {
            _mapController.rotate(360 - direction);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taskDataSubscription?.cancel(); // Replaced removeTaskDataCallback
    _positionStream?.cancel();
    _compassStream?.cancel();
    _flutterTts.stop();
    _adminTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      FlutterForegroundTask.stopService();
    }
  }

  Future<void> _startTracking(List<Landmark> landmarks) async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    }
    if (!await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.startService(
        notificationTitle: 'MakHeritage',
        notificationText: 'Tracking nearby landmarks...',
        callback: startCallback,
      );
    }
    // Request notification permission (Required for Android 13+)
    final NotificationPermission notificationPermissionStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Prevent the OS from aggressively killing the background task
    if (await FlutterForegroundTask.isIgnoringBatteryOptimizations == false) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    try {
      Position currentPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(currentPos.latitude, currentPos.longitude);
        });
      }
      _geofenceService.checkProximity(currentPos, landmarks, _handleProximityTrigger);
    } catch (e) {
      debugPrint("Could not get initial location: $e");
    }

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, 
      distanceFilter: 3, 
    );
    
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
        });
        
        if (_followUser) {
          _mapController.move(_currentPosition!, _mapController.camera.zoom);
        }

        if (_activeDestination != null) {
          _drawRouteTo(_activeDestination!);
        }
      }
      _geofenceService.checkProximity(position, landmarks, _handleProximityTrigger);
    });
  }

  void _handleProximityTrigger(Landmark landmark) {
    if (!_triggeredLandmarks.contains(landmark.name)) {
      _triggeredLandmarks.add(landmark.name);
      if (_activeDestination != null && _activeDestination!.name == landmark.name) {
        if (mounted) {
          setState(() {
            _routePoints.clear();
            _routeDistance = null;
            _activeDestination = null;
          });
        }
      }
      _showLandmarkDetails(landmark, isProximity: true);
    }
  }

  Future<void> _drawRouteTo(Landmark destination) async {
    _activeDestination = destination; 
    if (_currentPosition == null || !destination.hasCoordinates) return;
    
    final url = Uri.parse(
      'http://router.project-osrm.org/route/v1/foot/${_currentPosition!.longitude},${_currentPosition!.latitude};${destination.longitude},${destination.latitude}?geometries=geojson'
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        final double distanceMeters = data['routes'][0]['distance'].toDouble();
        
        if (mounted) {
          setState(() {
            _routePoints = coords.map((c) => LatLng(c[1], c[0])).toList();
            if (distanceMeters >= 1000) {
              _routeDistance = '${(distanceMeters / 1000).toStringAsFixed(2)} km';
            } else {
              _routeDistance = '${distanceMeters.toStringAsFixed(0)} m';
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Routing error: $e");
    }
  }

  void _retry() {
    setState(() {
      _future = _service.fetchLandmarks().then((landmarks) {
        _startTracking(landmarks);
        return landmarks;
      });
    });
  }

  void _showAdminAuthDialog() {
    final emailController = TextEditingController();
    final otpController = TextEditingController();
    bool isOtpSent = false;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isOtpSent ? 'Enter Security Code' : 'Admin Authentication'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isOtpSent)
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Makerere Email (@students.mak.ac.ug)',
                      border: OutlineInputBorder(),
                    ),
                  )
                else
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '6-Digit OTP',
                      border: OutlineInputBorder(),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isProcessing ? null : () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: isProcessing ? null : () async {
                  setDialogState(() => isProcessing = true);

                  try {
                    final email = emailController.text.trim().toLowerCase();
                    if (!isOtpSent) {
                      final isAllowed = email.endsWith('@students.mak.ac.ug') || 
                                        email.endsWith('@mak.ac.ug') || 
                                        email.endsWith('@gmail.com');

                      if (!isAllowed) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Unauthorised domain.'))
                        );
                        setDialogState(() => isProcessing = false);
                        return;
                      }

                      final response = await http.post(
                        Uri.parse('http://127.0.0.1:3000/api/admin/request-otp'), 
                        headers: {"Content-Type": "application/json"},
                        body: json.encode({"email": email}),
                      );

                      if (response.statusCode == 200) {
                        setDialogState(() => isOtpSent = true);
                      } else {
                        final error = json.decode(response.body)['error'] ?? 'Failed to send OTP';
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                      }
                    } else {
                      final otp = otpController.text.trim();

                      final response = await http.post(
                        Uri.parse('http://127.0.0.1:3000/api/admin/verify-otp'),
                        headers: {"Content-Type": "application/json"},
                        body: json.encode({"email": email, "code": otp}),
                      );

                      if (response.statusCode == 200) {
                        Navigator.pop(context); 
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddLandmarkScreen()),
                        );
                        if (result == true) _retry(); 
                      } else {
                        final error = json.decode(response.body)['error'] ?? 'Invalid OTP';
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                      }
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Network error: $e')));
                  } finally {
                    setDialogState(() => isProcessing = false);
                  }
                },
                child: isProcessing
                    ? const SizedBox(
                        width: 16, 
                        height: 16, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                    : Text(isOtpSent ? 'Verify' : 'Send Code', style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLandmarkDetails(Landmark landmark, {bool isProximity = false}) {
    bool isPlaying = true;
    _flutterTts.speak(landmark.description ?? "No description available.");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            _flutterTts.setCompletionHandler(() {
              if (mounted) {
                setModalState(() {
                  isPlaying = false;
                });
              }
            });

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isProximity)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        "📍 You are nearby!",
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          landmark.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.volume_off : Icons.volume_up, 
                          color: const Color(0xFFE5A93C), 
                          size: 28
                        ),
                        onPressed: () async {
                          if (isPlaying) {
                            await _flutterTts.stop();
                            setModalState(() { isPlaying = false; });
                          } else {
                            await _flutterTts.speak(landmark.description ?? "No description available.");
                            setModalState(() { isPlaying = true; });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${landmark.category}",
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    landmark.description ?? "No description available.",
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions_walk),
                      label: const Text('Set Destination', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE5A93C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context); 
                        _drawRouteTo(landmark); 
                        setState(() {
                          _followUser = true;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          }
        );
      },
    ).whenComplete(() {
      _flutterTts.stop(); 
    });
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold completely removed. Returns direct Stack/FutureBuilder layout.
    return FutureBuilder<List<Landmark>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString(), onRetry: _retry);
        }

        final landmarks = snapshot.data ?? [];

        final markers = landmarks
            .where((l) => l.hasCoordinates)
            .map(
              (l) => Marker(
                point: LatLng(l.latitude!, l.longitude!),
                width: 50,
                height: 50,
                child: GestureDetector(
                  onTap: () {
                    _showLandmarkDetails(l);
                  },
                  child: const Tooltip(
                    message: "Tap to view",
                    child: Icon(
                      Icons.location_on,
                      color: Color(0xFFE5A93C),
                      size: 44,
                    ),
                  ),
                ),
              ),
            )
            .toList();

        if (_currentPosition != null) {
          markers.add(
            Marker(
              point: _currentPosition!,
              width: 100, // Size increased to contain the rotating light beam properly
              height: 100,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Google Maps Faded Rotation Beam
                  Transform.rotate(
                    angle: (_heading * math.pi / 180), // Convert compass degrees to radians
                    child: CustomPaint(
                      size: const Size(80, 80),
                      painter: _CompassBeamPainter(),
                    ),
                  ),
                  // 2. Central Positioning Dot
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1)
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _makerereCenter,
                initialZoom: 16,
                onPositionChanged: (position, hasGesture) {
                  if (hasGesture && _followUser) {
                    setState(() {
                      _followUser = false;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.makheritage.app',
                ),
                PolylineLayer(
                  polylines: [
                    if (_routePoints.isNotEmpty)
                      Polyline(
                        points: _routePoints,
                        color: Colors.blueAccent,
                        strokeWidth: 5.0,
                      ),
                  ],
                ),
                MarkerLayer(markers: markers),
              ],
            ),

            if (_isSearchVisible)
              Positioned(
                top: 16,
                left: 16, 
                right: 16,
                child: Autocomplete<Landmark>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<Landmark>.empty();
                    }
                    return landmarks.where((l) => 
                      l.name.toLowerCase().contains(textEditingValue.text.toLowerCase())
                    );
                  },
                  displayStringForOption: (Landmark option) => option.name,
                  onSelected: (Landmark selection) {
                    setState(() {
                      _isSearchVisible = false;
                    });
                    _showLandmarkDetails(selection);
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    return Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(30),
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: 'Search landmarks...',
                          filled: true,
                          fillColor: Colors.white,
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              controller.clear();
                              setState(() {
                                _routePoints.clear();
                                _routeDistance = null;
                                _activeDestination = null;
                                _isSearchVisible = false;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Positioned(
                top: 16,
                right: 16,
                child: Listener(
                  onPointerDown: (_) {
                    _adminTimer = Timer(const Duration(seconds: 10), () {
                      _showAdminAuthDialog();
                    });
                  },
                  onPointerUp: (_) => _adminTimer?.cancel(),
                  onPointerCancel: (_) => _adminTimer?.cancel(),
                  child: FloatingActionButton.small(
                    heroTag: 'searchBtn',
                    backgroundColor: Colors.red,
                    onPressed: () {
                      setState(() {
                        _isSearchVisible = true;
                      });
                    },
                    child: const Icon(Icons.search, color: Colors.white),
                  ),
                ),
              ),

            if (_routeDistance != null)
              Positioned(
                top: _isSearchVisible ? 80 : 24,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Text(
                      '$_routeDistance away',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ),

            if (landmarks.isNotEmpty && markers.isEmpty)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: _InfoBanner(
                  text: '${landmarks.length} landmarks loaded, but none have coordinates yet.',
                ),
              ),
            
            Positioned(
              bottom: 140, 
              right: 16,
              child: FloatingActionButton(
                heroTag: 'followBtn',
                backgroundColor: _followUser ? Colors.blueAccent : Colors.red,
                onPressed: () {
                  setState(() {
                    _followUser = !_followUser;
                  });
                  if (_followUser && _currentPosition != null) {
                    _mapController.move(_currentPosition!, 18.0); 
                    _mapController.rotate(360 - _heading);
                  } else {
                    _mapController.rotate(0);
                  }
                },
                child: Icon(
                  _followUser ? Icons.explore : Icons.my_location, 
                  color: Colors.white
                ),
              ),
            ),
            
            Positioned(
              bottom: 80,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'radarBtn',
                backgroundColor: Colors.red,
                child: const Icon(Icons.radar, color: Colors.white),
                onPressed: () async {
                  try {
                    Position pos = await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high,
                    );
                    
                    if (context.mounted) {
                      setState(() {
                        _currentPosition = LatLng(pos.latitude, pos.longitude);
                      });
                    }

                    bool found = false;
                    _geofenceService.checkProximity(pos, landmarks, (landmark) {
                      found = true;
                      _handleProximityTrigger(landmark);
                    });

                    if (!found && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No landmarks within 50 metres.')),
                      );
                    }
                  } catch (e) {
                    debugPrint("Location error: $e");
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// Draw the Custom Google Maps direction radar cone
class _CompassBeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.blueAccent.withOpacity(0.4),
          Colors.blueAccent.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2))
      ..style = PaintingStyle.fill;

    // Using ui.Path resolves the namespace clash with latlong2
    final path = ui.Path();
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    path.moveTo(centerX, centerY);
    path.lineTo(centerX - 25, centerY - 55); 
    path.quadraticBezierTo(centerX, centerY - 65, centerX + 25, centerY - 55);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }
}
