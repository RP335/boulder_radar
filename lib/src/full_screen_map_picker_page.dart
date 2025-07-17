// lib/full_screen_map_picker_page.dart
import 'package:flutter/material.dart';
import 'package:boulder_radar/widgets/interactive_map_picker.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class FullScreenMapPickerPage extends StatefulWidget {
  final Point? initialPoint;

  const FullScreenMapPickerPage({
    super.key,
    this.initialPoint,
  });

  @override
  State<FullScreenMapPickerPage> createState() => _FullScreenMapPickerPageState();
}

class _FullScreenMapPickerPageState extends State<FullScreenMapPickerPage> {
  Point? _selectedPoint;

  @override
  void initState() {
    super.initState();
    // Set the initial point for the confirm button's state
    _selectedPoint = widget.initialPoint;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pinpoint the Boulder',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.grey.shade800,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(), // Close without a selection
        ),
        actions: [
          IconButton(
            tooltip: 'Confirm Location',
            icon: const Icon(Icons.check, color: Colors.white),
            // The button is disabled until a location is selected.
            onPressed: _selectedPoint == null
                ? null
                : () => Navigator.of(context).pop(_selectedPoint),
          ),
        ],
      ),
      // The body is now our fully interactive map picker.
      // It will fill the screen.
      body: InteractiveMapPicker(
        initialPoint: widget.initialPoint,
        onLocationSelected: (point) {
          // When the map picker reports a new point, update the state.
          // This will enable the 'Confirm' button.
          if (mounted) {
            setState(() {
              _selectedPoint = point;
            });
          }
        },
      ),
    );
  }
}