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

  /// method to detect when a new notification or a schedule is created
  @pragma('vm:entry-point')
  static Future<void> onNotificationCreatedMethod(
      ReceivedNotification receivedNotification) async {
    debugPrint('Notification created: ${receivedNotification.toMap().toString()}');
  }

  /// method to detect every time that a new notification is displayed
  @pragma('vm:entry-point')
  static Future<void> onNotificationDisplayedMethod(ReceivedNotification receivedNotification) async {
    debugPrint('Notification displayed: ${receivedNotification.toMap().toString()}');
  }

  /// method to detect if the user dismissed a notification
  @pragma('vm:entry-point')
  static Future<void> onDismissActionReceivedMethod(ReceivedAction receivedAction) async {
    debugPrint('Notification dismissed: ${receivedAction.toMap().toString()}');
  }

  /// method to detect when the user taps on a notification or action button
  @pragma('vm:entry-point')
  static Future<void> onActionReceivedMethod(ReceivedAction receivedAction) async {
    debugPrint('Notification action received: ${receivedAction.toMap().toString()}');

    // Navigate based on the notification action
    if (receivedAction.buttonKeyPressed == 'VIEW_DETAILS') {
      Map<String, String?>? payload = receivedAction.payload;

      if (payload != null && payload.containsKey('vehicleId')) {
        String? vehicleId = payload['vehicleId'];
        debugPrint('Navigating to vehicle details for: $vehicleId');
      }
    }
  }

  static Future<bool> requestNotificationPermissions() async {
    final bool isAllowed = await AwesomeNotifications().isNotificationAllowed();

    if (!isAllowed) {
      return await AwesomeNotifications().requestPermissionToSendNotifications();
    }

    return isAllowed;
  }

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

  static Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  static Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }
}