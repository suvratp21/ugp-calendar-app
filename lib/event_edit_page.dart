import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart';

class EventEditPage extends StatefulWidget {
  final CalendarApi calendarApi;
  final Event? event; // if null, a new event is created
  const EventEditPage({required this.calendarApi, this.event, super.key});

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage> {
  final _titleController = TextEditingController();
  DateTime? _startTime;
  DateTime? _endTime;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController.text = widget.event!.summary ?? '';
      _startTime = widget.event!.start?.dateTime?.toLocal() ??
          widget.event!.start?.date?.toLocal();
      _endTime = widget.event!.end?.dateTime?.toLocal() ??
          widget.event!.end?.date?.toLocal();
    } else {
      _startTime = DateTime.now();
      _endTime = DateTime.now().add(const Duration(hours: 1));
    }
  }

  // Separate pickers for start date and time.
  Future<void> _pickStartDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _startTime!,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _startTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
            _startTime!.hour, _startTime!.minute);
      });
    }
  }

  Future<void> _pickStartTimeOnly() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime!),
    );
    if (pickedTime != null) {
      setState(() {
        _startTime = DateTime(_startTime!.year, _startTime!.month,
            _startTime!.day, pickedTime.hour, pickedTime.minute);
      });
    }
  }

  // Separate pickers for end date and time.
  Future<void> _pickEndDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _endTime!,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _endTime = DateTime(pickedDate.year, pickedDate.month, pickedDate.day,
            _endTime!.hour, _endTime!.minute);
      });
    }
  }

  Future<void> _pickEndTimeOnly() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_endTime!),
    );
    if (pickedTime != null) {
      setState(() {
        _endTime = DateTime(_endTime!.year, _endTime!.month, _endTime!.day,
            pickedTime.hour, pickedTime.minute);
      });
    }
  }

  Future<void> _saveEvent() async {
    if (_titleController.text.isEmpty ||
        _startTime == null ||
        _endTime == null ||
        _startTime!.isAfter(_endTime!)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Invalid fields")));
      return;
    }
    Event event = Event();
    event.summary = _titleController.text;
    event.start = EventDateTime(dateTime: _startTime, timeZone: "UTC");
    event.end = EventDateTime(dateTime: _endTime, timeZone: "UTC");

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
            // Title input remains unchanged.
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: "Event Title"),
            ),
            const SizedBox(height: 16),
            // Separate Start Date Picker.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    "Start Date: ${_startTime!.toLocal().toString().split(' ')[0]}"),
                ElevatedButton(
                    onPressed: _pickStartDate, child: const Text("Pick Date"))
              ],
            ),
            const SizedBox(height: 8),
            // Separate Start Time Picker.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    "Start Time: ${TimeOfDay.fromDateTime(_startTime!).format(context)}"),
                ElevatedButton(
                    onPressed: _pickStartTimeOnly,
                    child: const Text("Pick Time"))
              ],
            ),
            const SizedBox(height: 16),
            // Separate End Date Picker.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    "End Date: ${_endTime!.toLocal().toString().split(' ')[0]}"),
                ElevatedButton(
                    onPressed: _pickEndDate, child: const Text("Pick Date"))
              ],
            ),
            const SizedBox(height: 8),
            // Separate End Time Picker.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                    "End Time: ${TimeOfDay.fromDateTime(_endTime!).format(context)}"),
                ElevatedButton(
                    onPressed: _pickEndTimeOnly, child: const Text("Pick Time"))
              ],
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
