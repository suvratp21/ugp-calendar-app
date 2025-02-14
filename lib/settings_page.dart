import 'package:flutter/material.dart';
import 'circular_time_picker_full.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // NEW: Replace minute-only settings with full time settings.
  int _offsetHour = 0;
  int _offsetMinute = 5;
  int _postponeHour = 0;
  int _postponeMinute = 10;

  // NEW: Generic method to select full time (hours and minutes).
  Future<void> _selectFullTime(String label, int initialHour, int initialMinute,
      void Function(int newHour, int newMinute) onTimeSelected) async {
    final result = await showDialog<Map<String, int>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("$label Time"),
          content: Center(
            child: CircularTimePickerFull(
              initialHour: initialHour,
              initialMinute: initialMinute,
              onTimeSelected: (hour, minute) {
                Navigator.of(context).pop({'hour': hour, 'minute': minute});
              },
            ),
          ),
        );
      },
    );
    if (result != null) {
      setState(() {
        onTimeSelected(result['hour']!, result['minute']!);
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
            // Notification offset picker using full time picker.
            ListTile(
              title: const Text("Notification offset"),
              subtitle: Text(
                  "Current: ${_offsetHour.toString().padLeft(2, '0')}:${_offsetMinute.toString().padLeft(2, '0')}"),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                await _selectFullTime(
                    "notification offset", _offsetHour, _offsetMinute,
                    (newHour, newMinute) {
                  _offsetHour = newHour;
                  _offsetMinute = newMinute;
                });
              },
            ),
            const SizedBox(height: 20),
            // Default postpone time using full time picker.
            ListTile(
              title: const Text("Default postpone time"),
              subtitle: Text(
                  "Current: ${_postponeHour.toString().padLeft(2, '0')}:${_postponeMinute.toString().padLeft(2, '0')}"),
              trailing: const Icon(Icons.access_time),
              onTap: () async {
                await _selectFullTime(
                    "postpone", _postponeHour, _postponeMinute,
                    (newHour, newMinute) {
                  _postponeHour = newHour;
                  _postponeMinute = newMinute;
                });
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
