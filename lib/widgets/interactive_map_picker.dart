// lib/widgets/interactive_map_picker.dart

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;

class InteractiveMapPicker extends StatefulWidget {
  final void Function(Point) onLocationSelected;

  const InteractiveMapPicker({
    Key? key,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<InteractiveMapPicker> createState() => _InteractiveMapPickerState();
}

class _InteractiveMapPickerState extends State<InteractiveMapPicker> {
  MapboxMap? _mapboxMap;
  PointAnnotation? _pointAnnotation;
  PointAnnotationManager? _pointAnnotationManager;
  String _currentMapStyle = MapboxStyles.MAPBOX_STREETS;

  Future<Uint8List> _createMarkerImage() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..color = Colors.deepPurpleAccent;
    const double radius = 30.0;
    canvas.drawCircle(const Offset(radius, radius), radius, paint);
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(radius, radius), radius * 0.3, paint);
    final img = await recorder.endRecording().toImage(
          (radius * 2).toInt(),
          (radius * 2).toInt(),
        );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Explicitly enable gestures for smooth interaction
    mapboxMap.gestures.updateSettings(
      GesturesSettings(
        pinchToZoomEnabled: true,
        scrollEnabled: true,
        rotateEnabled: false, // Disabling rotate for a simpler experience
      ),
    );

    _mapboxMap?.location.updateSettings(
      LocationComponentSettings(enabled: true),
    );

    // Prepare for point annotations
    mapboxMap.annotations.createPointAnnotationManager().then((mgr) {
      _pointAnnotationManager = mgr;
    });

    await _centerMapOnUser();
  }

  Future<void> _centerMapOnUser() async {
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        // Handle case where user denies location access
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Location permission denied. Cannot center on your location.'),
              ),
            );
        }
        return;
      }
      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));

      _mapboxMap?.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(pos.longitude, pos.latitude),
          ),
          zoom: 17.0,
        ),
        MapAnimationOptions(duration: 1500),
      );
    } catch (e) {
      debugPrint('Could not center on user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not get current location.'),
              backgroundColor: Colors.orange),
        );
      }
    }
  }

  void _onMapTap(ScreenCoordinate coordinate) async {
    final tapped = await _mapboxMap!.coordinateForPixel(coordinate);

    if (_pointAnnotation != null) {
      _pointAnnotation!.geometry = tapped;
      _pointAnnotationManager?.update(_pointAnnotation!);
    } else {
      final markerImg = await _createMarkerImage();
      _pointAnnotationManager
          ?.create(PointAnnotationOptions(
        geometry: tapped,
        image: markerImg,
        iconSize: 0.8,
      ))
          .then((ann) {
        if (mounted) setState(() => _pointAnnotation = ann);
      });
    }
    widget.onLocationSelected(tapped);
  }

  void _toggleMapStyle() {
    setState(() {
      _currentMapStyle = _currentMapStyle == MapboxStyles.SATELLITE_STREETS
          ? MapboxStyles.MAPBOX_STREETS
          : MapboxStyles.SATELLITE_STREETS;
    });
     // Update the style on the map controller
    _mapboxMap?.loadStyleURI(_currentMapStyle);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 12,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade700, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.5),
                  child: MapWidget(
                    onMapCreated: _onMapCreated,
                    onTapListener: (ctx) => _onMapTap(ctx.touchPosition),
                    // Use the optimize flag for better performance
                    styleUri: '$_currentMapStyle?optimize=true',
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: FloatingActionButton.small(
                  heroTag: 'toggleStyleFab',
                  backgroundColor: Colors.black.withOpacity(0.6),
                  onPressed: _toggleMapStyle,
                  tooltip: 'Toggle Map Style',
                  child: Icon(
                    _currentMapStyle == MapboxStyles.SATELLITE_STREETS
                        ? Icons.map_outlined
                        : Icons.satellite_alt_outlined,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            _pointAnnotation == null
                ? 'Tap map to pinpoint the boulder\'s location.'
                : 'Location selected.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _pointAnnotation == null
                  ? Colors.blueGrey[200]
                  : Colors.green[300],
              fontStyle: FontStyle.italic,
              fontWeight:
                  _pointAnnotation != null ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}