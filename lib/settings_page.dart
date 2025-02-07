import 'package:flutter/material.dart';
import 'notification_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: NotificationSettings.defaultNotificationOffset.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _saveSetting() {
    final value = int.tryParse(_controller.text);
    if (value != null) {
      setState(() {
        NotificationSettings.defaultNotificationOffset = value;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Default time updated")));
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
            const Text("Notification offset in minutes before event"),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                hintText: "Enter minutes",
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveSetting,
              child: const Text("Save"),
            )
          ],
        ),
      ),
    );
  }
}
