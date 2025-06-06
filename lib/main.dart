// lib/main.dart
import 'dart:async'; // 👈 Make sure to import this for StreamSubscription

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'src/create_account_page.dart'; // Assuming your pages are here now
import 'src/zones_page.dart';




Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseKey,
  );

  runApp(const MyApp());
}

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
      home: const AuthStateListener(), // Use the new StatefulWidget
    );
  }
}

/// This widget listens for auth changes and displays the correct page.
class AuthStateListener extends StatefulWidget {
  const AuthStateListener({Key? key}) : super(key: key);

  @override
  State<AuthStateListener> createState() => _AuthStateListenerState();
}

class _AuthStateListenerState extends State<AuthStateListener> {
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to the auth state stream
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      // We don't need to do anything with the data, just trigger a rebuild.
      // The `build` method will then check `currentSession` and show the correct page.
      setState(() {});
    });
  }

  @override
  void dispose() {
    // Cancel the subscription when the widget is disposed to prevent memory leaks
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This build method now runs every time the auth state changes
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      // If there's no session, show CreateAccountPage as the starting point
      return const CreateAccountPage();
    } else {
      // Otherwise, the user is logged in, show the main app
      return const ZonesPage();
    }
  }
}