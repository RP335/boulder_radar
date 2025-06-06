import 'package:boulder_radar/src/create_account_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'zone_boulder_list_page.dart';
import '../main.dart' as main_app;

// The main page after a user logs in.
class ZonesPage extends StatefulWidget {
  const ZonesPage({Key? key}) : super(key: key);

  @override
  State<ZonesPage> createState() => _ZonesPageState();
}

class _ZonesPageState extends State<ZonesPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _zonesFuture;

  @override
  void initState() {
    super.initState();
    _zonesFuture = _fetchZones();
  }

  Future<List<Map<String, dynamic>>> _fetchZones() async {
    try {
      final List<Map<String, dynamic>> data =
          await _supabase.from('zones').select();
      return data;
    } on PostgrestException catch (error) {
      // For production apps, you might want to log this error to a service
      // and show a more user-friendly message.
      throw Exception('Failed to load zones: ${error.message}');
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  // Method to handle user sign-out.

  Future<void> _signOut() async {
    try {
      print('*** Starting sign out process...');
      await Supabase.instance.client.auth.signOut();
      print('*** Sign out completed');

      // Add a small delay and force navigation if still mounted
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 500));

        // Check if we're still on the same page after auth should have changed
        final currentSession = Supabase.instance.client.auth.currentSession;
        if (currentSession == null && mounted) {
          print('*** Forcing navigation to CreateAccountPage');
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const CreateAccountPage()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('*** Sign out error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        // The title is updated to "Craglist" with white, bold text for visibility.
        title: const Text(
          'Craglist',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        // This prevents the automatic back button from appearing.
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey.shade900,
        elevation: 0,
        // We add an 'actions' widget to hold the logout button.
        actions: [
          IconButton(
            tooltip: 'Sign Out', // Provides helpful text on hover/long-press.
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut, // Calls the sign-out method.
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _zonesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading zones:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            );
          }
          final zones = snapshot.data;
          if (zones == null || zones.isEmpty) {
            return const Center(
              child: Text(
                'No zones found.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          // The rest of the body remains the same as our previous update.
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Image.asset(
                    'assets/images/Climbing-pana_1.png',
                    height: 200,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Chalk up, folks!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Where are we climbing today?',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GridView.builder(
                    itemCount: zones.length,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.1,
                    ),
                    itemBuilder: (context, index) {
                      final zone = zones[index];
                      final zoneId = zone['id'] as String;
                      final zoneName =
                          zone['name'] as String? ?? 'Unnamed Zone';
                      return GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ZoneBoulderListPage(
                                zoneId: zoneId,
                                zoneName: zoneName,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(2, 2),
                              )
                            ],
                          ),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                zoneName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
