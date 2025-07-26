// lib/widgets/boulder_location_map.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as dotenv;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:http/http.dart' as http;

class BoulderLocationMap extends StatefulWidget {
  final double boulderLatitude;
  final double boulderLongitude;
  final bool isOffline;

  const BoulderLocationMap({
    Key? key,
    required this.boulderLatitude,
    required this.boulderLongitude,
    this.isOffline = false,
  }) : super(key: key);

  @override
  State<BoulderLocationMap> createState() => _BoulderLocationMapState();
}

class _BoulderLocationMapState extends State<BoulderLocationMap> {
  static final String _mapboxAccessToken =
      dotenv.get('MAPBOX_ACCESS_TOKEN' as Uri) as String;

  mapbox.MapboxMap? _mapboxMap;
  mapbox.PointAnnotationManager? _pointAnnotationManager;
  geo.Position? _userPosition;
  bool _isLoading = true;
  String? _error;
  String _currentMapStyle = mapbox.MapboxStyles.MAPBOX_STREETS;

  // Performance optimization: Cache the marker image
  Uint8List? _cachedMarkerImage;
  bool _isRouteLoaded = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Pre-generate marker image for better performance
    _cachedMarkerImage = await _createBoulderMarkerImage();

    // Only get user location if we are online and need to draw a route
    // if (!widget.isOffline) {
    //   await _getUserLocation();
    // }
    await _getUserLocation();

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getUserLocation() async {
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        setState(() => _error = "Location permission denied to show route.");
        return;
      }
      _userPosition = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
    } catch (e) {
      print("Could not get user location: ${e.toString()}");
    }
  }

  /// Creates a custom marker image - cached for performance
  Future<Uint8List> _createBoulderMarkerImage() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    const double radius = 30.0; // Slightly smaller for better performance
    const double strokeWidth = 3.0;

    // Draw outer circle with stroke
    canvas.drawCircle(const Offset(radius, radius), radius, paint);

    // Draw stroke
    paint
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(
        const Offset(radius, radius), radius - strokeWidth / 2, paint);

    // Draw inner circle
    paint
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(radius, radius), radius * 0.35, paint);

    final img = await recorder.endRecording().toImage(
          (radius * 2).toInt(),
          (radius * 2).toInt(),
        );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  Future<void> _onMapCreated(mapbox.MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Optimized gesture settings for smooth interaction
    await _mapboxMap?.gestures.updateSettings(mapbox.GesturesSettings(
      pinchToZoomEnabled: true,
      scrollEnabled: true,
      rotateEnabled: true,
      doubleTapToZoomInEnabled: true,
      doubleTouchToZoomOutEnabled: true,
      quickZoomEnabled: true,
      pitchEnabled: false, // Disable pitch for better performance
      simultaneousRotateAndPinchToZoomEnabled: true,
      focalPoint: null, // Let system handle focal point
    ));

    // Optimize location component settings
// lib/widgets/boulder_location_map.dart -> Correction

    await _mapboxMap?.location.updateSettings(mapbox.LocationComponentSettings(
      enabled: true, // Always enable the location puck
      pulsingEnabled:
          true, // Optional: A pulsing effect can be nice for visibility
      showAccuracyRing: true, // Optional: Shows the GPS accuracy
    ));

    // Add boulder marker using cached image
    if (_cachedMarkerImage != null) {
      await _addBoulderMarker(_cachedMarkerImage!);
    }

    // Handle route and camera positioning
    if (_userPosition != null && !widget.isOffline) {
      await _fetchRouteAndDraw();
      await _zoomToFitRoute();
    } else {
      // Smooth camera transition to boulder location
      await _mapboxMap?.flyTo(
        mapbox.CameraOptions(
          center: mapbox.Point(
              coordinates: mapbox.Position(
                  widget.boulderLongitude, widget.boulderLatitude)),
          zoom: 15.0,
          pitch: 0.0, // Keep flat for better performance
        ),
        mapbox.MapAnimationOptions(
          duration: 800, // Shorter duration for snappier feel
          // No easing specified - uses default which is optimized
        ),
      );
    }
  }

  /// Optimized marker addition with cached image
  Future<void> _addBoulderMarker(Uint8List markerImage) async {
    try {
      _pointAnnotationManager ??=
          await _mapboxMap?.annotations.createPointAnnotationManager();

      final options = mapbox.PointAnnotationOptions(
        geometry: mapbox.Point(
            coordinates: mapbox.Position(
                widget.boulderLongitude, widget.boulderLatitude)),
        image: markerImage,
        iconSize: 0.7, // Slightly smaller for better performance
        iconAnchor: mapbox.IconAnchor.CENTER,
        // Remove the invalid parameters - these aren't available in PointAnnotationOptions
      );

      await _pointAnnotationManager?.create(options);
    } catch (e) {
      print("Error adding boulder marker: $e");
    }
  }

  Future<void> _fetchRouteAndDraw() async {
    if (widget.isOffline || _userPosition == null || _isRouteLoaded) {
      return;
    }

    final origin = _userPosition!;
    final destination = mapbox.Point(
        coordinates:
            mapbox.Position(widget.boulderLongitude, widget.boulderLatitude));

    // Optimized route URL with additional parameters for better performance
    final url = 'https://api.mapbox.com/directions/v5/mapbox/walking/'
        '${origin.longitude},${origin.latitude};'
        '${destination.coordinates.lng},${destination.coordinates.lat}'
        '?geometries=geojson'
        '&overview=simplified' // Use simplified geometry for better performance
        '&steps=false' // Disable steps if not needed
        '&access_token=$_mapboxAccessToken';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final route = data['routes'][0]['geometry'];

        // Check if source exists before adding
        final sourceExists =
            await _mapboxMap?.style.styleSourceExists('route-source') ?? false;
        if (!sourceExists) {
          await _mapboxMap?.style.addSource(mapbox.GeoJsonSource(
            id: 'route-source',
            data: json.encode(route),
            // Performance optimization: disable clustering and line metrics
            cluster: false,
            lineMetrics: false,
          ));
        } else {
          // Use setStyleSourceProperty to update existing source
          await _mapboxMap?.style.setStyleSourceProperty(
            'route-source',
            'data',
            json.encode(route),
          );
        }

        // Add layer only if it doesn't exist
        final layerExists =
            await _mapboxMap?.style.styleLayerExists('route-layer') ?? false;
        if (!layerExists) {
          await _mapboxMap?.style.addLayer(mapbox.LineLayer(
            id: 'route-layer',
            sourceId: 'route-source',
            lineColor:
                Colors.deepPurple.value, // Slightly darker for better contrast
            lineWidth: 4.0, // Slightly thinner for better performance
            lineOpacity: 0.9,
            // Performance optimizations
            lineCap: mapbox.LineCap.ROUND,
            lineJoin: mapbox.LineJoin.ROUND,
            // Use mapbox.Visibility instead of Flutter's Visibility
            visibility: mapbox.Visibility.VISIBLE,
          ));
        }

        _isRouteLoaded = true;
      } else {
        throw Exception('Failed to load route: ${response.statusCode}');
      }
    } on SocketException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Offline: Could not fetch walking directions."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching directions: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _zoomToFitRoute() async {
    if (_userPosition == null || _mapboxMap == null) return;

    try {
      // Create padding - don't use const since MbxEdgeInsets constructor isn't const
      final padding = mapbox.MbxEdgeInsets(
        top: 80.0,
        left: 40.0,
        bottom: 80.0,
        right: 40.0,
      );

      final cameraOptions = await _mapboxMap!.cameraForCoordinates(
        [
          mapbox.Point(
            coordinates: mapbox.Position(
              _userPosition!.longitude,
              _userPosition!.latitude,
            ),
          ),
          mapbox.Point(
            coordinates: mapbox.Position(
              widget.boulderLongitude,
              widget.boulderLatitude,
            ),
          ),
        ],
        padding,
        null, // bearing
        0.0, // pitch - keep flat for better performance
      );

      await _mapboxMap?.flyTo(
        cameraOptions,
        mapbox.MapAnimationOptions(
          duration: 1200, // Slightly faster animation
        ),
      );
    } catch (e) {
      print("Error fitting route to camera: $e");
    }
  }

  Future<void> _toggleMapStyle() async {
    final newStyle = _currentMapStyle == mapbox.MapboxStyles.SATELLITE_STREETS
        ? mapbox.MapboxStyles.MAPBOX_STREETS
        : mapbox.MapboxStyles.SATELLITE_STREETS;

    setState(() {
      _currentMapStyle = newStyle;
    });

    // Optimized style switching with proper URL formatting
    final optimizedStyleUrl = '$newStyle?optimize=true';
    await _mapboxMap?.loadStyleURI(optimizedStyleUrl);

    // Re-add markers and route after style change
    if (_cachedMarkerImage != null) {
      // Small delay to ensure style is loaded
      await Future.delayed(const Duration(milliseconds: 100));
      await _addBoulderMarker(_cachedMarkerImage!);

      if (!widget.isOffline && _userPosition != null) {
        _isRouteLoaded = false; // Reset route loaded flag
        await _fetchRouteAndDraw();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AspectRatio(
        aspectRatio: 16 / 10,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
          ),
        ),
      );
    }

    if (_error != null) {
      return AspectRatio(
        aspectRatio: 16 / 10,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            // This styling is fine, but you could remove the borderRadius
            // for a true edge-to-edge full-screen map if you prefer.
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.5),
            child: mapbox.MapWidget(
              onMapCreated: _onMapCreated,
              // Use optimized style URL for better performance
              styleUri: '$_currentMapStyle?optimize=true',
              // MapOptions constructor doesn't have antialiasing parameter
              mapOptions: mapbox.MapOptions(
                // Optimize for performance
                pixelRatio: MediaQuery.of(context).devicePixelRatio,
              ),
            ),
          ),
        ),
        // Style toggle button
        Positioned(
          top: 10,
          right: 10,
          child: Material(
            borderRadius: BorderRadius.circular(20),
            elevation: 4,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: Icon(
                  _currentMapStyle == mapbox.MapboxStyles.SATELLITE_STREETS
                      ? Icons.map_outlined
                      : Icons.satellite_alt_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: _toggleMapStyle,
                tooltip: 'Toggle Map Style',
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Clean up resources
    _pointAnnotationManager?.deleteAll();
    _mapboxMap?.dispose();
    super.dispose();
  }
}
