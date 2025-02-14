import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' hide Colors;
import 'package:intl/intl.dart';
import 'clock_duration_picker.dart';
import 'circular_duration_picker_full.dart'; // NEW: import duration picker

class EventEditPage extends StatefulWidget {
  final CalendarApi calendarApi;
  final Event? event; // if null, a new event is created
  const EventEditPage({required this.calendarApi, this.event, super.key});

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage> {
  final _titleController = TextEditingController();
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  int _durationMinutes = 60;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!.summary ?? '';
      _startDate = widget.event!.start?.dateTime?.toLocal() ??
          widget.event!.start?.date?.toLocal() ??
          DateTime.now();
      _startTime = TimeOfDay.fromDateTime(_startDate);
      _durationMinutes =
          widget.event!.end?.dateTime?.difference(_startDate).inMinutes ?? 60;
    } else {
      _startDate = DateTime.now();
      _startTime = TimeOfDay.now();
      _durationMinutes = 60;
    }
  }

  Future<void> _pickStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _startDate = pickedDate;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (pickedTime != null) {
      setState(() {
        _startTime = pickedTime;
      });
    }
  }

  Future<void> _pickDuration() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Duration"),
          content: CircularDurationPickerFull(
            initialDurationMinutes: _durationMinutes,
            onDurationSelected: (duration) {
              Navigator.of(context).pop(duration);
            },
          ),
        );
      },
    );
    if (selected != null) {
      setState(() => _durationMinutes = selected);
    }
  }

  Future<void> _saveEvent() async {
    if (_titleController.text.isEmpty ||
        _startDate == null ||
        _startTime == null ||
        _durationMinutes <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Invalid fields")));
      return;
    }
    final startDateTime = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = startDateTime.add(Duration(minutes: _durationMinutes));
    Event event = Event();
    event.summary = _titleController.text;
    event.start = EventDateTime(dateTime: startDateTime, timeZone: "UTC");
    event.end = EventDateTime(dateTime: endDateTime, timeZone: "UTC");

    try {
      if (widget.event == null) {
        // Insert new event.
        await widget.calendarApi.events.insert(event, "primary");
      } else {
        // Update existing event.
        event.id = widget.event!.id;
        await widget.calendarApi.events.update(event, "primary", event.id!);
      }
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving event: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Edit Event" : "Add Event")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Event Title"),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text("Start Date"),
              subtitle: Text(DateFormat("MMM dd, yyyy").format(_startDate)),
              onTap: _pickStartDate,
            ),
            ListTile(
              title: const Text("Start Time"),
              subtitle: Text(_startTime.format(context)),
              onTap: _pickStartTime, // NEW: use simple clock picker
            ),
            ListTile(
              title: const Text("Duration"),
              subtitle: Text("$_durationMinutes minute(s)"),
              trailing: const Icon(Icons.access_time),
              onTap: _pickDuration, // NEW: use circular duration picker
            ),
            const SizedBox(height: 32),
            ElevatedButton(
                onPressed: _saveEvent, child: const Text("Save Event"))
          ],
        ),
      ),
    );
  }
}
