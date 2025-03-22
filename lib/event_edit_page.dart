import 'package:flutter/material.dart';
import 'package:googleapis/calendar/v3.dart' hide Colors;
import 'package:intl/intl.dart';
import 'circular_duration_picker_full.dart'; // NEW: import duration picker
import 'local_members_store.dart'; // NEW: import local members store
import 'package:fluttercontactpicker/fluttercontactpicker.dart'
    hide Contact; // UPDATED: use correct package name
import 'package:contacts_service/contacts_service.dart'; // NEW: import contacts_service
import 'package:permission_handler/permission_handler.dart'; // NEW: import permission handler
import 'contacts_list_screen.dart'; // NEW: import ContactsListScreen

class EventEditPage extends StatefulWidget {
  final CalendarApi calendarApi;
  final Event? event; // if null, a new event is created
  const EventEditPage({required this.calendarApi, this.event, super.key});

  @override
  State<EventEditPage> createState() => _EventEditPageState();
}

class _EventEditPageState extends State<EventEditPage> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController(); // NEW: location
  final _descriptionController = TextEditingController(); // NEW: description
  final _attendeesController =
      TextEditingController(); // NEW: attendees (comma separated)
  final _membersController = TextEditingController(); // NEW: members

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
      // NEW: populate additional fields
      _locationController.text = widget.event!.location ?? '';
      _descriptionController.text = widget.event!.description ?? '';
      if (widget.event!.attendees != null) {
        _attendeesController.text = widget.event!.attendees!
            .map((att) => att.email ?? '')
            .where((email) => email.isNotEmpty)
            .join(", ");
      }
      // NEW: populate members if stored locally.
      if (widget.event!.id != null) {
        final members = LocalMembersStore.getMembers(widget.event!.id!);
        if (members != null) {
          _membersController.text = members.join(", ");
        }
      }
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
    if (_titleController.text.isEmpty || _durationMinutes <= 0) {
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
    // NEW: assign additional fields
    event.location = _locationController.text;
    event.description = _descriptionController.text;
    if (_attendeesController.text.isNotEmpty) {
      event.attendees = _attendeesController.text
          .split(',')
          .map((e) => EventAttendee(email: e.trim()))
          .toList();
    }

    try {
      if (widget.event == null) {
        final insertedEvent =
            await widget.calendarApi.events.insert(event, "primary");
        event.id = insertedEvent.id;
      } else {
        event.id = widget.event!.id;
        await widget.calendarApi.events.update(event, "primary", event.id!);
      }
      // NEW: Store members locally.
      LocalMembersStore.setMembers(
          event.id!,
          _membersController.text
              .split(',')
              .map((m) => m.trim())
              .where((m) => m.isNotEmpty)
              .toList());
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error saving event: $e")));
    }
  }

  // NEW: Postpone event by shifting start/end times by 15 minutes.
  Future<void> _postponeEvent() async {
    if (widget.event == null ||
        widget.event!.start?.dateTime == null ||
        widget.event!.end?.dateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot postpone a new event")));
      return;
    }
    final currentStart = widget.event!.start!.dateTime!.toLocal();
    final currentEnd = widget.event!.end!.dateTime!.toLocal();
    final newStart = currentStart.add(const Duration(minutes: 15));
    final newEnd = currentEnd.add(const Duration(minutes: 15));
    widget.event!.start =
        EventDateTime(dateTime: newStart.toUtc(), timeZone: "UTC");
    widget.event!.end =
        EventDateTime(dateTime: newEnd.toUtc(), timeZone: "UTC");
    try {
      await widget.calendarApi.events
          .update(widget.event!, "primary", widget.event!.id!);
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error postponing event: $e")));
    }
  }

  // NEW: Reject event by deleting it.
  Future<void> _rejectEvent() async {
    if (widget.event == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Cannot reject a new event")));
      return;
    }
    try {
      await widget.calendarApi.events.delete("primary", widget.event!.id!);
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error rejecting event: $e")));
    }
  }

  // UPDATED: contact picker method using flutter_contact_picker.
  Future<void> _pickContact() async {
    try {
      final FullContact contact = await FlutterContactPicker.pickFullContact();
      final String? email =
          contact.emails.isNotEmpty ? contact.emails.first.email : null;
      if (email != null && email.isNotEmpty) {
        String current = _membersController.text;
        if (current.isNotEmpty) current += ", ";
        setState(() {
          _membersController.text = current + email;
        });
      }
    } catch (e) {
      // ...error handling if needed...
    }
  }

  // NEW: show a dropdown (bottom sheet) of contacts with emails.
  Future<void> _showContactsDropdown() async {
    // Request contacts permission before accessing contacts.
    final permissionStatus = await Permission.contacts.request();
    if (!permissionStatus.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contacts permission denied")));
      return;
    }
    try {
      // Fetch contacts without thumbnails for better performance.
      Iterable<Contact> contacts =
          await ContactsService.getContacts(withThumbnails: false);
      List<Contact> contactsWithEmail = contacts
          .where((c) => c.emails != null && c.emails!.isNotEmpty)
          .toList();

      if (contactsWithEmail.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No contacts with email found")));
        return;
      }

      // Navigate to a new screen to display contacts.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ContactsListScreen(
            contacts: contactsWithEmail,
            onContactSelected: (email) {
              String current = _membersController.text;
              if (current.isNotEmpty) current += ", ";
              setState(() {
                _membersController.text = current + email;
              });
            },
          ),
        ),
      );
    } catch (e) {
      // Handle errors during contact fetching.
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching contacts: ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.event != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? "Edit Event" : "Add Event")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Event title section
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                  labelText: "Event Title", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            // --- Time-related fields inside a Card ---
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text("Start Date"),
                      subtitle:
                          Text(DateFormat("MMM dd, yyyy").format(_startDate)),
                      onTap: _pickStartDate,
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.access_time),
                      title: const Text("Start Time"),
                      subtitle: Text(_startTime.format(context)),
                      onTap: _pickStartTime,
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.timelapse),
                      title: const Text("Duration"),
                      subtitle: Text("$_durationMinutes minute(s)"),
                      trailing: const Icon(Icons.edit),
                      onTap: _pickDuration,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // --- Additional Info section inside a Card ---
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                          labelText: "Location", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                          labelText: "Description",
                          border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _attendeesController,
                      decoration: const InputDecoration(
                          labelText: "Attendees (comma separated emails)",
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    // NEW: Members field.
                    TextField(
                      controller: _membersController,
                      decoration: const InputDecoration(
                              labelText: "Members (comma separated)",
                              border: OutlineInputBorder())
                          .copyWith(
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.contacts),
                          onPressed:
                              _showContactsDropdown, // UPDATED: use dropdown helper
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveEvent,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                textStyle: const TextStyle(fontSize: 16),
              ),
              child: const Text("Save Event"),
            ),
            const SizedBox(height: 16),
            // NEW: Add postpone and reject buttons in a row.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _postponeEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                  ),
                  child: const Text("Postpone"),
                ),
                ElevatedButton(
                  onPressed: _rejectEvent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 15),
                  ),
                  child: const Text("Reject"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
