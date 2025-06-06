import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class BoulderDetailPage extends StatefulWidget {
  final String boulderId; // Changed to accept boulderId

  const BoulderDetailPage({Key? key, required this.boulderId})
      : super(key: key);

  @override
  State<BoulderDetailPage> createState() => _BoulderDetailPageState();
}

class _BoulderDetailPageState extends State<BoulderDetailPage> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isDeleting = false;
  Map<String, dynamic>? _boulderData;
  String? _error;
  String? _currentUserId; // To store the current user's ID

  @override
  void initState() {
    super.initState();
    _currentUserId = _supabase.auth.currentUser?.id; // Get current user ID
    _fetchBoulderDetails();
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
    final uploadedBy = _boulderData!['uploaded_by'] as String?; // Get uploaded_by

    // Location (Coordinates)
    final locationData = _boulderData!['location'] as Map<String, dynamic>?;
    final coordinates = locationData?['coordinates'] as List<dynamic>?;
    final longitude = coordinates != null && coordinates.isNotEmpty
        ? coordinates[0]?.toString()
        : null;
    final latitude = coordinates != null && coordinates.length > 1
        ? coordinates[1]?.toString()
        : null;

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
    final bool canDelete = (_currentUserId != null && uploadedBy == _currentUserId);


    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: Text(name),
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
                  : const Icon(Icons.delete_forever_outlined, color: Colors.white), // Explicitly set icon color
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
                  fit: BoxFit.contain, // Changed from BoxFit.cover to BoxFit.contain
                  width: double.infinity,
                  // Removed fixed height to allow image to determine its aspect ratio within bounds
                  // height: 250, 
                  loadingBuilder: (BuildContext context, Widget child,
                      ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child;
                    // Maintain a placeholder aspect ratio or min height during loading if desired
                    return AspectRatio(
                      aspectRatio: 16/9, // Or another common aspect ratio
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
                    aspectRatio: 16/9, // Or another common aspect ratio
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
              AspectRatio( // Use AspectRatio for placeholder as well
                aspectRatio: 16/9,
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

            const SizedBox(height: 20),

            // Name (already in AppBar, but can be here too if desired)
            // Text(name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
            // const SizedBox(height: 8),

            Text(
              'Grade: $grade',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
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

            _buildSectionTitle('Coordinates'),
            Text(
              (latitude != null && longitude != null)
                  ? 'Lat: $latitude, Lng: $longitude'
                  : 'Coordinates not available.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.white.withOpacity(0.8)),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('Google Maps'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: (latitude != null && longitude != null)
                        ? () => _launchMapsUrl(
                            'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude') // Ensure this Google Maps URL is correct for your needs
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.terrain_outlined), // Example icon
                    label: const Text('Gaia GPS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: (latitude != null && longitude != null)
                        // Using zoom level 15 as an example, adjust as needed. Format: ZOOM/LONGITUDE/LATITUDE
                        ? () => _launchMapsUrl(
                            'https://www.gaiagps.com/map/?loc=15/$longitude/$latitude')
                        : null,
                  ),
                ),
              ],
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