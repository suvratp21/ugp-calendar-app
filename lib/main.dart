import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' hide Colors;
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';

void main() => runApp(const MyApp());

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

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/calendar.readonly'],
  );

  GoogleSignInAccount? _currentUser;
  CalendarApi? _calendarApi;
  List<Appointment> _events = [];
  bool _isLoading = false;
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();

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

    try {
      final DateTime startOfDay =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      final DateTime endOfDay = startOfDay
          .add(const Duration(days: 1))
          .subtract(const Duration(seconds: 1));

      final Events events = await _calendarApi!.events.list(
        'primary',
        timeMin: startOfDay.toUtc(),
        timeMax: endOfDay.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      setState(() {
        _events = _convertGoogleEvents(events.items ?? []);
        _isLoading = false;
      });

      print('Fetched ${events.items?.length ?? 0} events for $_selectedDate');
      for (var event in events.items ?? []) {
        print(
            'Event: ${event.summary}, Start: ${event.start?.dateTime ?? event.start?.date}, End: ${event.end?.dateTime ?? event.end?.date}');
      }
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
                child: Text('Refresh Events'),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              formattedDate,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    return SfCalendar(
      view: CalendarView.day,
      dataSource: _CalendarDataSource(_events),
      key: ValueKey(_selectedDate),
      initialDisplayDate: _selectedDate,
      headerStyle: const CalendarHeaderStyle(
        textAlign: TextAlign.center,
      ),
      onViewChanged: (ViewChangedDetails details) {
        if (_selectedDate != details.visibleDates.first) {
          setState(() {
            _selectedDate = details.visibleDates.first;
            _isLoading = true;
          });
          _fetchEventsForSelectedDate();
        }
      },
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
