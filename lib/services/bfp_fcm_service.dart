import 'dart:convert';
import 'dart:ui';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class BfpFcmService {
  static const String _dbUrl =
      'https://lifeguard-cefd9-default-rtdb.asia-southeast1.firebasedatabase.app/';

  static const String _channelId = 'lifeguard_bfp_alerts';
  static const String _channelName = 'LifeGuard360 BFP Alerts';

  static final FlutterLocalNotificationsPlugin _localNotif =
      FlutterLocalNotificationsPlugin();

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<void> initialize({
    required String dispatcherId,
    required String dispatcherName,
  }) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        print('⚠️ BFP FCM: token is null');
        return;
      }

      await _initLocalNotifications();
      await _saveToken(
        dispatcherId: dispatcherId,
        dispatcherName: dispatcherName,
        token: token,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bfp_fcm_token', token);

      FirebaseMessaging.onMessage.listen((msg) {
        _showLocalNotification(
          title: msg.notification?.title ?? '🔥 New Fire Report',
          body: msg.notification?.body ?? 'A fire emergency has been reported.',
        );
      });

      messaging.onTokenRefresh.listen((newToken) async {
        await _saveToken(
          dispatcherId: dispatcherId,
          dispatcherName: dispatcherName,
          token: newToken,
        );
        final p = await SharedPreferences.getInstance();
        await p.setString('bfp_fcm_token', newToken);
        print('🔄 BFP FCM token refreshed');
      });

      print('✅ BFP FCM initialized for $dispatcherName ($dispatcherId)');
    } catch (e) {
      print('❌ BfpFcmService.initialize: $e');
    }
  }

  static Future<void> removeToken(String dispatcherId) async {
    try {
      await http
          .delete(Uri.parse('${_dbUrl}BFPTokens/$dispatcherId.json'))
          .timeout(const Duration(seconds: 10));
      print('🗑️ BFP FCM token removed for $dispatcherId');
    } catch (e) {
      print('⚠️ BfpFcmService.removeToken: $e');
    }
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  static Future<void> _saveToken({
    required String dispatcherId,
    required String dispatcherName,
    required String token,
  }) async {
    await http
        .patch(
          Uri.parse('${_dbUrl}BFPTokens/$dispatcherId.json'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'token': token,
            'dispatcherName': dispatcherName,
            'updatedAt': DateTime.now().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 10));
    print('✅ BFP FCM token saved at /BFPTokens/$dispatcherId');
  }

  static Future<void> _initLocalNotifications() async {
    await _localNotif.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await _localNotif
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: 'Fire emergency report alerts for BFP dispatchers',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            showBadge: true,
          ),
        );
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
  }) async {
    await _localNotif.show(
      id: (DateTime.now().millisecondsSinceEpoch ~/ 1000) & 0x7FFFFFFF,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              'Fire emergency report alerts for BFP dispatchers',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          fullScreenIntent: true,
          color: Color(0xFFD32F2F),
          icon: '@mipmap/ic_launcher',
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
