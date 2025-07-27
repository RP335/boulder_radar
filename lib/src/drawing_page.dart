import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// Represents a single continuous line drawn by the user. Unchanged.
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
  // The state now only needs to hold the lines and the decoded image.
  final List<DrawnLine> _lines = <DrawnLine>[];
  DrawnLine? _currentLine;
  ui.Image? _backgroundImage;
  final _transformationController = TransformationController(); // ADD THIS LINE

  // Drawing tool settings
  Color _selectedColor = Colors.redAccent;
  double _strokeWidth = 5.0; // Slightly thicker default

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  /// Decodes the image file into a format that the CustomPainter can use.
  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageXFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() {
          _backgroundImage = frame.image;
        });

        // --- THIS IS THE NEW LOGIC ---
        // Run this after the first frame is rendered.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _backgroundImage == null) return;

          // Get the size of the widget displaying the image.
          final RenderBox box = context.findRenderObject() as RenderBox;
          final viewportSize = box.size;
          final imageSize = Size(_backgroundImage!.width.toDouble(),
              _backgroundImage!.height.toDouble());

          // Calculate the scale to fit the image within the viewport.
          final scale = (viewportSize.width / imageSize.width <
                  viewportSize.height / imageSize.height)
              ? viewportSize.width / imageSize.width
              : viewportSize.height / imageSize.height;

          // Set the initial transformation on the controller.
          _transformationController.value = Matrix4.identity()..scale(scale);
        });
        // --- END OF NEW LOGIC ---
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

  // --- Core Drawing Logic ---
  // The coordinate conversion logic is no longer needed here, simplifying everything.

  void _startLine(DragStartDetails details) {
    // `details.localPosition` now directly gives us coordinates on the image.
    final Offset point = details.localPosition;
    setState(() {
      _currentLine = DrawnLine(
        path: [point],
        color: _selectedColor,
        strokeWidth: _strokeWidth,
      );
    });
  }

  void _updateLine(DragUpdateDetails details) {
    if (_currentLine == null) return;
    final Offset point = details.localPosition;
    setState(() {
      _currentLine!.path.add(point);
    });
  }

  void _endLine(DragEndDetails details) {
    if (_currentLine != null && _currentLine!.path.isNotEmpty) {
      // Add the finished line to the list of all lines and clear the current one.
      setState(() {
        _lines.add(_currentLine!);
        _currentLine = null;
      });
    }
  }

  // --- Toolbar Actions ---

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
      _currentLine = null;
    });
  }


  Future<void> _saveAndReturnDrawing() async {
    if (_backgroundImage == null) {
      Navigator.of(context).pop();
      return;
    }


    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, _backgroundImage!.width.toDouble(),
          _backgroundImage!.height.toDouble()),
    );


    canvas.drawImage(_backgroundImage!, Offset.zero, Paint());

    for (final line in _lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      if (line.path.isNotEmpty) {
        path.moveTo(line.path.first.dx, line.path.first.dy);
        for (var point in line.path.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }


    final ui.Image finalImage = await recorder.endRecording().toImage(
          _backgroundImage!.width,
          _backgroundImage!.height,
        );


    final byteData =
        await finalImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final Uint8List pngBytes = byteData.buffer.asUint8List();

    final Map<String, dynamic> result = {
      'updatedImageBytes': pngBytes,
      'has_drawings': _lines.isNotEmpty,
      'drawing_data': null, // Placeholder for future use
    };

    if (!mounted) return;
    if (kIsWeb) {
      Navigator.of(context).pop(result..addAll({'updatedImagePath': null}));
    } else {
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/drawn_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(tempPath).writeAsBytes(pngBytes);
      Navigator.of(context).pop(result..addAll({'updatedImagePath': tempPath}));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        title: const Text("Draw Line on Boulder"),
        backgroundColor: Colors.grey.shade800,
        foregroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
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
            onPressed:
                _lines.isEmpty && _currentLine == null ? null : _clearAllLines,
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
          // The main drawing area
          Expanded(
            child: Container(
              color: Colors.black, // Background for the InteractiveViewer
              child: _backgroundImage == null
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white))
                  : InteractiveViewer(
                      transformationController:
                          _transformationController, // ADD THIS LINE

                      // Set constraints to false to allow the child to be its natural size.
                      constrained: false,
                      // Set boundary margins to allow panning around the entire image.
                      boundaryMargin: const EdgeInsets.all(20.0),
                      minScale: 0.1,
                      maxScale: 4.0,
                      // The child is now a SizedBox with the exact dimensions of the image.
                      child: SizedBox(
                        width: _backgroundImage!.width.toDouble(),
                        height: _backgroundImage!.height.toDouble(),
                        // The GestureDetector captures raw pointer events in the image's own coordinate space.
                        child: GestureDetector(
                          onPanStart: _startLine,
                          onPanUpdate: _updateLine,
                          onPanEnd: _endLine,
                          // The CustomPaint widget does the actual drawing.
                          child: CustomPaint(
                            painter: DrawingPainter(
                              backgroundImage: _backgroundImage!,
                              lines: _lines,
                              currentLine: _currentLine,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          // The toolbar at the bottom
          _buildToolbar(),
        ],
      ),
    );
  }

  /// Builds the bottom toolbar for selecting colors and stroke widths.
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      color: Colors.grey.shade800,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildColorButton(Colors.redAccent[400]!),
          _buildColorButton(Colors.yellowAccent[400]!),
          _buildColorButton(Colors.blueAccent[400]!),
          _buildColorButton(Colors.greenAccent[400]!),
          _buildColorButton(Colors.white),
          const VerticalDivider(width: 24, color: Colors.transparent),
          PopupMenuButton<double>(
            tooltip: "Stroke Width",
            onSelected: (double width) => setState(() => _strokeWidth = width),
            itemBuilder: (context) => <PopupMenuEntry<double>>[
              const PopupMenuItem<double>(value: 3.0, child: Text('Thin')),
              const PopupMenuItem<double>(value: 5.0, child: Text('Medium')),
              const PopupMenuItem<double>(value: 8.0, child: Text('Thick')),
              const PopupMenuItem<double>(
                  value: 12.0, child: Text('Extra Thick')),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade700),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.line_weight, color: Colors.white),
                const SizedBox(width: 8),
                Text("${_strokeWidth.toInt()}px",
                    style: const TextStyle(color: Colors.white))
              ]),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildColorButton(Color color) {
    bool isSelected = _selectedColor == color;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.tealAccent, width: 3)
              : Border.all(color: Colors.white30, width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
        ),
      ),
    );
  }
}

/// The CustomPainter responsible for drawing the image and lines.
/// This is now much simpler as it doesn't need to handle any transformations.
class DrawingPainter extends CustomPainter {
  final ui.Image backgroundImage;
  final List<DrawnLine> lines;
  final DrawnLine? currentLine;

  DrawingPainter(
      {required this.backgroundImage, required this.lines, this.currentLine});

  @override
  void paint(Canvas canvas, Size size) {

    canvas.drawImage(backgroundImage, Offset.zero, Paint());

    // 2. Draw all the previously completed lines.
    for (final line in lines) {
      final paint = Paint()
        ..color = line.color
        ..strokeWidth = line.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      final path = Path();
      if (line.path.isNotEmpty) {
        path.moveTo(line.path.first.dx, line.path.first.dy);
        for (final point in line.path.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    // 3. Draw the line that is currently being drawn in real-time.
    if (currentLine != null && currentLine!.path.isNotEmpty) {
      final paint = Paint()
        ..color = currentLine!.color
        ..strokeWidth = currentLine!.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path();
      path.moveTo(currentLine!.path.first.dx, currentLine!.path.first.dy);
      for (final point in currentLine!.path.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) {
    // Repaint whenever the lines or the current line being drawn changes.
    return oldDelegate.lines != lines || oldDelegate.currentLine != currentLine;
  }
}
