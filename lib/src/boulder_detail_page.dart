import 'package:boulder_radar/src/full_screen_map_page.dart';
import 'package:boulder_radar/widgets/boulder_location_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import 'dart:convert'; // Required for jsonEncode and jsonDecode
import 'dart:math'; // FIX: Added import for 'pi'

class BoulderDetailPage extends StatefulWidget {
  // --- CONSTRUCTOR SIMPLIFIED ---
  final String boulderId;

  const BoulderDetailPage({
    Key? key,
    required this.boulderId,
  }) : super(key: key);

  @override
  State<BoulderDetailPage> createState() => _BoulderDetailPageState();
}

class _BoulderDetailPageState extends State<BoulderDetailPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isDeleting = false;
  bool _isSaving = false; // To track saving state
  bool _isSaved = false; // To track if the boulder is already saved
  bool _didSaveOccur = false; // <-- ADD THIS FLAG

  Map<String, dynamic>? _boulderData;
  String? _error;
  String? _currentUserId; // To store the current user's ID
  OfflineManager? _offlineManager;

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id; // Get current user ID
    _fetchBoulderDetails();
    _initOfflineManager();

    _checkIfSaved(); // Check saved status on init
  }

  void _initOfflineManager() async {
    _offlineManager = await OfflineManager.create();
  }

  Future<void> _checkIfSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBoulders = prefs.getStringList('saved_boulders') ?? [];
    // Check if any saved boulder's JSON string contains the current boulder's ID
    if (mounted) {
      setState(() {
        _isSaved = savedBoulders
            .any((b) => (jsonDecode(b) as Map)['id'] == widget.boulderId);
      });
    }
  }

  // REPLACE your entire _saveBoulderForOffline function with this one.

  // Use this clean _saveBoulderForOffline function.
// And ensure the back button in your AppBar is just a simple Navigator.of(context).pop().
  Future<void> _toggleSaveState() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    if (_isSaved) {
      await _unsaveBoulder();
    } else {
      await _saveBoulderForOffline();
    }

    if (mounted) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveBoulderForOffline() async {
    if (_boulderData == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedBoulders = prefs.getStringList('saved_boulders') ?? [];
      final dataToSave = Map<String, dynamic>.from(_boulderData!);

      savedBoulders
          .removeWhere((b) => (jsonDecode(b) as Map)['id'] == dataToSave['id']);
      savedBoulders.add(jsonEncode(dataToSave));
      await prefs.setStringList('saved_boulders', savedBoulders);

      final imagesList = _boulderData!['images'] as List<dynamic>?;
      if (imagesList != null && imagesList.isNotEmpty) {
        final imageUrl =
            (imagesList[0] as Map<String, dynamic>?)?['url'] as String?;
        if (imageUrl != null) {
          await DefaultCacheManager().downloadFile(imageUrl);
        }
      }

      final location = _boulderData!['location'] as Map<String, dynamic>?;
      final coords = location?['coordinates'] as List<dynamic>?;
      if (coords != null && coords.length == 2) {
        final lon = coords[0] as double;
        final lat = coords[1] as double;
        await _downloadOfflineRegion(lon, lat, widget.boulderId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Boulder and map area saved for offline use.'),
              backgroundColor: Colors.green),
        );
        setState(() => _isSaved = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save for offline: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // lib/boulder_detail_page.dart

  // FIX: This function now correctly gets the TileStore instance
  Future<void> _unsaveBoulder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> savedBoulders = prefs.getStringList('saved_boulders') ?? [];
      savedBoulders
          .removeWhere((b) => (jsonDecode(b) as Map)['id'] == widget.boulderId);
      await prefs.setStringList('saved_boulders', savedBoulders);

      // Use await TileStore.createDefault()
      final tileStore = await TileStore.createDefault();
      await tileStore.removeRegion(widget.boulderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Removed from offline storage.'),
              backgroundColor: Colors.orange),
        );
        setState(() => _isSaved = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to unsave: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  // FIX: This function now correctly gets the TileStore and calls loadTileRegion
  Future<void> _downloadOfflineRegion(
      double lon, double lat, String boulderId) async {
    // Use await TileStore.createDefault()
    final tileStore = await TileStore.createDefault();

    var latRad = lat * pi / 180.0;
    var lonRad = lon * pi / 180.0;
    const radiusKm = 10.0;
    const earthRadiusKm = 6371.0;
    var dLat = radiusKm / earthRadiusKm;
    var dLon = radiusKm / (earthRadiusKm * cos(latRad));

    final minLat = (latRad - dLat) * 180.0 / pi;
    final maxLat = (latRad + dLat) * 180.0 / pi;
    final minLon = (lonRad - dLon) * 180.0 / pi;
    final maxLon = (lonRad + dLon) * 180.0 / pi;

    final bounds = CoordinateBounds(
      southwest: Point(coordinates: Position(minLon, minLat)),
      northeast: Point(coordinates: Position(maxLon, maxLat)),
      infiniteBounds: false,
    );

    final tilesetDescriptor = TilesetDescriptorOptions(
      styleURI: MapboxStyles.SATELLITE_STREETS,
      minZoom: 10,
      maxZoom: 16,
    );

    final options = TileRegionLoadOptions(
      geometry: Polygon(coordinates: [
        [
          bounds.southwest.coordinates,
          Position(bounds.northeast.coordinates.lng,
              bounds.southwest.coordinates.lat),
          bounds.northeast.coordinates,
          Position(bounds.southwest.coordinates.lng,
              bounds.northeast.coordinates.lat),
          bounds.southwest.coordinates,
        ]
      ]).toJson(),
      descriptorsOptions: [tilesetDescriptor],
      acceptExpired: false,
      networkRestriction: NetworkRestriction.NONE,
      metadata: {'boulderId': boulderId, 'name': 'BoulderRegion'},
    );

    // Pass the progress listener directly as the third argument.
    await tileStore.loadTileRegion(
      boulderId,
      options,
      (progress) {
        // You can use this to update the UI, for example.
        print(
            'Download progress: ${progress.completedResourceCount} / ${progress.requiredResourceCount}');
      },
    );
  }

  Future<void> _fetchBoulderDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'get-boulder-details', // Your new Edge Function name
        body: {'bid': widget.boulderId},
      );

      if (!mounted) return;

      if (response.status == 200 && response.data != null) {
        setState(() {
          _boulderData = response.data as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        final errorMessage = response.data?['error']?.toString() ??
            'Failed to load boulder details. Status: ${response.status}';
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
        print('Error fetching boulder: $errorMessage');
      }
    } catch (e) {
      if (!mounted) return;
      print('Exception fetching boulder: $e');
      setState(() {
        _error = 'An unexpected error occurred: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteBoulder(String id, String name) async {
    if (!mounted) return;
    setState(() => _isDeleting = true);
    try {
      await _supabase.from('boulders').delete().eq('id', id);
      // If no exception, it's successful.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('"$name" deleted successfully.'),
            backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true); // Pop with success
    } on PostgrestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to delete: ${e.message}'),
            backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _launchMapsUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch map: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey.shade900,
        appBar: AppBar(
          title: const Text('Loading Boulder...'),
          centerTitle: true,
          backgroundColor: Colors.grey.shade800,
        ),
        body:
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null || _boulderData == null) {
      return Scaffold(
        backgroundColor: Colors.grey.shade900,
        appBar: AppBar(
          title: const Text('Error'),
          centerTitle: true,
          backgroundColor: Colors.grey.shade800,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _error ?? 'Failed to load boulder details.',
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _fetchBoulderDetails,
                  child: const Text('Retry'),
                )
              ],
            ),
          ),
        ),
      );
    }

    // Extract data from _boulderData
    final id = _boulderData!['id'] as String? ?? '';
    final name = _boulderData!['name'] as String? ?? 'Unnamed Boulder';
    final grade = _boulderData!['grade'] as String? ?? '—';
    final description = _boulderData!['description'] as String? ?? '';
    final uploadedBy = _boulderData!['uploaded_by'] as String?;

    final areaName = _boulderData!['area_name'] as String? ?? 'Unknown Area';
    final zoneName = _boulderData!['zone_name'] as String? ?? 'Unknown Zone';

    final locationData = _boulderData!['location'] as Map<String, dynamic>?;
    final coordinates = locationData?['coordinates'] as List<dynamic>?;
    final longitude =
        coordinates?.isNotEmpty == true ? coordinates![0]?.toString() : null;
    final latitude =
        coordinates?.length == 2 ? coordinates![1]?.toString() : null;

    // Images (taking the first boulder image if available)
    final imagesList = _boulderData!['images'] as List<dynamic>?;
    String? primaryImageUrl;
    if (imagesList != null && imagesList.isNotEmpty) {
      final firstImage = imagesList[0] as Map<String, dynamic>?;
      primaryImageUrl = firstImage?['url'] as String?;
    } else {
      primaryImageUrl = null;
    }

// Landmarks - same approach
    final landmarksList = _boulderData!['landmarks'] as List<dynamic>?;
    String landmarkDescription;
    if (landmarksList != null && landmarksList.isNotEmpty) {
      final firstLandmark = landmarksList[0] as Map<String, dynamic>?;
      landmarkDescription = firstLandmark?['description'] as String? ?? '';
    } else {
      landmarkDescription = '';
    }

    // Determine if the current user can delete this boulder
    final bool canDelete =
        (_currentUserId != null && uploadedBy == _currentUserId);

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title:
            const Text('Boulder Deets', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        backgroundColor:
            Colors.grey.shade800, // Slightly different shade for AppBar
        elevation: 1,
        actions: [
          if (canDelete) // Conditionally show the delete button
            IconButton(
              tooltip: "Delete Boulder",
              icon: _isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Icon(Icons.delete_forever_outlined,
                      color: Colors.white), // Explicitly set icon color
              onPressed: (_isDeleting || id.isEmpty)
                  ? null
                  : () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Boulder?'),
                          content: Text(
                              'Are you sure you want to delete "$name"? This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text('Delete',
                                  style: TextStyle(color: Colors.redAccent)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        _deleteBoulder(id, name);
                      }
                    },
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (primaryImageUrl != null && primaryImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                child: Image.network(
                  primaryImageUrl,
                  fit: BoxFit
                      .contain, // Changed from BoxFit.cover to BoxFit.contain
                  width: double.infinity,
                  // Removed fixed height to allow image to determine its aspect ratio within bounds
                  // height: 250,
                  loadingBuilder: (BuildContext context, Widget child,
                      ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child;
                    // Maintain a placeholder aspect ratio or min height during loading if desired
                    return AspectRatio(
                      aspectRatio: 16 / 9, // Or another common aspect ratio
                      child: Container(
                        color: Colors.grey.shade800,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => AspectRatio(
                    aspectRatio: 16 / 9, // Or another common aspect ratio
                    child: Container(
                      // height: 250,
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image,
                                color: Colors.white60, size: 48),
                            SizedBox(height: 8),
                            Text('Image not available',
                                style: TextStyle(color: Colors.white60)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              AspectRatio(
                // Use AspectRatio for placeholder as well
                aspectRatio: 16 / 9,
                child: Container(
                  // Placeholder if no image
                  // height: 250,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported_outlined,
                            color: Colors.white60, size: 48),
                        SizedBox(height: 8),
                        Text('No image provided',
                            style: TextStyle(color: Colors.white60)),
                      ],
                    ),
                  ),
                ),
              ),

            // const SizedBox(height: 20),

            const SizedBox(height: 24),

            Text(
              name,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            _buildSectionTitle('Description'),
            Text(
              description.isEmpty ? 'No description provided.' : description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.85), height: 1.5),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle('Approach / Landmark'),
            Text(
              landmarkDescription.isEmpty
                  ? 'No specific approach details provided.'
                  : landmarkDescription,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.85), height: 1.5),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle('Grade'),
            Text(
              grade,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle('Coordinates'),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    (latitude != null && longitude != null)
                        // Parse string to double for display formatting
                        ? 'Lat: ${double.tryParse(latitude)?.toStringAsFixed(6) ?? latitude}, Lng: ${double.tryParse(longitude)?.toStringAsFixed(6) ?? longitude}'
                        : 'Coordinates not available.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white.withOpacity(0.8)),
                  ),
                ),
                // Only show the copy button if coordinates exist
                if (latitude != null && longitude != null)
                  IconButton(
                    icon: Icon(
                      Icons.copy,
                      size: 20.0,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    tooltip: 'Copy Coordinates',
                    onPressed: () {
                      // The original, full-precision strings are used for copying
                      final String coordinatesToCopy = '$latitude,$longitude';
                      Clipboard.setData(ClipboardData(text: coordinatesToCopy))
                          .then((_) {
                        // Show a confirmation message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Coordinates copied to clipboard!'),
                            behavior: SnackBarBehavior.floating,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open in Google Maps'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent.withOpacity(0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: (latitude != null && longitude != null)
                    ? () => _launchMapsUrl(
                        'https://maps.google.com/?q=$latitude,$longitude')
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            _buildSectionTitle('Location Map'),
            const SizedBox(height: 4),
            if (latitude != null && longitude != null)
              _MapPreview(
                latitude: latitude,
                longitude: longitude,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullScreenMapPage(
                        boulderLatitude: double.parse(latitude!),
                        boulderLongitude: double.parse(longitude!),
                      ),
                    ),
                  );
                },
              )
            else
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Location not available',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              ),
            const SizedBox(height: 20),

            // In your build method's Column, use this button code
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.0))
                    : Icon(_isSaved
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_download_outlined),
                label:
                    Text(_isSaved ? 'Saved Offline' : 'Save for Offline Use'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _isSaved ? Colors.indigo : Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isSaving
                    ? null
                    : _toggleSaveState, // Use the toggle function
              ),
            ),
            const SizedBox(height: 30), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _MapPreview extends StatelessWidget {
  final String latitude;
  final String longitude;
  final VoidCallback onTap;

  const _MapPreview({
    required this.latitude,
    required this.longitude,
    required this.onTap,
  });

  static const String _mapboxAccessToken =
      '';

  @override
  Widget build(BuildContext context) {
    final lon = Uri.encodeComponent(longitude);
    final lat = Uri.encodeComponent(latitude);
    final String staticMapUrl =
        'https://api.mapbox.com/styles/v1/mapbox/streets-v11/static/'
        'pin-s($lon,$lat)/' // Using a standard small pin
        '$lon,$lat,14,0/600x400?access_token=$_mapboxAccessToken';

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              Image.network(
                staticMapUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade800,
                    child: const Center(
                        child:
                            CircularProgressIndicator(color: Colors.white70)),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  // This will help you see the exact error in your debug console.
                  print('--- MAP PREVIEW FAILED TO LOAD ---');
                  print('Error: $error');
                  print('URL: $staticMapUrl');
                  print('---------------------------------');

                  return Container(
                    color: Colors.grey.shade800,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.map_outlined,
                            color: Colors.white60, size: 48),
                        SizedBox(height: 8),
                        Text('Could not load map preview',
                            style: TextStyle(color: Colors.white60)),
                      ],
                    ),
                  );
                },
              ),
              // This overlay for tapping is unchanged and should work fine.
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.fullscreen, color: Colors.white, size: 40),
                      SizedBox(height: 8),
                      Text(
                        'Tap to view full map',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(blurRadius: 1, color: Colors.black87)
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
