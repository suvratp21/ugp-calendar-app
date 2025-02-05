import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' hide Colors;
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_calendar/calendar.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Google Calendar Android',
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
        await _fetchEvents();
        _showLoginMessage();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign-in failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEvents() async {
    if (_calendarApi == null) {
      setState(() {
        _errorMessage = 'Calendar API is not initialized.';
        _isLoading = false;
      });
      return;
    }

    try {
      final Events events = await _calendarApi!.events.list(
        'primary',
        timeMin: DateTime.now().toUtc(),
        timeMax: DateTime.now().add(const Duration(days: 30)).toUtc(),
      );

      setState(() {
        _events = _convertGoogleEvents(events.items ?? []);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load events: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  List<Appointment> _convertGoogleEvents(List<Event> events) {
    return events.map((event) {
      final start = _parseEventDateTime(event.start);
      final end = _parseEventDateTime(event.end);

      return Appointment(
        startTime: start,
        endTime: end,
        subject: event.summary ?? 'Untitled Event',
        color: Colors.blue,
        isAllDay: event.start?.date != null,
      );
    }).toList();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Calendar Events'),
        actions: [
          if (_currentUser != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: _handleSignOut,
            )
          else
            IconButton(
              icon: const Icon(Icons.login),
              onPressed: _handleSignIn,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _fetchEvents,
          ),
        ],
      ),
      body: _buildMainContent(),
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