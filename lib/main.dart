// lib/main.dart  (BFP Fire Dispatcher App)
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/dispatcher_screen.dart';
import 'services/auth_service.dart';
import 'services/dispatcher_presence.dart';
import 'core/app_colors.dart';

final FlutterLocalNotificationsPlugin _localNotif =
    FlutterLocalNotificationsPlugin();

const String _kChannelId = 'lifeguard_bfp_alerts';
const String _kChannelName = 'LifeGuard360 BFP Alerts';

// ── FCM background handler ────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await _localNotif.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await _localNotif.show(
    id: (DateTime.now().millisecondsSinceEpoch ~/ 1000) & 0x7FFFFFFF,
    title: message.notification?.title ?? '🔥 New Fire Report',
    body: message.notification?.body ?? 'A fire emergency has been reported.',
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        _kChannelId,
        _kChannelName,
        channelDescription: 'Fire emergency report alerts for BFP dispatchers',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
        fullScreenIntent: true,
        color: const Color(0xFFD32F2F),
        icon: '@mipmap/ic_launcher',
        visibility: NotificationVisibility.public,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}

// ── MAIN ──────────────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await _localNotif.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    ),
  );

  await _localNotif
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          _kChannelId,
          _kChannelName,
          description: 'Fire emergency report alerts for BFP dispatchers',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          showBadge: true,
        ),
      );

  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

  runApp(const BfpDispatcherApp());
}

// ── APP ───────────────────────────────────────────────────────────────────────
class BfpDispatcherApp extends StatelessWidget {
  const BfpDispatcherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LifeGuard360 BFP Dispatcher',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A2035),
          elevation: 0,
        ),
      ),
      home: const _SplashRouter(),
    );
  }
}

// ── SPLASH ROUTER ─────────────────────────────────────────────────────────────
class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final session = await AuthService.getSession();
    if (!mounted) return;

    if (session != null) {
      // Auto-login path — restart presence tracking so OnlineStatus /
      // LastSeen keep updating and the onDisconnect() hook is re-armed
      // on Firebase's server for this session.
      final userId = session['userId']?.toString() ?? '';
      if (userId.isNotEmpty) {
        await DispatcherPresence.initialize(userId, 'BFPAccounts');
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DispatcherScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 42,
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'LifeGuard360',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A2035),
              ),
            ),
            SizedBox(height: 6),
            Text(
              'BFP FIRE DISPATCHER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                letterSpacing: 1.8,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
