import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:live_location/screens/splash_widget.dart';
import 'firebase_options.dart';


Future<void> main() async {

  await dotenv.load(fileName: "assets/.env");

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform
  );

  await AwesomeNotifications().initialize(
    'resource://drawable/notification_icon',
    [
      NotificationChannel(
        channelKey: 'vehicle_updates',
        channelName: 'Vehicle Updates',
        channelDescription: 'Notifications about vehicle status changes',
        defaultColor: const Color(0xFF3F51B5),
        ledColor: const Color(0xFF3F51B5),
        importance: NotificationImportance.High,
        defaultPrivacy: NotificationPrivacy.Private,
        enableVibration: true,
        playSound: true,
      )
    ],
  );

  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}


Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  print("Handling a background message: ${message.messageId}");

  if (message.notification != null) {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: message.hashCode,
        channelKey: 'vehicle_updates',
        title: message.notification?.title ?? 'Vehicle Update',
        body: message.notification?.body ?? 'A vehicle status has changed',
        notificationLayout: NotificationLayout.Default,
        payload: message.data.map((key, value) => MapEntry(key, value.toString())),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashWidget(),
    );
  }

}
