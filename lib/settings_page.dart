import 'package:flutter/material.dart';
import 'notification_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _offsetMinutes = NotificationSettings.defaultNotificationOffset;
  int _postponeMinutes = NotificationSettings.defaultPostponeTime;

  Future<void> _selectTime(String label, int currentMinutes,
      void Function(int newMinutes) onTimeSelected) async {
    // Calculate initial hour in 0–11 range.
    final currentHour = currentMinutes ~/ 60;
    final initialHour = currentHour < 12 ? currentHour : currentHour - 12;
    final initialMinute = currentMinutes % 60;
    final initialTime = TimeOfDay(hour: initialHour, minute: initialMinute);
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      helpText: "Select $label time ",
      builder: (BuildContext context, Widget? child) {
        // Force 24-hour mode so AM/PM option is removed.
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked != null) {
      // Normalize picked hour: if hour >=12 then subtract 12 so that 12 becomes 0.
      final normalizedHour = picked.hour < 12 ? picked.hour : picked.hour - 12;
      final newMinutes = normalizedHour * 60 + picked.minute;
      setState(() {
        onTimeSelected(newMinutes);
        NotificationSettings.defaultNotificationOffset =
            label == "notification offset"
                ? newMinutes
                : NotificationSettings.defaultNotificationOffset;
        NotificationSettings.defaultPostponeTime = label == "postpone"
            ? newMinutes
            : NotificationSettings.defaultPostponeTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Notification offset picker.
            ListTile(
              title: const Text("Notification offset"),
              subtitle: Text("Current: $_offsetMinutes minute(s)"),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                await _selectTime("notification offset", _offsetMinutes,
                    (newMinutes) {
                  _offsetMinutes = newMinutes;
                });
              },
            ),
            const SizedBox(height: 20),
            // Postpone time picker.
            ListTile(
              title: const Text("Default postpone time"),
              subtitle: Text("Current: $_postponeMinutes minute(s)"),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                await _selectTime("postpone", _postponeMinutes, (newMinutes) {
                  _postponeMinutes = newMinutes;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
