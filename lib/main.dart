import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const DoorBirdApp());
}

class DoorBirdApp extends StatelessWidget {
  const DoorBirdApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DoorBird Live',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late VideoPlayerController _controller;
  final DatabaseReference _db = FirebaseDatabase.instance.ref('rings');
  List<Map<String, dynamic>> rings = [];

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initVideo();
    _initPush();
    _loadRings();
  }

  void _initVideo() {
    _controller = VideoPlayerController.network(
      'http://192.168.7.238/bha-api/video.cgi',
    )..initialize().then((_) {
      setState(() {});
      _controller.play();
      _controller.setLooping(true);
    }).catchError((error) {
      print("Video error: $error");
    });
  }

  Future<void> _initPush() async {
    const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(message);
      _loadRings();
    });

    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    print('FCM Token: $token');
  }

  Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'doorbell_channel', 'DoorBell',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: android);
    await _notifications.show(
      0, 'Someone is at the door!', 'Front Door rang', details,
    );
  }

  void _loadRings() {
    _db.limitToLast(10).onValue.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        rings = data.entries.map((e) {
          final val = e.value as Map<dynamic, dynamic>;
          final ts = val['timestamp']?.toString() ?? '';
          return {
            'time': ts.contains('T') ? ts.split('T')[1].substring(0, 8) : '',
            'date': ts.contains('T') ? ts.split('T')[0] : '',
          };
        }).toList().reversed.toList();
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DoorBird Live')),
      body: Column(
        children: [
          _controller.value.isInitialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(_controller),
                )
              : const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
          const SizedBox(height: 20),
          const Text('Ring History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(
            child: ListView.builder(
              itemCount: rings.length,
              itemBuilder: (ctx, i) {
                final r = rings[i];
                return ListTile(
                  leading: const Icon(Icons.doorbell, color: Colors.orange),
                  title: const Text('Front Door'),
                  subtitle: Text('${r['date']} ${r['time']}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}