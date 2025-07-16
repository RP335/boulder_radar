import 'package:boulder_radar/widgets/boulder_location_map.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BoulderDetailPageOffline extends StatelessWidget {
  final Map<String, dynamic> boulderData;

  const BoulderDetailPageOffline({Key? key, required this.boulderData})
      : super(key: key);

  void _launchMapsUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch map: $url')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Extract data from boulderData
    final name = boulderData['name'] as String? ?? 'Unnamed Boulder';
    final grade = boulderData['grade'] as String? ?? '—';
    final description = boulderData['description'] as String? ?? '';

    final locationData = boulderData['location'] as Map<String, dynamic>?;
    final coordinates = locationData?['coordinates'] as List<dynamic>?;
    final longitude = coordinates != null && coordinates.isNotEmpty
        ? coordinates[0]?.toString()
        : null;
    final latitude = coordinates != null && coordinates.length > 1
        ? coordinates[1]?.toString()
        : null;

    final imagesList = boulderData['images'] as List<dynamic>?;
    String? primaryImageUrl;
    if (imagesList != null && imagesList.isNotEmpty) {
      final firstImage = imagesList[0] as Map<String, dynamic>?;
      primaryImageUrl = firstImage?['url'] as String?;
    }

    final landmarksList = boulderData['landmarks'] as List<dynamic>?;
    String landmarkDescription = '';
    if (landmarksList != null && landmarksList.isNotEmpty) {
      final firstLandmark = landmarksList[0] as Map<String, dynamic>?;
      landmarkDescription = firstLandmark?['description'] as String? ?? '';
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('Boulder Deets (Offline)',
            style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        centerTitle: true,
        backgroundColor: Colors.grey.shade800,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Image Widget (same as your original)
            if (primaryImageUrl != null && primaryImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
                // Use CachedNetworkImage instead of Image.network
                child: CachedNetworkImage(
                  imageUrl: primaryImageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  placeholder: (context, url) => AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white70),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      color: Colors.grey.shade800,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image,
                                color: Colors.white60, size: 48),
                            SizedBox(height: 8),
                            Text('Image could not be loaded',
                                style: TextStyle(color: Colors.white60)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              // Placeholder widget (same as your original)
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
            const SizedBox(height: 24),

            Text(
              name,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, 'Description'),
            Text(
              description.isEmpty ? 'No description provided.' : description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.85), height: 1.5),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, 'Approach / Landmark'),
            Text(
              landmarkDescription.isEmpty
                  ? 'No specific approach details provided.'
                  : landmarkDescription,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withOpacity(0.85), height: 1.5),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, 'Grade'),
            Text(
              grade,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            _buildSectionTitle(context, 'Coordinates'),
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

            _buildSectionTitle(context, 'Location Map'),
            const SizedBox(height: 4),
            if (latitude != null && longitude != null)
              BoulderLocationMap(
                boulderLatitude: double.parse(latitude),
                boulderLongitude: double.parse(longitude),
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
                        // THE FIX: Pass `context` as the first argument
                        // I've also updated the URL to be more robust
                        ? () => _launchMapsUrl(context,
                            'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude')
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.terrain_outlined),
                    label: const Text('Gaia GPS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withOpacity(0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: (latitude != null && longitude != null)
                        // THE FIX: Pass `context` as the first argument here as well
                        ? () => _launchMapsUrl(context,
                            'https://www.gaiagps.com/map/?loc=15/$longitude/$latitude')
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
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
