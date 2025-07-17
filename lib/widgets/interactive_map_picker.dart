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
  String _currentMapStyle = MapboxStyles.MAPBOX_STREETS;
  Uint8List? _cachedMarkerImage;

  bool _isInitializing = true;
  Point? _initialCameraCenter;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _determineInitialCenter();
    _cachedMarkerImage = await _createMarkerImage();
    
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _determineInitialCenter() async {
    if (widget.initialPoint != null) {
      _initialCameraCenter = widget.initialPoint;
      return;
    }

    try {
      final permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied || permission == geo.LocationPermission.deniedForever) {
        _initialCameraCenter = Point(coordinates: Position(0, 0));
        return;
      }
      
      final pos = await geo.Geolocator.getCurrentPosition(desiredAccuracy: geo.LocationAccuracy.high);
      if (mounted) {
         _initialCameraCenter = Point(coordinates: Position(pos.longitude, pos.latitude));
      }
    } catch (e) {
      debugPrint('Could not get user location for picker: $e');
      _initialCameraCenter = Point(coordinates: Position(0, 0));
    }
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

    _mapboxMap?.location.updateSettings(LocationComponentSettings(
      enabled: true,
      pulsingEnabled: true,
    ));

    // --- MODIFIED: Set the camera position here ---
    // This happens instantly when the map is ready, avoiding any visible pan.
    if (_initialCameraCenter != null) {
      mapboxMap.setCamera(
        CameraOptions(
          center: _initialCameraCenter,
          zoom: _initialCameraCenter!.coordinates.lat == 0 && _initialCameraCenter!.coordinates.lng == 0 ? 1.0 : 14.0,
        ),
      );
    }
    
    _pointAnnotationManager =
        await _mapboxMap?.annotations.createPointAnnotationManager();

    if (widget.initialPoint != null) {
      _updateMarker(widget.initialPoint!);
    }
  }

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
    if (_isInitializing || _initialCameraCenter == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF121212),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 20),
              Text("Finding your location...", style: TextStyle(color: Colors.white70, fontSize: 16)),
            ],
          )
        ),
      );
    }

    return Stack(
      children: [
        MapWidget(
          // --- MODIFIED: Removed the incorrect 'cameraOptions' and added the required 'pixelRatio' ---
          mapOptions: MapOptions(
            pixelRatio: MediaQuery.of(context).devicePixelRatio,
          ),
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
              _currentMapStyle == MapboxStyles.MAPBOX_STREETS
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