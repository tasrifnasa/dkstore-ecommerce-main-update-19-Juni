import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dkstore/firebase_options.dart';
import 'package:dkstore/router/app_routes.dart';
import 'global_keys.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Skip if it's a silent notification (no notification object)
  if (message.notification == null) {
    log('Ignoring silent push notification (likely auth related)');
    return;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }

  // FCM automatically shows notifications in the background on Android/iOS if message.notification is present.
  // We only show a local notification here if we want to customize it or if it's a data-only message.
  // To avoid duplicates, we can skip this if it's already a standard notification.
  log('Handling background notification: ${message.messageId}');
}

class NotificationService {
  late BuildContext? context;
  NotificationService({this.context});

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initFirebaseMessaging(BuildContext context) async {
    await _requestNotificationPermissions();

    // Initialize Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/notification');
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        log('Notification response received: ${response.payload}');
        if (response.payload != null) {
          try {
            log('User navigating from foreground notification tap');
            final Map<String, dynamic> data = jsonDecode(response.payload!);
            handleNotificationNavigation(data);
          } catch (e) {
            log('Error parsing notification payload: $e');
          }
        }
      },
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('Foreground Title: ${message.notification?.title}');
      log('Foreground Body: ${message.notification?.body}');
      _showForegroundNotification(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('Message opened app: ${message.notification?.title}');
      handleNotificationNavigation(message.data);
    });

    _firebaseMessaging.onTokenRefresh.listen((String newToken) {
      log('New FCM Token: $newToken');
    });
  }

  Future<void> _requestNotificationPermissions() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<String?> getFcmToken() async {
    return await _firebaseMessaging.getToken();
  }

  void _showForegroundNotification(RemoteMessage message) async {
    if (message.notification == null) return;
    
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'order-foreground',
          'order-foreground-channel',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@drawable/notification',
          largeIcon: const DrawableResourceAndroidBitmap(
            '@drawable/notification',
          ),
          sound: const RawResourceAndroidNotificationSound('notification_sound'),
          fullScreenIntent: true,
          enableVibration: true,
          enableLights: true,
        );

    final DarwinNotificationDetails iosDetails =
        const DarwinNotificationDetails(
          subtitle: '',
          threadIdentifier: 'foreground_threat',
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification_sound.wav',
        );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Pass the entire data map as JSON string to handle navigation on tap
    await _flutterLocalNotificationsPlugin.show(
      convertIntFromType(message),
      message.notification?.title ?? 'No Title',
      message.notification?.body ?? 'No Body',
      notificationDetails,
      payload: jsonEncode(message.data),
    );
  }

  int convertIntFromType(RemoteMessage message) {
    final type = message.data['type']?.toString();
    if (type == 'new_order' || type == 'order_update' || type == 'return_order' || type == 'return_order_update') {
      return 1;
    } else if (type == 'wallet_transaction') {
      return 2;
    }
    return 1;
  }

  static void handleNotificationNavigation(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    final orderSlug = data['order_slug']?.toString();
    final navigatorContext = GlobalKeys.navigatorKey.currentContext;

    log('Handling notification navigation: type=$type, slug=$orderSlug');

    if (navigatorContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (type == 'order' || type == 'delivery'|| type == 'new_order' || type == 'order_update') {
          if (orderSlug != null) {
            log('Delivery Tracking Navigation');
            GoRouter.of(navigatorContext).push(
              AppRoutes.deliveryTracking,
              extra: {'order-slug': orderSlug},
            );
          }
        } else if (type == 'delivered') {
          log('Order Delivered Navigation');
          GoRouter.of(navigatorContext).push(AppRoutes.orderDetail,
              extra: {'order-slug': orderSlug});

        } else if (type == 'wallet_transaction') {
          log('Wallet Transaction Navigation');
          GoRouter.of(navigatorContext).push(AppRoutes.transactions);
        }
      });
    } else {
      log('Navigator context is null, cannot navigate');
    }
  }
}

Future<String?> getFCMToken() async {
  try {
    // Request notification permissions first
    NotificationSettings settings = await FirebaseMessaging.instance
        .requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Wait for APNS token to be available on iOS
      if (Platform.isIOS) {
        await Future.delayed(const Duration(seconds: 2));
      }

      final fcmToken = await FirebaseMessaging.instance.getToken();
      log('FCM Token: $fcmToken');
      return fcmToken;
    } else {
      log('User declined or has not accepted notification permissions');
      return null;
    }
  } catch (e) {
    log('Error getting FCM token: $e');
    return null;
  }
}
