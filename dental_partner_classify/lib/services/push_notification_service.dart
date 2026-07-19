import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
  PushNotificationService._();

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'reservation_channel',
    '예약/리뷰 알림',
    description: '신규 예약, 리뷰 등록, 방문 예정 등 주요 알림',
    importance: Importance.high,
  );

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _local.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ));

    await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
  }

  static Future<void> saveTokenForCurrentUser() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _saveToken(token);
    } catch (_) {
      // 토큰 발급 실패해도 앱 사용에는 지장 없음 (알림만 못 받음)
    }
  }

  static Future<void> clearTokenOnLogout() async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return;
    try {
      await Supabase.instance.client
          .from('hospitals')
          .update({'fcm_token': null}).eq('email', email);
    } catch (_) {}
  }

  static Future<void> _saveToken(String token) async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return;
    try {
      await Supabase.instance.client
          .from('hospitals')
          .update({'fcm_token': token}).eq('email', email);
    } catch (_) {}
  }

  static void _showForegroundNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;
    _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  // 환자 방문 예정 알림: 방문 시각 N분 전에 로컬 알림 예약 (서버 왕복 없이 기기에서 직접 스케줄)
  static Future<void> scheduleArrivalReminder({
    required int reservationId,
    required DateTime visitAt,
    required String patientName,
    required int minutesBefore,
  }) async {
    final scheduledAt = visitAt.subtract(Duration(minutes: minutesBefore));
    if (scheduledAt.isBefore(DateTime.now())) return;

    await _local.zonedSchedule(
      reservationId,
      '환자 방문 예정',
      '$patientName님이 $minutesBefore분 후 방문 예정입니다.',
      tz.TZDateTime.from(scheduledAt, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  static Future<void> cancelArrivalReminder(int reservationId) =>
      _local.cancel(reservationId);
}
