import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';

class NotificationController {


  static Future<void> initializeNotificationListeners() async {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  /// Use this method to detect when a new notification or a schedule is created
  @pragma('vm:entry-point')
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    debugPrint('Notification created: ${receivedNotification.toMap().toString()}');
  }

  /// Use this method to detect every time that a new notification is displayed
  @pragma('vm:entry-point')
  static Future<void> onNotificationDisplayedMethod(
      ReceivedNotification receivedNotification) async {
    debugPrint('Notification displayed: ${receivedNotification.toMap().toString()}');
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma('vm:entry-point')
  static Future<void> onDismissActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint('Notification dismissed: ${receivedAction.toMap().toString()}');
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(
      ReceivedAction receivedAction) async {
    debugPrint('Notification action received: ${receivedAction.toMap().toString()}');

    // Navigate based on the notification action
    if (receivedAction.buttonKeyPressed == 'VIEW_DETAILS') {
      // Get the payload data
      Map<String, String?>? payload = receivedAction.payload;

      if (payload != null && payload.containsKey('vehicleId')) {
        String? vehicleId = payload['vehicleId'];
        debugPrint('Navigating to vehicle details for: $vehicleId');

        // In a real app, we would navigate to the appropriate screen
        // But since this is a separate class, we need a navigation technique
        // that doesn't require context

        // Option 1: Using a navigation key (defined in main.dart)
        // MyApp.navigatorKey.currentState?.push(
        //   MaterialPageRoute(
        //     builder: (context) => VehicleDetailsScreen(vehicleId: vehicleId),
        //   ),
        // );

        // Option 2: Using a navigation service (more complex but better architecture)
        // NavigationService.instance.navigateTo(
        //   'vehicle_details',
        //   arguments: {'vehicleId': vehicleId},
        // );
      }
    }
  }

  // Request notification permissions
  static Future<bool> requestNotificationPermissions() async {
    final bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      return await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    return isAllowed;
  }

  // Create a basic notification
  static Future<void> createBasicNotification({
    required int id,
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'vehicle_updates',
        title: title,
        body: body,
        payload: payload,
      ),
    );
  }

  // Create a notification with action buttons
  static Future<void> createNotificationWithActions({
    required int id,
    required String title,
    required String body,
    Map<String, String>? payload,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'vehicle_updates',
        title: title,
        body: body,
        payload: payload,
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'VIEW_DETAILS',
          label: 'View Details',
        ),
        NotificationActionButton(
          key: 'DISMISS',
          label: 'Dismiss',
          isDangerousOption: true,
        ),
      ],
    );
  }

  // Cancel a specific notification
  static Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
}