import 'package:flutter/material.dart';
import 'dart:math';

class ClockDurationPicker extends StatelessWidget {
  final List<int> durations;
  final int selectedDuration;
  final void Function(int) onDurationSelected;

  const ClockDurationPicker({
    super.key,
    required this.durations,
    required this.selectedDuration,
    required this.onDurationSelected,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = 120;
    final center = Offset(radius, radius);

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        children: durations.asMap().entries.map((entry) {
          int index = entry.key;
          int duration = entry.value;
          double angle = (2 * pi * index) / durations.length - pi / 2;
          double x = center.dx + radius * 0.7 * cos(angle) - 20;
          double y = center.dy + radius * 0.7 * sin(angle) - 20;
          return Positioned(
            left: x,
            top: y,
            child: GestureDetector(
              onTap: () => onDurationSelected(duration),
              child: CircleAvatar(
                radius: selectedDuration == duration ? 24 : 20,
                backgroundColor: selectedDuration == duration
                    ? Colors.blue
                    : Colors.grey[300],
                child: Text(
                  "$duration",
                  style: TextStyle(
                    color: selectedDuration == duration
                        ? Colors.white
                        : Colors.black,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
