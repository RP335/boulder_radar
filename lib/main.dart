// lib/main.dart
import 'dart:async'; // 👈 Make sure to import this for StreamSubscription

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/create_account_page.dart'; // Assuming your pages are here now
import 'src/zones_page.dart';

const _supabaseUrl = '';

const _supabaseKey = '';


Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseKey,
  );

  runApp(const MyApp());
}

final ValueNotifier<Session?> _authNotifier = ValueNotifier<Session?>(null);
ValueNotifier<Session?> get authNotifier => _authNotifier;

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Boulder Radar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthHandler(),
    );
  }
}

class AuthHandler extends StatefulWidget {
  const AuthHandler({Key? key}) : super(key: key);

  @override
  State<AuthHandler> createState() => _AuthHandlerState();
}

class _AuthHandlerState extends State<AuthHandler> {
  late StreamSubscription<AuthState> _authSubscription;
  bool _isInitialized = false;
  Session? _lastSession; // Add this to track the last session

  @override
  void initState() {
    super.initState();
    _initializeAuth();
  }

  void _initializeAuth() {
    final supabase = Supabase.instance.client;
    
    // Set initial session
    _lastSession = supabase.auth.currentSession;
    _authNotifier.value = _lastSession;
    
    // Listen to auth changes
    _authSubscription = supabase.auth.onAuthStateChange.listen((data) {
      print('*** Auth state changed: ${data.event}');
      
      // Only update if the session actually changed
      if (_lastSession != data.session) {
        print('*** Session changed from ${_lastSession?.user?.email} to ${data.session?.user?.email}');
        _lastSession = data.session;
        _authNotifier.value = data.session;
      } else {
        print('*** Same session, ignoring duplicate event');
      }
    });

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ValueListenableBuilder<Session?>(
      valueListenable: _authNotifier,
      builder: (context, session, child) {
        print('*** ValueListenableBuilder rebuild - hasSession: ${session != null}');
        
        if (session == null) {
          print('*** Showing CreateAccountPage');
          return const CreateAccountPage();
        } else {
          print('*** Showing ZonesPage');
          return const ZonesPage();
        }
      },
    );
  }
}