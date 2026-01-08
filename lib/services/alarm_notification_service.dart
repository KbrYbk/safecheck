import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:hive/hive.dart';
import '../models/receipt.dart';

@pragma('vm:entry-point')
class AlarmNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  @pragma('vm:entry-point')
  static Future<void> init() async {
    // Инициализация alarm manager
    await AndroidAlarmManager.initialize();
    // Инициализация timezone
    tz.initializeTimeZones();
    // Инициализация уведомлений
    const AndroidInitializationSettings android =
    AndroidInitializationSettings('notification_icon');
    const InitializationSettings settings = InitializationSettings(
      android: android,
    );

    await _notifications.initialize(settings);

    // канал с высокой важностью
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'warranty_channel',
      'Гарантия',
      description: 'Уведомления о заканчивающейся гарантии',
      importance: Importance.high,
      playSound: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // Топ-левел callback для AlarmManager
  @pragma('vm:entry-point')
  static Future<void> _alarmCallback(
    int id,
    Map<String, dynamic>? payload,
  ) async {
    await init();

    final String title = payload?['title'] ?? 'Товар';
    final int days = payload?['days'] ?? 0;

    await _notifications.show(
      id,
      'Гарантия заканчивается!',
      days == 0
          ? 'Сегодня истекает гарантия на $title'
          : 'Через $days дней истекает гарантия на $title',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'warranty_channel',
          'Гарантия',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
  @pragma('vm:entry-point')
  // Планируем уведомления для одного чека
  static Future<void> scheduleForReceipt(Receipt receipt) async {
    final warrantyEnd = receipt.warrantyEnd;

    final reminders = [
      {'days': 30, 'date': warrantyEnd.subtract(const Duration(days: 30))},
      {'days': 14, 'date': warrantyEnd.subtract(const Duration(days: 14))},
      {'days': 7, 'date': warrantyEnd.subtract(const Duration(days: 7))},
      {'days': 0, 'date': warrantyEnd}, // в день окончания
    ];

    for (var reminder in reminders) {
      final notifyDate = reminder['date'] as DateTime;
      final days = reminder['days'] as int;

      if (notifyDate.isAfter(DateTime.now())) {
        final int alarmId = receipt.hashCode + days; // уникальный ID
        await AndroidAlarmManager.cancel(alarmId);
        await AndroidAlarmManager.oneShotAt(
          notifyDate,
          alarmId,
          _alarmCallback,
          allowWhileIdle: true,
          wakeup: true,
          rescheduleOnReboot: true, // КЛЮЧЕВОЕ: пересоздаст после ребута
          params: {'title': receipt.title, 'days': days},
        );
      }
      print(
        'Планирую уведомление для чека ${receipt.title} на ${notifyDate} (через $days дней)',
      );
    }
  }
  @pragma('vm:entry-point')
  // Перепланируем все уведомления (вызывать при открытии приложения)
  static Future<void> rescheduleAll() async {
    final box = Hive.box<Receipt>('receipts');
    for (var receipt in box.values) {
      await scheduleForReceipt(receipt);
    }
  }
}
