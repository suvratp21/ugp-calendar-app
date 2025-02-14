import 'package:flutter/material.dart';
import 'dart:math';

class CircularTimePicker extends StatelessWidget {
  final List<int> minuteOptions;
  final int selectedMinutes;
  final void Function(int) onSelected;

  const CircularTimePicker({
    super.key,
    required this.minuteOptions,
    required this.selectedMinutes,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = 120;
    final center = Offset(radius, radius);

    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        children: minuteOptions.asMap().entries.map((entry) {
          int index = entry.key;
          int minutes = entry.value;
          double angle = (2 * pi * index) / minuteOptions.length - pi / 2;
          double x = center.dx + radius * 0.7 * cos(angle) - 20;
          double y = center.dy + radius * 0.7 * sin(angle) - 20;
          return Positioned(
            left: x,
            top: y,
            child: GestureDetector(
              onTap: () => onSelected(minutes),
              child: CircleAvatar(
                radius: selectedMinutes == minutes ? 24 : 20,
                backgroundColor:
                    selectedMinutes == minutes ? Colors.blue : Colors.grey[300],
                child: Text(
                  "$minutes",
                  style: TextStyle(
                    color: selectedMinutes == minutes
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
