import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/map_screen.dart';
import 'screens/landmark_list_screen.dart';
import 'dart:isolate';
import 'package:geolocator/geolocator.dart';

// ----------------------------------------------------
// GLOBAL STATE: Keeps Admin Mode alive across all tabs
final ValueNotifier<bool> globalIsAdminMode = ValueNotifier<bool>(false);

// GLOBAL STATE: Triggers all landmark views (Map & List) to refresh immediately when updated
final ValueNotifier<int> globalLandmarksRefreshNotifier = ValueNotifier<int>(0);
final ValueNotifier<int> landmarkListRefreshNotifier = globalLandmarksRefreshNotifier;

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

class LocationTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {}

  @override
  Future<void> onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      sendPort?.send({
        'lat': position.latitude,
        'lng': position.longitude,
      });
    } catch (e) { }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'makheritage_bg',
      channelName: 'MakHeritage Location Service',
      channelDescription: 'Running in background to track landmarks',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      isSticky: false, 
      iconData: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
    ),
    iosNotificationOptions: const IOSNotificationOptions(),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 5000,
      isOnceEvent: false,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
  runApp(const MakHeritageApp());
}

class MakHeritageApp extends StatelessWidget {
  const MakHeritageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MakHeritage',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF006633),
          primary: const Color(0xFF006633),
          secondary: const Color(0xFFE5A93C),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RootScreen()));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF006633),
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _animation,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ), 
              ),
              const SizedBox(height: 20),
              const Text(
                'MakHeritage',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                'Navigate the Legacy.',
                style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: Color(0xFFE5A93C)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;
  static const _titles = ['Map', 'Landmarks'];
  final _screens = const [MapScreen(), LandmarkListScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF006633),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    width: 28,
                    height: 28,
                  ),
                ), 
                const SizedBox(width: 8),
                const Text(
                  'MakHeritage',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18),
                ),
              ],
            ),
            // The top bar now watches the Admin Mode and displays the Exit button cleanly
            ValueListenableBuilder<bool>(
              valueListenable: globalIsAdminMode,
              builder: (context, isAdmin, _) {
                if (isAdmin) {
                  return TextButton.icon(
                    onPressed: () => globalIsAdminMode.value = false,
                    icon: const Icon(Icons.exit_to_app, color: Colors.red),
                    label: const Text('Exit Admin Mode', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
                    style: TextButton.styleFrom(backgroundColor: Colors.white),
                  );
                }
                return Text(
                  _titles[_index],
                  style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.white70, fontSize: 16),
                );
              },
            ),
          ],
        ),
      ),
      // USING INDEXEDSTACK: This completely stops the app from "booting you out" of views when you switch tabs! 
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) {
          setState(() => _index = i);
          // Force all active tabs to refetch fresh data on tab change
          globalLandmarksRefreshNotifier.value++;
        },
        selectedItemColor: const Color(0xFF006633),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Landmarks'),
        ],
      ),
    );
  }
}
