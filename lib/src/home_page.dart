import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _email = '';
  bool _isLoading = false;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _checkCurrentUser();
  }

  Future<void> _checkCurrentUser() async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      setState(() {
        _userId = session.user.id;
      });
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await _supabase.auth.signOut();
      setState(() {
        _userId = null;
      });
    } 
    catch (e) {
      debugPrint('Error signing out: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out: $e')),
      );
    }

    setState(() {
      _userId = null;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If user is signed in, show a welcome + sign-out button; otherwise a placeholder.
    Widget body;
    if (_userId != null) {
      body = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '🪨 Welcome, user: $_userId',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _signOut,
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Sign Out'),
          ),
        ],
      );
    } else {
      body = Center(
        child: Text(
          'You are not signed in.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Boulder Radar Home'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: body,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // For now, just show a snackbar. Later you can navigate to "Boulders" screen, etc.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('FAB pressed – navigate somewhere')),
          );
        },
        child: const Icon(Icons.explore),
      ),
    );
  }
}
