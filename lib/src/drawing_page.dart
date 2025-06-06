import 'dart:io';
import 'dart:ui' as ui; // For ui.Image and ImageShader

import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

// Represents a single continuous line drawn by the user
class DrawnLine {
  final List<Offset> path;
  final Color color;
  final double strokeWidth;

  DrawnLine(
      {required this.path, required this.color, required this.strokeWidth});
}

class DrawingPage extends StatefulWidget {
  final XFile imageXFile;

  const DrawingPage({Key? key, required this.imageXFile}) : super(key: key);

  @override
  State<DrawingPage> createState() => _DrawingPageState();
}

class _DrawingPageState extends State<DrawingPage> {
  final List<DrawnLine> _lines = <DrawnLine>[];
  List<Offset> _currentPath = [];
  Color _selectedColor = Colors.redAccent;
  double _strokeWidth = 4.0;
  ui.Image? _backgroundImage; // To hold the decoded image for CustomPainter

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageXFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _backgroundImage = frame.image;
        });
      }
    } catch (e) {
      print("Error loading image for drawing: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error loading image for drawing: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _startLine(DragStartDetails details) {
    if (_backgroundImage == null) return; // Don't draw if image not loaded
    setState(() {
      _currentPath = [details.localPosition];
    });
  }

  void _updateLine(DragUpdateDetails details) {
    if (_backgroundImage == null) return;
    setState(() {
      _currentPath.add(details.localPosition);
    });
  }

  void _endLine(DragEndDetails details) {
    if (_backgroundImage == null || _currentPath.isEmpty) return;
    setState(() {
      _lines.add(DrawnLine(
          path: List.from(_currentPath),
          color: _selectedColor,
          strokeWidth: _strokeWidth));
      _currentPath = []; // Reset for next line
    });
  }

  void _undoLastLine() {
    if (_lines.isNotEmpty) {
      setState(() {
        _lines.removeLast();
      });
    }
  }

  void _clearAllLines() {
    setState(() {
      _lines.clear();
    });
  }

  // In a real app, you'd capture the drawing as an image or save line data
  Future<void> _saveAndReturnDrawing() async {
    if (_backgroundImage == null) {
      Navigator.of(context).pop();
      return;
    }

    // 1. Create a PictureRecorder & Canvas matching the background image size
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(
        0,
        0,
        _backgroundImage!.width.toDouble(),
        _backgroundImage!.height.toDouble(),
      ),
    );

    // 2. Draw the background image onto the canvas
    canvas.drawImage(_backgroundImage!, Offset.zero, Paint());

    // 3. Draw each line on top
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final line in _lines) {
      paint.color = line.color;
      paint.strokeWidth = line.strokeWidth;
      final path = Path();
      if (line.path.isNotEmpty) {
        path.moveTo(line.path.first.dx, line.path.first.dy);
        for (var point in line.path.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // 4. End recording and convert to ui.Image
    final picture = recorder.endRecording();
    final ui.Image finalImage = await picture.toImage(
      _backgroundImage!.width,
      _backgroundImage!.height,
    );

    // 5. Convert ui.Image to PNG bytes
    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List pngBytes = byteData!.buffer.asUint8List();

    // 6. Save bytes to a temporary file
    if (kIsWeb) {
      Navigator.of(context).pop({
        'updatedImageBytes': pngBytes,
        'updatedImagePath': null,
        'has_drawings': _lines.isNotEmpty,
      });
    } else {
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/drawn_${DateTime.now().millisecondsSinceEpoch}.png';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(pngBytes);
      Navigator.of(context).pop({
        'updatedImageBytes': pngBytes,
        'updatedImagePath': tempPath,
        'has_drawings': _lines.isNotEmpty,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      appBar: AppBar(
        title: const Text("Draw Line on Boulder"),
        backgroundColor: Colors.grey.shade900,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(), // Just cancel
        ),
        actions: [
          IconButton(
            tooltip: "Undo last line",
            icon: const Icon(Icons.undo_outlined),
            onPressed: _lines.isEmpty ? null : _undoLastLine,
          ),
          IconButton(
            tooltip: "Clear all lines",
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _lines.isEmpty ? null : _clearAllLines,
          ),
          TextButton(
            onPressed: _saveAndReturnDrawing,
            child: const Text("DONE",
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _backgroundImage == null
                ? const Center(child: CircularProgressIndicator())
                : InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.1, // Allow zooming out more
                    maxScale: 5.0, // Allow zooming in more
                    child: Center(
                      child: AspectRatio(
                        aspectRatio:
                            _backgroundImage!.width / _backgroundImage!.height,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Display the original image as background for the CustomPaint
                            Positioned.fill(
                              child: RawImage(image: _backgroundImage),
                            ),
                            // CustomPaint widget for drawing lines on top
                            Positioned.fill(
                              child: CustomPaint(
                                painter: LinePainter(
                                    lines: _lines,
                                    currentPath: _currentPath,
                                    selectedColor: _selectedColor,
                                    selectedStrokeWidth: _strokeWidth),
                              ),
                            ),
                            // GestureDetector to capture drawing input
                            Positioned.fill(
                              child: GestureDetector(
                                onPanStart: _startLine,
                                onPanUpdate: _updateLine,
                                onPanEnd: _endLine,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
          // Simple Toolbar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
            color: Colors.grey.shade900,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Color pickers (simplified)
                _buildColorButton(Colors.redAccent),
                _buildColorButton(Colors.yellowAccent),
                _buildColorButton(Colors.blueAccent),
                _buildColorButton(Colors.greenAccent),
                _buildColorButton(Colors.white),
                // Stroke width adjustment (simplified)
                PopupMenuButton<double>(
                  icon: Icon(Icons.line_weight, color: Colors.white70),
                  tooltip: "Stroke Width",
                  onSelected: (double width) {
                    setState(() {
                      _strokeWidth = width;
                    });
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<double>>[
                    const PopupMenuItem<double>(
                        value: 2.0, child: Text('Thin')),
                    const PopupMenuItem<double>(
                        value: 4.0, child: Text('Medium')),
                    const PopupMenuItem<double>(
                        value: 8.0, child: Text('Thick')),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    bool isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border:
                isSelected ? Border.all(color: Colors.white, width: 3) : null,
            boxShadow: [
              BoxShadow(
                  color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))
            ]),
      ),
    );
  }
}

// CustomPainter to draw the lines
class LinePainter extends CustomPainter {
  final List<DrawnLine> lines;
  final List<Offset> currentPath; // The line currently being drawn
  final Color selectedColor;
  final double selectedStrokeWidth;

  LinePainter(
      {required this.lines,
      required this.currentPath,
      required this.selectedColor,
      required this.selectedStrokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed lines
    for (final line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeCap = StrokeCap.round
        ..strokeWidth = line.strokeWidth
        ..style = PaintingStyle.stroke;
      if (line.path.isNotEmpty) {
        Path path = Path();
        path.moveTo(line.path.first.dx, line.path.first.dy);
        for (int i = 1; i < line.path.length; i++) {
          path.lineTo(line.path[i].dx, line.path[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // Draw the current path being actively drawn
    if (currentPath.isNotEmpty) {
      final currentPaint = Paint()
        ..color = selectedColor
        ..strokeCap = StrokeCap.round
        ..strokeWidth = selectedStrokeWidth
        ..style = PaintingStyle.stroke;
      Path path = Path();
      path.moveTo(currentPath.first.dx, currentPath.first.dy);
      for (int i = 1; i < currentPath.length; i++) {
        path.lineTo(currentPath[i].dx, currentPath[i].dy);
      }
      canvas.drawPath(path, currentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) {
    return oldDelegate.lines != lines ||
        oldDelegate.currentPath != currentPath ||
        oldDelegate.selectedColor != selectedColor ||
        oldDelegate.selectedStrokeWidth != selectedStrokeWidth;
  }
}
