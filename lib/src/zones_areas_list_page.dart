// lib/src/zone_areas_list_page.dart
import 'dart:async';
import 'dart:convert'; // Import for json encoding/decoding
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'package:supabase_flutter/supabase_flutter.dart';
import 'area_boulder_list_page.dart';

class ZoneAreasListPage extends StatefulWidget {
  final String zoneId;
  final String zoneName;

  const ZoneAreasListPage({
    Key? key,
    required this.zoneId,
    required this.zoneName,
  }) : super(key: key);

  @override
  State<ZoneAreasListPage> createState() => _ZoneAreasListPageState();
}

class _ZoneAreasListPageState extends State<ZoneAreasListPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _areasFuture;
  
  // --- NEW: Tracks the offline state to show/hide the banner ---
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _areasFuture = _fetchAreasInZone();
  }

  // --- MODIFIED: Now includes caching logic ---
  Future<List<Map<String, dynamic>>> _fetchAreasInZone() async {
    // Define a unique cache key for each zone
    final cacheKey = 'cached_areas_${widget.zoneId}';
    
    try {
      // 1. TRY TO FETCH FROM NETWORK
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are denied.');
      }
      final Position pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 10));

      final response = await _supabase.rpc(
        'get_areas_in_zone_by_proximity',
        params: {
          'p_zone_id': widget.zoneId,
          'user_lat': pos.latitude,
          'user_lng': pos.longitude,
        },
      );

      final data = List<Map<String, dynamic>>.from(response);

      // 2. IF SUCCESSFUL, SAVE TO CACHE
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(cacheKey, jsonEncode(data));
      
      if (mounted) {
        setState(() => _isOffline = false);
      }
      return data;

    } catch (e) {
      // 3. IF FETCHING FAILS, TRY TO LOAD FROM CACHE
      print('Failed to fetch areas from network, trying cache. Error: $e');
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);

      if (cachedData != null) {
        if (mounted) {
          setState(() => _isOffline = true); // Set offline mode!
        }
        final List<dynamic> decodedData = jsonDecode(cachedData);
        return decodedData.cast<Map<String, dynamic>>();
      } else {
        // 4. IF NETWORK AND CACHE BOTH FAIL, show an error.
        throw Exception('Could not load areas. Please try again later.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text(widget.zoneName,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop()),
        centerTitle: true,
        backgroundColor: Colors.grey.shade800,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {
              _areasFuture = _fetchAreasInZone();
            }),
            tooltip: 'Refresh Areas',
          )
        ],
      ),
      // --- MODIFIED: Wrapped in a Column to hold the banner ---
      body: Column(
        children: [
          // --- NEW: Offline Banner ---
          if (_isOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8.0),
              color: Colors.orange.shade800,
              child: const Text(
                "You're offline. Showing cached areas.\nDistances may be outdated.",
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          // --- NEW: Expanded takes up the remaining space ---
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _areasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red)),
                    ),
                  );
                }
                final areas = snapshot.data;
                if (areas == null || areas.isEmpty) {
                  return const Center(
                    child: Text('No areas found in this zone.',
                        style: TextStyle(color: Colors.white70, fontSize: 16)),
                  );
                }
      
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: areas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final area = areas[index];
                    final areaId = area['id'] as String;
                    final areaName = area['name'] as String? ?? 'Unnamed Area';
                    final distanceVal = area['distance_m'];
                    String distanceText = '...';
                    if (distanceVal is num) {
                      distanceText = '${distanceVal.toStringAsFixed(0)} m away';
                    }
      
                    return Card(
                      elevation: 2,
                      margin: EdgeInsets.zero,
                      color: Colors.grey.shade800,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                        leading: const Icon(Icons.landscape_outlined,
                            color: Colors.tealAccent),
                        title: Text(areaName,
                            style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                        subtitle: Text(distanceText,
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey.shade400)),
                        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => AreaBoulderListPage(
                              areaId: areaId,
                              areaName: areaName,
                            ),
                          ));
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}