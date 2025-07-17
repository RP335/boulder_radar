// lib/widgets/interactive_map_picker.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;

class InteractiveMapPicker extends StatefulWidget {
  final void Function(Point) onLocationSelected;
  final Point? initialPoint;

  const InteractiveMapPicker({
    super.key,
    required this.onLocationSelected,
    this.initialPoint,
  });

  @override
  State<InteractiveMapPicker> createState() => _InteractiveMapPickerState();
}

class _InteractiveMapPickerState extends State<InteractiveMapPicker> {
  MapboxMap? _mapboxMap;
  PointAnnotation? _pointAnnotation;
  PointAnnotationManager? _pointAnnotationManager;
  String _currentMapStyle = MapboxStyles.SATELLITE_STREETS;
  Uint8List? _cachedMarkerImage;

  @override
  void initState() {
    super.initState();
    _createMarkerImage().then((image) {
      if (mounted) {
        setState(() => _cachedMarkerImage = image);
      }
    });
  }

  Future<Uint8List> _createMarkerImage() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..color = Colors.deepPurpleAccent;
    const double radius = 35.0;
    canvas.drawCircle(const Offset(radius, radius), radius, paint);
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(radius, radius), radius * 0.35, paint);
    final img = await recorder
        .endRecording()
        .toImage((radius * 2).toInt(), (radius * 2).toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _mapboxMap?.gestures.updateSettings(GesturesSettings(
      pinchToZoomEnabled: true,
      scrollEnabled: true,
      rotateEnabled: true,
      pitchEnabled: true,
    ));

    // THE FIX: This code enables the user location puck (the blue dot).
    _mapboxMap?.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
    ));

    _pointAnnotationManager =
        await _mapboxMap?.annotations.createPointAnnotationManager();

    if (widget.initialPoint != null) {
      _updateMarker(widget.initialPoint!);
      await _mapboxMap?.flyTo(
        CameraOptions(center: widget.initialPoint, zoom: 16.0),
        MapAnimationOptions(duration: 1200),
      );
    } else {
      await _centerMapOnUser();
    }
  }

  Future<void> _centerMapOnUser() async {
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) return;

      final pos = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high);
      await _mapboxMap?.flyTo(
        CameraOptions(
            center: Point(coordinates: Position(pos.longitude, pos.latitude)),
            zoom: 14.0),
        MapAnimationOptions(duration: 1500),
      );
    } catch (e) {
      debugPrint('Could not center on user: $e');
    }
  }

// NEW, CORRECTED CODE

  void _handleMapTap(MapContentGestureContext context) {
    final Point tappedPoint = context.point;
    _updateMarker(tappedPoint);
  }

  void _updateMarker(Point point) async {
    if (_cachedMarkerImage == null) return;

    if (_pointAnnotation != null) {
      _pointAnnotation!.geometry = point;
      _pointAnnotationManager?.update(_pointAnnotation!);
    } else {
      final options = PointAnnotationOptions(
        geometry: point,
        image: _cachedMarkerImage,
        iconSize: 0.8,
        iconAnchor: IconAnchor.CENTER,
      );
      final annotation = await _pointAnnotationManager?.create(options);
      if (mounted) setState(() => _pointAnnotation = annotation);
    }
    // This call is what enables the "Confirm" button.
    widget.onLocationSelected(point);
  }

  void _toggleMapStyle() {
    if (_mapboxMap == null) return;
    setState(() {
      _currentMapStyle = _currentMapStyle == MapboxStyles.SATELLITE_STREETS
          ? MapboxStyles.MAPBOX_STREETS
          : MapboxStyles.SATELLITE_STREETS;
    });
    _mapboxMap?.loadStyleURI('$_currentMapStyle?optimize=true');
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          onMapCreated: _onMapCreated,
          onTapListener: _handleMapTap,
          styleUri: '$_currentMapStyle?optimize=true',
        ),
        Positioned(
          top: 10,
          right: 10,
          child: FloatingActionButton.small(
            heroTag: 'toggleStyleFab_interactive',
            backgroundColor: Colors.black.withOpacity(0.7),
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
    );
  }
}
