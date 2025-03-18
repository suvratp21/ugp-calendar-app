import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' hide Colors;
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:awesome_notifications/awesome_notifications.dart'; // new import
import 'notification_settings.dart';
import 'settings_page.dart';
import 'event_edit_page.dart'; // new import
import 'dart:async'; // new import

void main() {
  // Initialize Awesome Notifications with a basic channel.
  AwesomeNotifications().initialize(null, [
    NotificationChannel(
      channelKey: 'basic_channel',
      channelName: 'Basic notifications',
      channelDescription: 'Notification channel for event reminders',
      defaultColor: Colors.teal,
      ledColor: Colors.white,
      importance: NotificationImportance.High,
    )
  ]);

  // Request notification permission if not already allowed.
  AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
    if (!isAllowed) {
      AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calendar App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const CalendarScreen(),
    );
  }
}

// Add a top-level notification action callback.
Future<void> onNotificationActionReceived(ReceivedAction action) async {
  // For now, simply log the action.
  print("Notification action received: ${action.buttonKeyPressed}");
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/calendar'],
  );

  GoogleSignInAccount? _currentUser;
  CalendarApi? _calendarApi;
  List<Appointment> _events = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  Timer? _timer; // new field for periodic refresh
  // New field to track event IDs for which notifications have been scheduled.
  final Set<String> _scheduledEventIds = {};
  final CalendarController _calendarController = CalendarController(); // NEW
  List<Appointment> _cachedAppointments =
      []; // NEW: cache for fetched appointments

  @override
  void initState() {
    super.initState();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account;
      });
      if (account != null) {
        _initializeGoogleSignIn();
      }
    });
    _googleSignIn.signInSilently().then((account) {
      if (account == null) {
        _handleSignIn();
      }
    });

    // Start periodic refresh of events and notifications.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (_calendarApi != null) {
        _fetchEventsForSelectedDate();
      }
    });

    // Set a top-level (static) listener instead of an inline lambda.
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onNotificationActionReceived,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calendarController.displayDate =
          DateTime.now(); // NEW: scroll to current time
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // cancel timer to avoid memory leaks
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      setState(() {
        _currentUser = account;
      });
      if (account != null) {
        _initializeGoogleSignIn();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign-in failed: ${e.toString()}';
      });
    }
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);
      final GoogleSignInAccount? account = _currentUser;
      if (account != null) {
        final authHeaders = await account.authHeaders;
        final client = GoogleAuthClient(authHeaders);
        setState(() {
          _calendarApi = CalendarApi(client);
        });
        await _fetchEventsForSelectedDate();
        _showLoginMessage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign-in failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEventsForSelectedDate() async {
    if (_calendarApi == null) {
      setState(() {
        _errorMessage = 'Calendar API is not initialized.';
        _isLoading = false;
      });
      return;
    }

    // Check if selected date is within the cached range.
    if (_cachedAppointments.isNotEmpty) {
      final earliest = _cachedAppointments
          .reduce((a, b) => a.startTime.isBefore(b.startTime) ? a : b)
          .startTime;
      final latest = _cachedAppointments
          .reduce((a, b) => a.startTime.isAfter(b.startTime) ? a : b)
          .startTime;
      if (!_selectedDate.isBefore(
              DateTime(earliest.year, earliest.month, earliest.day)) &&
          !_selectedDate
              .isAfter(DateTime(latest.year, latest.month, latest.day))) {
        final cachedFiltered = _cachedAppointments.where((appointment) {
          final d = appointment.startTime;
          return d.year == _selectedDate.year &&
              d.month == _selectedDate.month &&
              d.day == _selectedDate.day;
        }).toList();
        setState(() {
          _events = cachedFiltered;
          _isLoading = false;
        });
        return;
      }
    }

    try {
      final DateTime rangeStart =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
              .subtract(const Duration(days: 5));
      final DateTime rangeEnd = DateTime(
              _selectedDate.year, _selectedDate.month, _selectedDate.day)
          .add(const Duration(days: 5, hours: 23, minutes: 59, seconds: 59));

      final Events events = await _calendarApi!.events.list(
        'primary',
        timeMin: rangeStart.toUtc(),
        timeMax: rangeEnd.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      _cachedAppointments = _convertGoogleEvents(events.items ?? []);
      final filteredAppointments = _cachedAppointments.where((appointment) {
        final d = appointment.startTime;
        return d.year == _selectedDate.year &&
            d.month == _selectedDate.month &&
            d.day == _selectedDate.day;
      }).toList();
      setState(() {
        _events = filteredAppointments;
        _isLoading = false;
      });

      // Schedule notifications for events in the filtered list.
      final now = DateTime.now();
      for (int i = 0; i < filteredAppointments.length; i++) {
        final appointment = filteredAppointments[i];
        if (appointment.startTime.isAfter(now)) {
          _scheduleNotificationForEvent(appointment, i);
        }
      }

      print(
          'Fetched ${events.items?.length ?? 0} events covering 5 days before and after $_selectedDate');
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load events: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<Appointment> _convertGoogleEvents(List<Event> events) {
    List<Appointment> appointments = [];
    for (var event in events) {
      final start = _parseEventDateTime(event.start);
      final end = _parseEventDateTime(event.end);

      appointments.add(
        Appointment(
          startTime: start,
          endTime: end,
          subject: event.summary ?? 'Untitled Event',
          color: Colors.blue,
          isAllDay: event.start?.date != null,
          // Store the Google event ID for editing (if available)
          notes: event.id,
        ),
      );
    }
    return appointments;
  }

  DateTime _parseEventDateTime(EventDateTime? dateTime) {
    if (dateTime == null) {
      return DateTime.now();
    }
    if (dateTime.dateTime != null) {
      return dateTime.dateTime!.toLocal();
    }
    return dateTime.date!.toLocal();
  }

  Future<void> _handleSignOut() async {
    await _googleSignIn.signOut();
    setState(() {
      _currentUser = null;
      _calendarApi = null;
      _events = [];
    });
  }

  void _showLoginMessage() {
    final snackBar = SnackBar(
      content: const Text('You have successfully logged in'),
      duration: const Duration(seconds: 1),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  // Updated helper method to schedule notification with remaining time,
  // but only schedule once per event.
  void _scheduleNotificationForEvent(Appointment appointment, int id) {
    if (appointment.notes == null ||
        _scheduledEventIds.contains(appointment.notes!)) {
      return;
    }
    _scheduledEventIds.add(appointment.notes!);

    final offset =
        Duration(minutes: NotificationSettings.defaultNotificationOffset);
    var scheduledTime = appointment.startTime.subtract(offset);
    if (scheduledTime.isBefore(DateTime.now())) {
      scheduledTime = DateTime.now().add(const Duration(seconds: 1));
    }
    final durationRemaining = appointment.startTime.difference(DateTime.now());
    final minutesRemaining = durationRemaining.inMinutes;
    final secondsRemaining = durationRemaining.inSeconds % 60;
    final remainingText = minutesRemaining > 0
        ? '$minutesRemaining minutes'
        : '$secondsRemaining seconds';

    AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'basic_channel',
        title: appointment.subject,
        body:
            'Your event "${appointment.subject}" is starting in $remainingText!',
        notificationLayout: NotificationLayout.Default,
        // Replace additionalData with payload (a Map<String, String>).
        payload: {'eventId': appointment.notes!},
      ),
      actionButtons: [
        NotificationActionButton(
          key: 'ACCEPT',
          label: 'Accept',
        ),
        NotificationActionButton(
          key: 'POSTPONE',
          label: 'Postpone',
        ),
        NotificationActionButton(
          key: 'REJECT',
          label: 'Reject',
        ),
      ],
      schedule: NotificationCalendar(
        year: scheduledTime.year,
        month: scheduledTime.month,
        day: scheduledTime.day,
        hour: scheduledTime.hour,
        minute: scheduledTime.minute,
        second: scheduledTime.second,
        millisecond: 0,
        repeats: false,
        allowWhileIdle: true,
      ),
    );
  }

  Future<void> _openEventEditPage() async {
    if (_calendarApi == null) return;
    bool? didChange = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => EventEditPage(calendarApi: _calendarApi!)),
    );
    if (didChange == true) {
      _fetchEventsForSelectedDate();
    }
  }

  // NEW: Updated _pickDate method using CalendarDatePicker for immediate selection.
  Future<void> _pickDate() async {
    final DateTime? picked = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: CalendarDatePicker(
            initialDate: _selectedDate,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            onDateChanged: (date) {
              Navigator.of(context).pop(date);
            },
          ),
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _isLoading = true;
      });
      _fetchEventsForSelectedDate();
    }
  }

  // NEW: Helper method to get full event details.
  Future<Event> _getEventDetails(String eventId) async {
    return await _calendarApi!.events.get('primary', eventId);
  }

  @override
  Widget build(BuildContext context) {
    final String formattedDate =
        DateFormat('MMMM dd, yyyy').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'Sign In':
                  _handleSignIn();
                  break;
                case 'Sign Out':
                  _handleSignOut();
                  break;
                case 'Refresh':
                  if (!_isLoading) _fetchEventsForSelectedDate();
                  break;
                case 'Settings':
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()));
                  break;
                case 'Add Event':
                  _openEventEditPage();
                  break;
              }
            },
            itemBuilder: (context) => [
              if (_currentUser == null)
                const PopupMenuItem(
                  value: 'Sign In',
                  child: Text('Sign In'),
                )
              else
                const PopupMenuItem(
                  value: 'Sign Out',
                  child: Text('Sign Out'),
                ),
              const PopupMenuItem(
                value: 'Refresh',
                child: Text('Refresh'),
              ),
              const PopupMenuItem(
                value: 'Settings',
                child: Text('Settings'),
              ),
              const PopupMenuItem(
                value: 'Add Event',
                child: Text('Add Event'),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          // Modified header: add calendar icon button in front of date.
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: _pickDate,
                ),
                GestureDetector(
                  onTap: _pickDate,
                  child: Text(
                    formattedDate,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildMainContent()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "add",
        onPressed: _openEventEditPage, // Add event
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return Center(
        child: Container(
          color: Colors.blue,
          child: SpinKitFadingFour(
            color: Colors.white,
            size: 100.0,
          ),
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    // Wrap SfCalendar with ConstrainedBox to enforce nonnegative height constraints.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 0.0),
      child: SfCalendar(
        controller: _calendarController, // NEW: pass controller
        view: CalendarView.day,
        dataSource: _CalendarDataSource(_events),
        key: ValueKey(_selectedDate),
        initialDisplayDate: _selectedDate,
        headerHeight: 0, // Hide header to remove date and time display.
        viewHeaderHeight: 0, // Hide date and day header.
        onTap: (CalendarTapDetails details) {
          if (details.appointments != null &&
              details.appointments!.isNotEmpty) {
            final Appointment tapped = details.appointments!.first;
            if (tapped.notes != null && tapped.notes!.isNotEmpty) {
              // Instead of building a basic Event, fetch full details.
              showDialog(
                context: context,
                builder: (_) => FutureBuilder<Event>(
                  future: _getEventDetails(tapped.notes!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const AlertDialog(
                        content: SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      );
                    }
                    final Event fullEvent = snapshot.data!;
                    // Collect extra details.
                    final location = fullEvent.location ?? "No location";
                    final description =
                        fullEvent.description ?? "No description";
                    final attendees = fullEvent.attendees
                            ?.map((att) => att.email)
                            .join(", ") ??
                        "No attendees";
                    return AlertDialog(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(fullEvent.summary ?? "Untitled"),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              Navigator.of(context).pop();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EventEditPage(
                                      calendarApi: _calendarApi!,
                                      event: fullEvent),
                                ),
                              ).then((didChange) {
                                if (didChange == true) {
                                  _fetchEventsForSelectedDate();
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      content: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'Start: ${DateFormat("MMM dd, yyyy hh:mm a").format(tapped.startTime)}'),
                            Text(
                                'End: ${DateFormat("MMM dd, yyyy hh:mm a").format(tapped.endTime)}'),
                            const SizedBox(height: 8),
                            Text('Location: $location'),
                            Text('Description: $description'),
                            Text('Attendees: $attendees'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }
          }
        },
        onViewChanged: (ViewChangedDetails details) {
          if (_selectedDate != details.visibleDates.first) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _selectedDate = details.visibleDates.first;
                _isLoading = true;
              });
              if (_calendarApi != null) {
                _fetchEventsForSelectedDate();
              } else {
                setState(() {
                  _isLoading = false;
                });
              }
            });
          }
        },
      ),
    );
  }
}

class _CalendarDataSource extends CalendarDataSource {
  _CalendarDataSource(List<Appointment> events) {
    appointments = events;
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final _client = http.Client();

  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}
