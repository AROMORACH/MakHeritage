import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/landmark.dart';
import '../services/landmark_service.dart';
import '../services/geofence_service.dart';
import 'add_landmark_screen.dart';
import 'edit_landmark_screen.dart';
import 'dart:ui' as ui;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../main.dart'; // To access globalIsAdminMode

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
  double _heading = 0.0; 
  List<LatLng> _routePoints = [];
  String? _routeDistance;
  bool _isSearchVisible = false;
  Landmark? _activeDestination; 
  
  bool _followUser = false; 
  Timer? _adminTimer;
  StreamSubscription? _taskDataSubscription; 
  bool _isMasterVolumeMuted = false;

  Future<void> _loadMutePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isMasterVolumeMuted = prefs.getBool('is_master_volume_muted') ?? false;
      });
    }
  }

  Future<void> _toggleMuteState() async {
    final newMuteState = !_isMasterVolumeMuted;
    setState(() {
      _isMasterVolumeMuted = newMuteState;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_master_volume_muted', newMuteState);
    if (newMuteState) {
      _flutterTts.stop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-narration muted.')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-narration enabled.')),
        );
      }
    }
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'makheritage_bg_service',
        channelName: 'MakHeritage Location Tracking',
        channelDescription: 'Tracks location in the background to narrate nearby landmarks.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        isSticky: false,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic, 
          name: 'launcher',             
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

        if (_loadedLandmarks.isNotEmpty && _shouldTriggerAutoDetection(position)) {
          _geofenceService.checkProximity(position, _loadedLandmarks, _handleProximityTrigger);
        }
      }
    });
  }

  static const LatLng _makerereCenter = LatLng(0.3315, 32.5675);

  late final VoidCallback _refreshListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadMutePreference();
    _initTts();
    _initCompass();
    _initForegroundTask();
    _initForegroundTaskListener(); 
    _refreshListener = () {
      if (mounted) _retry();
    };
    globalLandmarksRefreshNotifier.addListener(_refreshListener);
    _future = _service.fetchLandmarks().then((landmarks) {
      _loadedLandmarks = landmarks; 
      _startTracking(landmarks);
      return landmarks;
    });
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-GB");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    try {
      dynamic voices = await _flutterTts.getVoices;
      if (voices != null) {
        for (var voice in voices) {
          String voiceName = voice["name"].toString().toLowerCase();
          if (voiceName.contains("male") || voiceName.contains("daniel")) {
            await _flutterTts.setVoice({"name": voice["name"], "locale": voice["locale"]});
            break;
          }
        }
      }
    } catch (e) {
      debugPrint("Failed to set male voice: $e");
    }
  }

  String _formatPronunciation(String text) {
    return text
        .replaceAll(RegExp(r'Kikoni', caseSensitive: false), 'Chiko-ni')
        .replaceAll(RegExp(r'Makerere', caseSensitive: false), 'Mahkerrehrey');
  }

  void _initCompass() {
    _compassStream = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      
      final double? direction = event.heading;
      if (direction != null) {
        setState(() {
          _heading = direction;
          
          if (_followUser && _currentPosition != null) {
            _mapController.rotate(360 - direction);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    globalLandmarksRefreshNotifier.removeListener(_refreshListener);
    WidgetsBinding.instance.removeObserver(this);
    _taskDataSubscription?.cancel(); 
    _positionStream?.cancel();
    _compassStream?.cancel();
    _flutterTts.stop();
    _adminTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Only stop tracking when the app is swiped away / closed (detached).
    // If the app is simply in the background (paused/hidden/inactive), keep tracking running!
    if (state == AppLifecycleState.detached) {
      FlutterForegroundTask.stopService();
    }
  }

  Future<void> _startTracking(List<Landmark> landmarks) async {
    await _positionStream?.cancel();
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;
    }

    final NotificationPermission notificationPermissionStatus =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isIgnoringBatteryOptimizations == false) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    if (!await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.startService(
        notificationTitle: 'MakHeritage',
        notificationText: 'Tracking nearby landmarks...',
        callback: startCallback,
      );
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
      if (_shouldTriggerAutoDetection(position)) {
        _geofenceService.checkProximity(position, landmarks, _handleProximityTrigger);
      }
    });
  }

  Position? _lastProximityCheckPosition;

  bool _shouldTriggerAutoDetection(Position newPos) {
    if (_lastProximityCheckPosition == null) {
      _lastProximityCheckPosition = newPos;
      return false; // Do not auto-trigger proximity audio on initial app launch or first fix
    }
    final double dist = Geolocator.distanceBetween(
      _lastProximityCheckPosition!.latitude,
      _lastProximityCheckPosition!.longitude,
      newPos.latitude,
      newPos.longitude,
    );
    if (dist >= 15.0) {
      _lastProximityCheckPosition = newPos;
      return true;
    }
    return false;
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
    if (!mounted) return;
    setState(() {
      _future = _service.fetchLandmarks().then((landmarks) {
        _loadedLandmarks = landmarks;
        _startTracking(landmarks);
        return landmarks;
      });
    });
  }

  void _showAdminAuthDialog() {
    final emailController = TextEditingController(text: 'test@example.com');
    final otpController = TextEditingController();
    final secretCodeController = TextEditingController(); 
    bool isOtpSent = false;
    bool isProcessing = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isOtpSent ? 'Verify Admin Identity' : 'Admin Authentication'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isOtpSent)
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                    ),
                  )
                else
                  Column(
                    children: [
                      TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '6-Digit OTP',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: secretCodeController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Secret Code',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
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
                    
                    if (email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid email.'))
                      );
                      setDialogState(() => isProcessing = false);
                      return;
                    }

                    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'https://makheritage.onrender.com';

                    if (!isOtpSent) {
                      // Send OTP via our custom Mailtrap backend
                      final res = await http.post(
                        Uri.parse('$baseUrl/api/admin/request-otp'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({'email': email}),
                      );

                      if (res.statusCode == 200) {
                        setDialogState(() => isOtpSent = true);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('OTP sent! Check your Mailtrap inbox.'))
                          );
                        }
                      } else {
                        final error = jsonDecode(res.body)['error'] ?? 'Failed to send OTP.';
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                        }
                        setDialogState(() => isProcessing = false);
                        return;
                      }
                    } else {
                      final otp = otpController.text.trim();
                      final secret = secretCodeController.text.trim();

                      // Verify OTP via our custom backend
                      final res = await http.post(
                        Uri.parse('$baseUrl/api/admin/verify-otp'),
                        headers: {'Content-Type': 'application/json'},
                        body: jsonEncode({'email': email, 'code': otp, 'secretCode': secret}),
                      );

                      if (res.statusCode == 200) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          globalIsAdminMode.value = true;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin Mode activated!')));
                        }
                      } else {
                        final error = jsonDecode(res.body)['error'] ?? 'Verification failed.';
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                        }
                      }
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
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
                    : Text(isOtpSent ? 'Unlock' : 'Send Code', style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLandmarkDetails(Landmark landmark, {bool isProximity = false}) {
    bool isPlaying = !_isMasterVolumeMuted;
    final isAdmin = globalIsAdminMode.value; // Read global state
    
    String displayDescription = landmark.description ?? "No description available.";
    if (landmark.name.toLowerCase().contains('ivory tower') ||
        landmark.name.toLowerCase().contains('main admin') ||
        landmark.name.toLowerCase().contains('main building')) {
      displayDescription =
          "Completed in 1941, the Makerere University Main Administration Building, affectionately known as the Ivory Tower, stands as the most iconic architectural landmark of higher education in East Africa. Featuring a distinctive white-walled tower, bell clock, and blue-tiled roof, it served as the nerve centre for East African academic governance throughout the 20th century. Following a midnight fire in September 2020, a comprehensive restoration preserved its iconic 1941 colonial exterior while modernising its interior.";
    }

    final imagePath = landmark.imageAssetPath;

    String textToSpeak = _formatPronunciation(displayDescription);
    if (!_isMasterVolumeMuted) {
      _flutterTts.speak(textToSpeak);
    }

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

            return SingleChildScrollView(
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
                  if (imagePath != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imagePath.startsWith('http://') || imagePath.startsWith('https://')
                          ? Image.network(imagePath, height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
                          : imagePath.startsWith('/') || imagePath.startsWith('file://')
                              ? Image.file(File(imagePath.replaceFirst('file://', '')), height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
                              : Image.asset(imagePath, height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                    const SizedBox(height: 16),
                  ],
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
                          isPlaying ? Icons.volume_up : Icons.volume_off, 
                          color: const Color(0xFFE5A93C), 
                          size: 28
                        ),
                        onPressed: () async {
                          if (isPlaying) {
                            await _flutterTts.stop();
                            setModalState(() { isPlaying = false; });
                          } else {
                            await _flutterTts.speak(_formatPronunciation(displayDescription));
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
                    displayDescription,
                    style: const TextStyle(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.directions_walk),
                      label: const Text('Set Destination', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
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
                  if (isAdmin) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Landmark'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (_) => EditLandmarkScreen(landmark: landmark))).then((_) => _retry());
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete Landmark'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                           bool confirm = await showDialog(
                             context: context,
                             builder: (c) => AlertDialog(
                               title: const Text('Confirm Delete'),
                               content: Text('Are you sure you want to delete ${landmark.name}?'),
                               actions: [
                                 TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                 TextButton(
                                  onPressed: () => Navigator.pop(c, true), 
                                  child: const Text('Delete', style: TextStyle(color: Colors.red))
                                 ),
                               ],
                             )
                           ) ?? false;

                           if (confirm) {
                               // ignore: use_build_context_synchronously
                               Navigator.pop(context); 
                               bool success = await _service.deleteLandmark(landmark.id);
                               if (success) _retry();
                           }
                        },
                      ),
                    ),
                  ],
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
      // Wrap the entire screen in the global value listener so FABs appear instantly
      return ValueListenableBuilder<bool>(
        valueListenable: globalIsAdminMode,
        builder: (context, isAdmin, child) {
          return Scaffold(
            body: FutureBuilder<List<Landmark>>(
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
                      width: 100, 
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Transform.rotate(
                            angle: (_heading * math.pi / 180), 
                            child: CustomPaint(
                              size: const Size(80, 80),
                              painter: _CompassBeamPainter(),
                            ),
                          ),
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
                        backgroundColor: Colors.red,
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

                    // NEW ADMIN ADD BUTTON (Only visible to admin)
                    if (isAdmin)
                      Positioned(
                        bottom: 150, // Placed precisely above the master volume button!
                        left: 16,
                        child: FloatingActionButton(
                          heroTag: 'addLandmarkBtn',
                          backgroundColor: Colors.red,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AddLandmarkScreen())).then((_) => _retry());
                          },
                          child: const Icon(Icons.add_location_alt, color: Colors.white),
                        ),
                      ),

                    Positioned(
                      bottom: 80,
                      left: 16,
                      child: FloatingActionButton(
                        heroTag: 'masterVolumeBtn',
                        backgroundColor: _isMasterVolumeMuted ? Colors.grey : Colors.red,
                        onPressed: _toggleMuteState,
                        child: Icon(
                          _isMasterVolumeMuted ? Icons.volume_off : Icons.volume_up, 
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
                              _showLandmarkDetails(landmark, isProximity: true);
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
            ),
          );
        }
      );
    }
}   
class _CompassBeamPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Canvas painting identical to original
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.blueAccent.withOpacity(0.4),
          Colors.blueAccent.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: Offset(size.width / 2, size.height / 2), radius: size.width / 2))
      ..style = PaintingStyle.fill;

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
