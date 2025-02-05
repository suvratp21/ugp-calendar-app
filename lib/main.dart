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

  CalendarApi? _calendarApi;
  List<Appointment> _events = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      setState(() => _isLoading = true);
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account != null) {
        final authHeaders = await account.authHeaders;
        final client = GoogleAuthClient(authHeaders);
        _calendarApi = CalendarApi(client);
        await _fetchEvents();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Sign-in failed: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchEvents() async {
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
      final start = _parseEventDateTime(event.start!);
      final end = _parseEventDateTime(event.end!);

      return Appointment(
        startTime: start,
        endTime: end,
        subject: event.summary ?? 'Untitled Event',
        color: Colors.blue,
        isAllDay: event.start?.date != null,
      );
    }).toList();
  }

  DateTime _parseEventDateTime(EventDateTime dateTime) {
    if (dateTime.dateTime != null) {
      return dateTime.dateTime!.toLocal();
    }
    return dateTime.date!.toLocal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Calendar Events'),
        actions: [
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
      view: CalendarView.week,
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