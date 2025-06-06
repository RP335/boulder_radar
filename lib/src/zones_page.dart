import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:supabase/supabase.dart';
import 'zone_boulder_list_page.dart';
final supabase = Supabase.instance.client;

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
    // final res = await supabase.from('zones').select().execute(); // OLD
    // The 'supabase' variable here should be '_supabase' as defined in your class
    final List<Map<String, dynamic>> data = await _supabase // Use the class member _supabase
        .from('zones')
        .select(); // NEW: directly returns the list or throws an error

    // No 'res.error' or 'res.data' check needed here with the new pattern.
    // If 'data' is null, it's often an empty list or an error would have been thrown.
    return data; // data will be List<Map<String, dynamic>>
  } on PostgrestException catch (error) { // Catch specific Supabase errors
    throw Exception('Failed to load zones: ${error.message}');
  } catch (e) { // Catch any other errors
    throw Exception('An unexpected error occurred: $e');
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boulder Destinations'),
        centerTitle: true,
        backgroundColor: Colors.grey.shade900,
      ),
      backgroundColor: Colors.grey.shade900,
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
          final zones = snapshot.data!;
          if (zones.isEmpty) {
            return const Center(
              child: Text(
                'No zones found.',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: GridView.builder(
              itemCount: zones.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.2,
              ),
              itemBuilder: (context, index) {
                final zone = zones[index];
                final zoneId = zone['id'] as String;
                final zoneName = zone['name'] as String? ?? 'Unnamed Zone';
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
                      color: Colors.grey.shade800, // instead of shade850
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
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
                );
              },
            ),
          );
        },
      ),
    );
  }
}
