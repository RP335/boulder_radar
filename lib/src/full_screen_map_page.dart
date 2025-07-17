// lib/full_screen_map_page.dart
import 'package:flutter/material.dart';
import 'package:boulder_radar/widgets/boulder_location_map.dart';

class FullScreenMapPage extends StatelessWidget {
  final double boulderLatitude;
  final double boulderLongitude;

  const FullScreenMapPage({
    Key? key,
    required this.boulderLatitude,
    required this.boulderLongitude,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Interactive Map',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.grey.shade800,
        // Provide a clear way to close the full-screen view
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      // The body is just the interactive map widget
      body: BoulderLocationMap(
        boulderLatitude: boulderLatitude,
        boulderLongitude: boulderLongitude,
      ),
    );
  }
}