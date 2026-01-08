import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'models/receipt.dart';
import 'services/theme_service.dart';
import 'services/alarm_notification_service.dart';

// Экраны
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/add_receipt_screen.dart';
import 'screens/expired_receipts_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';

// Обработчик фоновых уведомлений
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Фоновое уведомление: ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hive
  await Hive.initFlutter();
  Hive.registerAdapter(ReceiptAdapter());
  await Hive.openBox<Receipt>('receipts');
  await AlarmNotificationService.init();

  // Тема
  final themeService = ThemeService();
  await themeService.load();

  // Firebase
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final prefs = await SharedPreferences.getInstance();
  final bool alarmsInitialized = prefs.getBool('alarms_initialized') ?? false;
  if (!alarmsInitialized) {
    await AlarmNotificationService.rescheduleAll();
    await prefs.setBool('alarms_initialized', true);
    print('Уведомления запланированы при первом запуске');
  } else {
    print('Уведомления уже были запланированы ранее');
  }

  runApp(SafeCheckApp(themeService: themeService));
}

class SafeCheckApp extends StatefulWidget {
  final ThemeService themeService;

  const SafeCheckApp({super.key, required this.themeService});

  @override
  State<SafeCheckApp> createState() => _SafeCheckAppState();
}

class _SafeCheckAppState extends State<SafeCheckApp> {
  late final SharedPreferences _prefs;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _setupFCM();
  }

  // Загружаем сохранённую настройку уведомлений
  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    final enabled = _prefs.getBool('notifications') ?? true;
    print('Загружено из prefs: notifications = $enabled'); // Добавь этот лог!

    if (mounted) {
      setState(() => _notificationsEnabled = enabled);
    }

    await _updateTopicSubscription();
  }

  // Переключение уведомлений — сохраняем и обновляем подписку на топик
  Future<void> _toggleNotifications(bool enabled) async {
    setState(() => _notificationsEnabled = enabled);
    await _prefs.setBool('notifications', enabled);
    await _updateTopicSubscription();
  }

  // Новая функция: подписка или отписка от топика в зависимости от настройки
  Future<void> _updateTopicSubscription() async {
    final enabled = _prefs.getBool('notifications') ?? true;

    try {
      if (enabled) {
        await FirebaseMessaging.instance.subscribeToTopic('all');
        print('Успешно подписались на топик "all"');
      } else {
        await FirebaseMessaging.instance.unsubscribeFromTopic('all');
        print('Успешно отписались от топика "all"');
      }
    } catch (e) {
      print('Ошибка при подписке/отписке: $e');
    }
  }

  // Настройка FCM
  Future<void> _setupFCM() async {
    // Запрашиваем разрешение на push-уведомления (делаем всегда)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    print('Разрешение на уведомления: ${settings.authorizationStatus}');

    // Получаем токен (полезно для отладки и будущих функций)
    String? token = await FirebaseMessaging.instance.getToken();
    print('FCM TOKEN: $token');

    // Обработка уведомлений в foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Получено foreground уведомление: ${message.notification?.title}');
      // Здесь можно показать локальное уведомление или SnackBar
    });

    // Открытие приложения по клику на уведомление (из фона)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Открыто по уведомлению из фона');
      // Можно перейти на нужный экран
    });

    // Открытие из terminated состояния
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      print('Открыто из terminated по уведомлению');
    }

    // Подписка на топик делается в _updateTopicSubscription(),
    // которая вызывается из _loadSettings()
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightScheme =
            lightDynamic ?? ColorScheme.fromSeed(seedColor: const Color(0xFF2079DF));
        final darkScheme =
            darkDynamic ??
                ColorScheme.fromSeed(
                  seedColor: const Color(0xFF2079DF),
                  brightness: Brightness.dark,
                );

        return ValueListenableBuilder<ThemeMode>(
          valueListenable: widget.themeService.themeMode,
          builder: (context, mode, _) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              title: 'Гарантийные чеки',
              theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
              darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
              themeMode: mode,
              home: AuthWrapper(themeService: widget.themeService),
              routes: {
                '/login': (context) => const LoginScreen(),
                '/register': (context) => const RegisterScreen(),
                '/add': (context) => const AddReceiptScreen(),
                '/expired': (context) {
                  final box = Hive.box<Receipt>('receipts');
                  return ExpiredReceiptsScreen(receipts: box.values.toList());
                },
                '/profile': (context) => const ProfileScreen(),
                '/settings': (ctx) => SettingsScreen(
                  themeService: widget.themeService,
                  notificationsEnabled: _notificationsEnabled,
                  onNotificationsChanged: _toggleNotifications,
                ),
              },
            );
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  final ThemeService themeService;

  const AuthWrapper({super.key, required this.themeService});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        print('AuthWrapper: connectionState = ${snapshot.connectionState}, hasData = ${snapshot.hasData}');
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return HomeScreen(themeService: themeService);
        }
        return const LoginScreen();
      },
    );
  }
}