// lib/boulder_detail_page_offline.dart (Updated)

import 'package:boulder_radar/widgets/boulder_location_map.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    final firstAscentUserName =
        boulderData['first_ascent_user_name'] as String?;

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

    final staticMapUrl = boulderData['static_map_url'] as String?;

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
            if (primaryImageUrl != null && primaryImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.0),
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
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
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

            if (firstAscentUserName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                    children: [
                      TextSpan(
                        text: 'FA: ',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade600,
                            fontSize: 18),
                      ),
                      TextSpan(
                        text: firstAscentUserName,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
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

            // MODIFIED: This is now a single, full-width button
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
                    ? () => _launchMapsUrl(context,
                        'https://maps.google.com/?q=$latitude,$longitude')
                    : null,
              ),
            ),
            const SizedBox(height: 16),

            _buildSectionTitle(context, 'Location Map'),
            const SizedBox(height: 4),

            if (latitude != null && longitude != null)
              _MapPreviewOffline(
                staticMapUrl: staticMapUrl,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FullScreenMapPageOffline(
                        latitude: double.parse(latitude),
                        longitude: double.parse(longitude),
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

class _MapPreviewOffline extends StatelessWidget {
  final VoidCallback onTap;
  final String? staticMapUrl;

  const _MapPreviewOffline({required this.onTap, this.staticMapUrl});

  @override
  Widget build(BuildContext context) {
    final fallbackWidget = Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fullscreen,
                color: Colors.white.withOpacity(0.9), size: 40),
            const SizedBox(height: 8),
            Text(
              'Tap to view offline map',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12.0),
          child: (staticMapUrl != null && staticMapUrl!.isNotEmpty)
              ? CachedNetworkImage(
                  imageUrl: staticMapUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => fallbackWidget,
                  errorWidget: (context, url, error) => fallbackWidget,
                )
              : fallbackWidget,
        ),
      ),
    );
  }
}

class FullScreenMapPageOffline extends StatelessWidget {
  final double latitude;
  final double longitude;

  const FullScreenMapPageOffline({
    Key? key,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text('Offline Map', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.grey.shade800,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BoulderLocationMap(
        boulderLatitude: latitude,
        boulderLongitude: longitude,
        isOffline: true,
      ),
    );
  }
}
