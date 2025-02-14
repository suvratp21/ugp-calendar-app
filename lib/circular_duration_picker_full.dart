import 'package:flutter/material.dart';
import 'circular_time_picker.dart'; // Reuse circular picker widget

class CircularDurationPickerFull extends StatefulWidget {
  final int initialDurationMinutes; // total minutes
  final void Function(int durationMinutes) onDurationSelected;
  const CircularDurationPickerFull({
    super.key,
    required this.initialDurationMinutes,
    required this.onDurationSelected,
  });

  @override
  State<CircularDurationPickerFull> createState() =>
      _CircularDurationPickerFullState();
}

class _CircularDurationPickerFullState
    extends State<CircularDurationPickerFull> {
  late int selectedHours;
  late int selectedMinutes;

  // Change: Set hour options from 0 to 11.
  final List<int> hourOptions =
      List.generate(12, (index) => index); // 0 to 11 hours
  // Minute options from 0 to 55 in intervals of 5.
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
    selectedHours = widget.initialDurationMinutes ~/ 60;
    if (selectedHours > 11) selectedHours = 11; // clamp hours to maximum
    selectedMinutes = widget.initialDurationMinutes % 60;
    // Snap minutes to the closest option:
    selectedMinutes = minuteOptions.reduce((prev, curr) =>
        ((selectedMinutes - prev).abs() < (selectedMinutes - curr).abs())
            ? prev
            : curr);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Select Hours",
            style: TextStyle(fontWeight: FontWeight.bold)),
        // Circular picker for hours.
        CircularTimePicker(
          minuteOptions: hourOptions,
          selectedMinutes: selectedHours,
          onSelected: (value) {
            setState(() {
              selectedHours = value;
            });
          },
        ),
        const SizedBox(height: 20),
        const Text("Select Minutes",
            style: TextStyle(fontWeight: FontWeight.bold)),
        // Circular picker for minutes.
        CircularTimePicker(
          minuteOptions: minuteOptions,
          selectedMinutes: selectedMinutes,
          onSelected: (value) {
            setState(() {
              selectedMinutes = value;
            });
          },
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            final total = selectedHours * 60 + selectedMinutes;
            widget.onDurationSelected(total);
          },
          child: const Text("Confirm"),
        ),
      ],
    );
  }
}
