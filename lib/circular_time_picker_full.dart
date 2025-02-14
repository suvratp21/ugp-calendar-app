import 'package:flutter/material.dart';
import 'circular_time_picker.dart'; // Reuse existing circular picker widget

class CircularTimePickerFull extends StatefulWidget {
  final int initialHour;
  final int initialMinute;
  final void Function(int hour, int minute) onTimeSelected;
  const CircularTimePickerFull({
    super.key,
    required this.initialHour,
    required this.initialMinute,
    required this.onTimeSelected,
  });

  @override
  State<CircularTimePickerFull> createState() => _CircularTimePickerFullState();
}

class _CircularTimePickerFullState extends State<CircularTimePickerFull> {
  late int selectedHour;
  late int selectedMinute;

  // Modified: Use 0-11 for 12-hour format instead of 1-12.
  final List<int> hourOptions = List.generate(12, (index) => index);
  final List<int> minuteOptions = [
    0,
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55
  ];

  @override
  void initState() {
    super.initState();
    selectedHour =
        widget.initialHour; // assume initialHour is provided in 0-11 format.
    selectedMinute = widget.initialMinute;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Select Hour",
            style: TextStyle(fontWeight: FontWeight.bold)),
        // Use the generic circular picker from CircularTimePicker for hours
        CircularTimePicker(
          minuteOptions: hourOptions,
          selectedMinutes: selectedHour,
          onSelected: (value) {
            setState(() {
              selectedHour = value;
            });
          },
        ),
        const SizedBox(height: 20),
        const Text("Select Minute",
            style: TextStyle(fontWeight: FontWeight.bold)),
        CircularTimePicker(
          minuteOptions: minuteOptions,
          selectedMinutes: selectedMinute,
          onSelected: (value) {
            setState(() {
              selectedMinute = value;
            });
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => widget.onTimeSelected(selectedHour, selectedMinute),
          child: const Text("Confirm"),
        ),
      ],
    );
  }
}
