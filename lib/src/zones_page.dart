import 'package:boulder_radar/src/signin_page.dart';
import 'package:boulder_radar/src/zones_areas_list_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'area_boulder_list_page.dart';

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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_zones', jsonEncode(data));
      return data;
    } catch (e) {
      print('Failed to fetch zones from network, trying cache. Error: $e');
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('cached_zones');
      if (cachedData != null) {
        return jsonDecode(cachedData).cast<Map<String, dynamic>>();
      } else {
        throw Exception('An unexpected error occurred: $e');
      }
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _zonesFuture = _fetchZones();
    });
  }

  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SignInPage()),
          (route) =>
              false, 
        );
      }
    } catch (e) {
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
        title: const Text(
          'Boulderly',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey.shade900,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
          ),
        ],
      ),
      // FIXED: Removed the incorrect 'Expanded' widget. The FutureBuilder is now the direct body.
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _zonesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Error loading zones:\nFailed to connect. Pull down to try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
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
          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: Colors.white,
            backgroundColor: Colors.grey.shade800,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Image.asset(
                    'assets/images/boulderly_image.png',
                    height: 200,
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: [
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
                                    builder: (_) => ZoneAreasListPage(
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
                      ],
                    ),
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
