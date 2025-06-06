import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'boulder_detail_page.dart'; 
import 'add_boulder_page.dart'; // Import the new page

class ZoneBoulderListPage extends StatefulWidget {
  final String zoneId;
  final String zoneName;

  const ZoneBoulderListPage({
    Key? key,
    required this.zoneId,
    required this.zoneName,
  }) : super(key: key);

  @override
  State<ZoneBoulderListPage> createState() => _ZoneBoulderListPageState();
}

class _ZoneBoulderListPageState extends State<ZoneBoulderListPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _bouldersFuture;

  @override
  void initState() {
    super.initState();
    print('ZoneBoulderListPage initState: zoneId=${widget.zoneId} (this is the target zone for filtering), zoneName=${widget.zoneName}');
    _bouldersFuture = _fetchNearbyBouldersInZone(widget.zoneId);
  }

  Future<void> _refreshBoulders() async {
    setState(() {
      _bouldersFuture = _fetchNearbyBouldersInZone(widget.zoneId);
    });
  }

  Future<List<Map<String, dynamic>>> _fetchNearbyBouldersInZone(
    String zoneId) async {
    print('Starting _fetchNearbyBouldersInZone for target zoneId: $zoneId');
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print('Location permission denied, requesting...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permission denied after request.');
          throw Exception('Location permissions are denied. Please enable them in app settings.');
        }
        if (permission == LocationPermission.deniedForever) {
           print('Location permission permanently denied.');
           throw Exception('Location permissions are permanently denied. Please enable them in app settings.');
        }
      }
      print('Location permission status: $permission');

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          throw Exception('Location permission not granted. Cannot fetch nearby boulders.');
      }
      
      // --- USING ACTUAL LOCATION --- (Uncomment for real use)
      final Position pos = await Geolocator.getCurrentPosition( 
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10)); 
      final double actualLat = pos.latitude;
      final double actualLng = pos.longitude;
      print('Current actual location: lat=$actualLat, lng=$actualLng');

      // --- HARDCODED TEST VALUES (COMMENT OUT FOR REAL USE) ---
      // const double testLatitude = 32.2423;
      // const double testLongitude = 77.3403; 
      // print('USING HARDCODED TEST location: lat=$testLatitude, lng=$testLongitude');
      // --- END HARDCODED TEST VALUES ---

      // Use actual location for the function call
      final double latToUse = actualLat; // Or testLatitude if testing
      final double lngToUse = actualLng; // Or testLongitude if testing

      const int radiusMeters = 10000; 

      print('Invoking Edge Function "fetch-nearby-boulders" with lat=$latToUse, lng=$lngToUse, radius=$radiusMeters');
      final FunctionResponse funcResponse = await _supabase.functions.invoke(
        'fetch-nearby-boulders', 
        body: {
          'user_lat': latToUse,  
          'user_lng': lngToUse, 
          'radius_meters': radiusMeters 
        },
      ).timeout(const Duration(seconds: 20)); 

      print('Edge Function response status: ${funcResponse.status}');
      
      if (funcResponse.status != 200) {
          print('Edge Function returned non-200 status: ${funcResponse.status}');
          String errorMessage = 'Edge function request failed with status: ${funcResponse.status}.';
          if (funcResponse.data != null && funcResponse.data is Map && funcResponse.data['error'] != null) {
            errorMessage += ' Error: ${funcResponse.data['error']}';
          } else if (funcResponse.data != null) {
            errorMessage += ' Data: ${funcResponse.data.toString().substring(0, (funcResponse.data.toString().length > 100 ? 100 : funcResponse.data.toString().length))}';
          }
          throw Exception(errorMessage);
      }

      if (funcResponse.data == null) {
        print('Edge Function returned null data despite 200 status.');
        return []; 
      }
      
      if (funcResponse.data is! List) {
        print('Edge Function data is not a List. Actual type: ${funcResponse.data.runtimeType}. Data: ${funcResponse.data}');
        if (funcResponse.data is Map && (funcResponse.data as Map).containsKey('error')) {
           final errorMessage = (funcResponse.data as Map)['error'];
           print('Edge Function returned an error object in its data: $errorMessage');
           throw Exception('Edge Function error: $errorMessage');
        }
        throw Exception('Function "fetch-nearby-boulders" did not return a list as expected. Received: ${funcResponse.data}');
      }

      final List<dynamic> rawList = funcResponse.data as List<dynamic>;
      print('Received ${rawList.length} boulders from Edge Function before filtering.');

      for (var i = 0; i < rawList.length; i++) {
        var boulderData = rawList[i];
        if (boulderData is Map) {
          print('Boulder $i name: ${boulderData['name']}, received zone_id: ${boulderData['zone_id']}');
        } else {
          print('Boulder $i is not a Map: $boulderData');
        }
      }

      final List<Map<String, dynamic>> filtered = rawList
          .whereType<Map<String, dynamic>>() 
          .where((b) {
            final boulderZoneId = b['zone_id']; 
            return boulderZoneId != null && boulderZoneId == zoneId;
          })
          .toList();
      print('Filtered list contains ${filtered.length} boulders for target zoneId $zoneId.');

      filtered.sort((a, b) {
        final num da = (a['distance_m'] ?? double.infinity) as num;
        final num db = (b['distance_m'] ?? double.infinity) as num;
        return da.compareTo(db);
      });
      
      print('Successfully fetched and processed ${filtered.length} boulders.');
      return filtered;

    } on TimeoutException catch (e) {
  print('Operation timed out (fetching location or invoking function): $e');
  throw Exception('The operation timed out. Please try again.');
} catch (e) {
  // Check if it's a Supabase function-related error
  if (e.toString().contains('FunctionException') || e.toString().contains('function')) {
    print('Function-related error: $e');
    throw Exception('Failed to call function: $e');
  }
  // Handle other specific exceptions here if needed
  print('Unexpected error: $e');
  rethrow;
} on Exception catch (e) { // Catch other exceptions, including those we throw
  print('General error in _fetchNearbyBouldersInZone: $e');
  // Re-throw to be caught by FutureBuilder
  rethrow; // Use rethrow instead of throw e
}
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text(widget.zoneName),
        centerTitle: true,
        backgroundColor: Colors.grey.shade800,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshBoulders,
            tooltip: 'Refresh Boulders',
          )
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bouldersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print('FutureBuilder error: ${snapshot.error}'); 
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Error loading boulders:\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try Again'),
                      onPressed: _refreshBoulders,
                    )
                  ],
                ),
              ),
            );
          }

          final boulders = snapshot.data;
          if (boulders == null || boulders.isEmpty) { 
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No nearby boulders found in this zone.',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                   ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: _refreshBoulders,
                  )
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: boulders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final b = boulders[index];
              final id = b['id'] as String? ?? 'unknown_id';
              final name = b['name'] as String? ?? 'Unnamed Boulder';
              final grade = b['grade'] as String? ?? '—';
              final distanceVal = b['distance_m'];
              String distanceText = 'Distance unknown';
              if (distanceVal is num) {
                distanceText = '${distanceVal.toStringAsFixed(0)} m away';
              } else if (distanceVal != null) {
                final parsedDist = num.tryParse(distanceVal.toString());
                if (parsedDist != null) {
                  distanceText = '${parsedDist.toStringAsFixed(0)} m away';
                }
              }

              return Card(
                color: Colors.grey.shade800,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grade: $grade',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        distanceText,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.deepPurpleAccent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      grade,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () async { // Make onTap async
                    final result = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BoulderDetailPage(boulderId: id),
                      ),
                    );
                    // If BoulderDetailPage pops with 'true' (meaning a deletion occurred), refresh list
                    if (result == true) {
                      _refreshBoulders();
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurpleAccent,
        heroTag: 'addBoulderFab', // Ensure unique heroTag if multiple FABs exist across routes
        child: const Icon(Icons.add),
        onPressed: () async { // Make onPressed async
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddBoulderPage(
                zoneId: widget.zoneId,
                zoneName: widget.zoneName,
              ),
            ),
          );
          // If AddBoulderPage pops with 'true' (meaning a boulder was added), refresh list
          if (result == true) {
             _refreshBoulders();
          }
        },
      ),
    );
  }
}
