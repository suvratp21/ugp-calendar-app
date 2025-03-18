import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:googleapis/calendar/v3.dart';

class NotificationActionHandler {
  final CalendarApi calendarApi;

  NotificationActionHandler({required this.calendarApi}) {
    AwesomeNotifications().actionStream.listen(_handleAction);
  }

  void _handleAction(ReceivedAction action) {
    // Log action for debugging.
    print(
        "Action received: ${action.buttonKeyPressed}, payload: ${action.payload}");
    // Assume action.buttonKeyPressed is set to 'POSTPONE' or 'REJECT' and payload contains "eventId".
    final payload = action.payload;
    if (action.buttonKeyPressed == 'POSTPONE') {
      _postponeEvent(payload);
    } else if (action.buttonKeyPressed == 'REJECT') {
      _rejectEvent(payload);
    }
  }

  Future<void> _postponeEvent(Map<String, String?>? payload) async {
    final eventId = payload?['eventId'];
    if (eventId == null || eventId.isEmpty) {
      print("No eventId provided in payload for postponing.");
      return;
    }
    try {
      final event = await calendarApi.events.get('primary', eventId);
      if (event.start?.dateTime == null || event.end?.dateTime == null) {
        print("Event does not have proper start/end times.");
        return;
      }
      final currentStart = event.start!.dateTime!.toLocal();
      final currentEnd = event.end!.dateTime!.toLocal();
      final newStart = currentStart.add(const Duration(minutes: 15));
      final newEnd = currentEnd.add(const Duration(minutes: 15));
      event.start = EventDateTime(dateTime: newStart.toUtc(), timeZone: "UTC");
      event.end = EventDateTime(dateTime: newEnd.toUtc(), timeZone: "UTC");
      await calendarApi.events.update(event, 'primary', eventId);
      print("Successfully postponed event $eventId by 15 minutes.");
    } catch (e) {
      print("Error postponing event $eventId: $e");
    }
  }

  Future<void> _rejectEvent(Map<String, String?>? payload) async {
    final eventId = payload?['eventId'];
    if (eventId == null || eventId.isEmpty) {
      print("No eventId provided in payload for rejection.");
      return;
    }
    try {
      await calendarApi.events.delete('primary', eventId);
      print("Successfully rejected (deleted) event $eventId.");
    } catch (e) {
      print("Error rejecting event $eventId: $e");
    }
  }

  void dispose() {
    AwesomeNotifications().actionSink.close();
  }
}
