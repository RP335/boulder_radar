import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'boulder_detail_page.dart';
import 'add_boulder_page.dart';

enum BoulderSortOrder { distance, grade }

enum GradeSystem { vScale, font }

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
  final _searchController = TextEditingController();

  final Map<String, int> _vScaleSortMap = {
    'V0': 0,
    'V1': 1,
    'V2': 2,
    'V3': 3,
    'V4': 4,
    'V5': 5,
    'V6': 6,
    'V7': 7,
    'V8': 8,
    'V9': 9,
    'V10': 10,
    'V11': 11,
    'V12': 12,
    'V13': 13,
    'V14': 14,
    'V15': 15,
    'V16': 16,
    'V17': 17,
  };

  final Map<String, int> _fontScaleSortMap = {
    '4': 0,
    '5': 1,
    '5+': 2,
    '6A': 3,
    '6A+': 4,
    '6B': 5,
    '6B+': 6,
    '6C': 7,
    '6C+': 8,
    '7A': 9,
    '7A+': 10,
    '7B': 11,
    '7B+': 12,
    '7C': 13,
    '7C+': 14,
    '8A': 15,
    '8A+': 16,
    '8B': 17,
    '8B+': 18,
    '8C': 19,
    '8C+': 20,
    '9A': 21,
  };
  // --- END NEW ---

  List<Map<String, dynamic>> _allBoulders = [];
  List<Map<String, dynamic>> _displayedBoulders = [];
  Future<void>? _fetchFuture;

  BoulderSortOrder _sortOrder = BoulderSortOrder.distance;
  GradeSystem _gradeSystem = GradeSystem.vScale;

  @override
  void initState() {
    super.initState();
    _fetchFuture = _fetchAndSetBoulders();
    _searchController.addListener(_filterAndSortBoulders);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndSetBoulders() async {
    try {
      final boulders = await _fetchNearbyBouldersInZone(widget.zoneId);
      if (mounted) {
        setState(() {
          _allBoulders = List.from(boulders);
          _filterAndSortBoulders();
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _refreshBoulders() async {
    setState(() {
      _searchController.clear();
      _allBoulders = [];
      _displayedBoulders = [];
      _fetchFuture = _fetchAndSetBoulders();
    });
  }

  // --- MODIFIED: Main filtering and sorting logic ---
  void _filterAndSortBoulders() {
    List<Map<String, dynamic>> workingList = List.from(_allBoulders);

    // 1. Apply search filter first
    final String query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      workingList = workingList.where((boulder) {
        final name = boulder['name']?.toString().toLowerCase() ?? '';
        final grade = boulder['grade']?.toString().toLowerCase() ?? '';
        return name.contains(query) || grade.contains(query);
      }).toList();
    }

    // 2. If sorting by grade, FILTER by the selected grade system first
    if (_sortOrder == BoulderSortOrder.grade) {
      workingList = workingList.where((boulder) {
        final grade = boulder['grade']?.toString().toUpperCase() ?? '';
        if (_gradeSystem == GradeSystem.vScale) {
          return _vScaleSortMap.containsKey(grade);
        } else {
          // Font
          return _fontScaleSortMap.containsKey(grade);
        }
      }).toList();
    }

    // 3. Apply sorting to the (now filtered) list
    workingList.sort((a, b) {
      if (_sortOrder == BoulderSortOrder.distance) {
        final num da = (a['distance_m'] ?? double.infinity) as num;
        final num db = (b['distance_m'] ?? double.infinity) as num;
        return da.compareTo(db);
      } else {
        // Grade sorting
        final gradeA = a['grade']?.toString().toUpperCase() ?? '';
        final gradeB = b['grade']?.toString().toUpperCase() ?? '';
        num valueA = _getGradeValue(gradeA, _gradeSystem);
        num valueB = _getGradeValue(gradeB, _gradeSystem);
        return valueA.compareTo(valueB);
      }
    });

    if (mounted) {
      setState(() {
        _displayedBoulders = workingList;
      });
    }
  }

  // --- MODIFIED: Use the new lookup maps for sorting ---
  num _getGradeValue(String grade, GradeSystem system) {
    final gradeUpper = grade.toUpperCase();
    if (system == GradeSystem.vScale) {
      return _vScaleSortMap[gradeUpper] ?? 999; // Return 999 if not in map
    } else {
      // Font
      return _fontScaleSortMap[gradeUpper] ?? 999;
    }
  }
  // --- END MODIFICATIONS ---

  Future<List<Map<String, dynamic>>> _fetchNearbyBouldersInZone(
      String zoneId) async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permissions are denied. Please enable them in app settings.');
      }

      final Position pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 10));

      const int radiusMeters = 1000000;

      final FunctionResponse funcResponse = await _supabase.functions.invoke(
        'fetch-nearby-boulders',
        body: {
          'user_lat': pos.latitude,
          'user_lng': pos.longitude,
          'radius_meters': radiusMeters
        },
      ).timeout(const Duration(seconds: 20));

      if (funcResponse.status != 200) {
        throw Exception(
            'Edge function failed with status: ${funcResponse.status}. ${funcResponse.data?['error']}');
      }
      if (funcResponse.data == null) return [];

      final List<dynamic> rawList = funcResponse.data as List<dynamic>;

      final List<Map<String, dynamic>> filtered = rawList
          .whereType<Map<String, dynamic>>()
          .where((b) => b['zone_id'] == zoneId)
          .toList();

      return filtered;
    } on TimeoutException {
      throw Exception('The operation timed out. Please try again.');
    } catch (e) {
      print('Error in _fetchNearbyBouldersInZone: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text(
          widget.zoneName,
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        backgroundColor: Colors.grey.shade800,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshBoulders,
            tooltip: 'Refresh Boulders',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search boulders by name or grade...',
                hintStyle: TextStyle(color: Colors.grey.shade500),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.grey.shade800,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: SegmentedButton<BoulderSortOrder>(
                    style: _segmentedButtonStyle(),
                    segments: const [
                      ButtonSegment(
                        value: BoulderSortOrder.distance,
                        icon: Icon(Icons.location_on_outlined),
                        tooltip: 'Sort by Distance',
                      ),
                      ButtonSegment(
                        value: BoulderSortOrder.grade,
                        icon: Icon(Icons.stacked_line_chart_outlined),
                        tooltip: 'Sort by Grade',
                      ),
                    ],
                    selected: {_sortOrder},
                    onSelectionChanged: (newSelection) {
                      setState(() {
                        _sortOrder = newSelection.first;
                        _filterAndSortBoulders();
                      });
                    },
                  ),
                ),
                if (_sortOrder == BoulderSortOrder.grade) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: SegmentedButton<GradeSystem>(
                      style: _segmentedButtonStyle(),
                      segments: const [
                        ButtonSegment(
                            value: GradeSystem.vScale, label: Text('V-Scale')),
                        ButtonSegment(
                            value: GradeSystem.font, label: Text('Font')),
                      ],
                      selected: {_gradeSystem},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _gradeSystem = newSelection.first;
                          _filterAndSortBoulders();
                        });
                      },
                    ),
                  )
                ]
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<void>(
              future: _fetchFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _buildErrorState(snapshot.error.toString());
                }

                if (_allBoulders.isEmpty) {
                  return _buildEmptyState('No boulders found in this zone.');
                }

                if (_displayedBoulders.isEmpty) {
                  String message = _sortOrder == BoulderSortOrder.grade
                      ? 'No boulders found for the selected grade system.'
                      : 'No boulders match your search.';
                  return _buildEmptyState(message);
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _displayedBoulders.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final b = _displayedBoulders[index];
                    return _buildBoulderTile(b);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurpleAccent,
        heroTag: 'addBoulderFab',
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AddBoulderPage(
                zoneId: widget.zoneId,
                zoneName: widget.zoneName,
              ),
            ),
          );
          if (result == true) {
            _refreshBoulders();
          }
        },
      ),
    );
  }

  ButtonStyle _segmentedButtonStyle() {
    return SegmentedButton.styleFrom(
      backgroundColor: Colors.grey.shade800,
      foregroundColor: Colors.white70,
      selectedForegroundColor: Colors.white,
      selectedBackgroundColor: Colors.deepPurple,
      side: BorderSide(color: Colors.grey.shade700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Error loading boulders:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
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
      ),
    );
  }

  Widget _buildBoulderTile(Map<String, dynamic> b) {
    final id = b['id'] as String? ?? 'unknown_id';
    final name = b['name'] as String? ?? 'Unnamed Boulder';
    final grade = b['grade'] as String? ?? '—';
    final distanceVal = b['distance_m'];
    String distanceText = '...';
    if (distanceVal is num) {
      distanceText = '${distanceVal.toStringAsFixed(0)} m away';
    }

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      color: Colors.grey.shade800,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        title: Text(name,
            style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold)),
        subtitle: Text(
          distanceText,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.deepPurpleAccent.withOpacity(0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            grade,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        onTap: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BoulderDetailPage(boulderId: id),
            ),
          );
          if (result == true) {
            _refreshBoulders();
          }
        },
      ),
    );
  }
}
