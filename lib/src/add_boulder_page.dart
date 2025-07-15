import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // for kIsWeb

// Ensure drawing_page.dart exists in lib/src/
import 'drawing_page.dart';

enum LocationInputType { gps, manual }

class AddBoulderPage extends StatefulWidget {
  final String areaId;
  final String areaName;

  const AddBoulderPage({
    Key? key,
    required this.areaId,
    required this.areaName,
  }) : super(key: key);

  @override
  State<AddBoulderPage> createState() => _AddBoulderPageState();
}

class _AddBoulderPageState extends State<AddBoulderPage> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _landmarkDescriptionController = TextEditingController();
  final _boulderDescriptionController = TextEditingController();
  final _manualLatController = TextEditingController();
  final _manualLngController = TextEditingController();
  final _pastedCoordsController = TextEditingController();

  Uint8List? _selectedImageBytes;
  String? _selectedGrade;
  XFile? _selectedImageXFile;
  Map<String, dynamic>? _drawingResultData; // To store data from DrawingPage

  LocationInputType _locationInputType = LocationInputType.manual;
  bool _isLoading = false;
  String _submissionStatus = "";

  final List<String> _gradeOptions = [
    'V0',
    'V1',
    'V2',
    'V3',
    'V4',
    'V5',
    'V6',
    'V7',
    'V8',
    'V9',
    'V10',
    'V11',
    'V12',
    'V13',
    'V14',
    'V15',
    'V16',
    '6A',
    '6A+',
    '6B',
    '6B+',
    '6C',
    '6C+',
    '7A',
    '7A+',
    '7B',
    '7B+',
    '7C',
    '7C+',
    '8A',
    '8A+',
    '8B',
    '8B+',
    '8C',
    '8C+',
    '9A'
  ];

  final List<String> _vScaleGrades = [
    'V0',
    'V1',
    'V2',
    'V3',
    'V4',
    'V5',
    'V6',
    'V7',
    'V8',
    'V9',
    'V10',
    'V11',
    'V12',
    'V13',
    'V14',
    'V15',
    'V16'
  ];

  final List<String> _fontScaleGrades = [
    '6A',
    '6A+',
    '6B',
    '6B+',
    '6C',
    '6C+',
    '7A',
    '7A+',
    '7B',
    '7B+',
    '7C',
    '7C+',
    '8A',
    '8A+',
    '8B',
    '8B+',
    '8C',
    '8C+',
    '9A'
  ];

  List<DropdownMenuItem<String>> _buildGradeDropdownItems() {
    final List<DropdownMenuItem<String>> items = [];

    // Hueco / V-Scale Header
    items.add(
      DropdownMenuItem(
        enabled: false, // Make it unselectable
        child: Text(
          "Hueco Scale (USA)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepPurpleAccent[100],
          ),
        ),
      ),
    );

    // V-Scale items
    items.addAll(_vScaleGrades.map(
      (grade) => DropdownMenuItem<String>(
        value: grade,
        child: Text(grade, style: const TextStyle(color: Colors.white)),
      ),
    ));

    // Divider
    items.add(const DropdownMenuItem(
      enabled: false,
      child: Divider(color: Colors.white30),
    ));

    // Font Scale Header
    items.add(
      DropdownMenuItem(
        enabled: false,
        child: Text(
          "Fontainebleau Scale (Font)",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepPurpleAccent[100],
          ),
        ),
      ),
    );

    // Font Scale items
    items.addAll(_fontScaleGrades.map(
      (grade) => DropdownMenuItem<String>(
        value: grade,
        child: Text(grade, style: const TextStyle(color: Colors.white)),
      ),
    ));

    return items;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _landmarkDescriptionController.dispose();
    _boulderDescriptionController.dispose();
    _manualLatController.dispose();
    _manualLngController.dispose();
    _pastedCoordsController.dispose();
    super.dispose();
  }

  Future<void> _handleImageTap() async {
    if (_isLoading) return;
    if (_selectedImageXFile == null) {
      await _pickImage();
    } else {
      await _navigateToDrawingPage();
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? imageXFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Compress slightly
        maxWidth: 1200, // Resize for performance
        maxHeight: 1200,
      );

      if (imageXFile != null) {
        if (mounted) {
          setState(() {
            _selectedImageXFile = imageXFile;
            _drawingResultData =
                null; // Clear previous drawing data for new image
          });
        }
      }
    } catch (e) {
      print("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error picking image: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _navigateToDrawingPage() async {
    if (_selectedImageXFile == null || !mounted) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DrawingPage(imageXFile: _selectedImageXFile!),
      ),
    );

    if (result is Map<String, dynamic> && mounted) {
      final bool hasDrawings = result['has_drawings'] as bool? ?? false;
      final Uint8List newBytes = result['updatedImageBytes'] as Uint8List;

      if (kIsWeb) {
        setState(() {
          _selectedImageBytes = newBytes;
          _drawingResultData = result;
        });
      } else {
        final String newPath = result['updatedImagePath'] as String;
        setState(() {
          _selectedImageXFile = XFile(newPath);
          _drawingResultData = result;
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasDrawings ? 'Lines updated!' : 'No lines drawn.'),
          backgroundColor: hasDrawings ? Colors.blueAccent : Colors.orange,
        ),
      );
    }
  }

  Future<void> _handleGpsSelection() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true; // Show loading indicator while fetching
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permission not granted. Please enable it in your device settings.');
      }

      final Position pos = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high)
          .timeout(const Duration(seconds: 10)); // 10 second timeout

      // SUCCESS!
      if (mounted) {
        setState(() {
          _isLoading = false;
          _locationInputType = LocationInputType.gps; // Confirm GPS selection
          // Optionally pre-fill the manual fields for user reference
          _manualLatController.text = pos.latitude.toStringAsFixed(6);
          _manualLngController.text = pos.longitude.toStringAsFixed(6);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GPS Location Acquired!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // FAILURE
      if (mounted) {
        setState(() {
          _isLoading = false;
          _locationInputType =
              LocationInputType.manual; // <<-- REVERT to manual
        });
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey.shade800,
            title: const Text('Location Error',
                style: TextStyle(color: Colors.white)),
            content: Text(
              'Could not get your current location. Please check your GPS signal and permissions, or enter the coordinates manually.\n\nError: ${e.toString().replaceFirst("Exception: ", "")}',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _parseAndSetPastedCoordinates(String pastedText) {
    if (pastedText.trim().isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Clipboard is empty.'),
              backgroundColor: Colors.orange),
        );
      return;
    }
    final RegExp coordRegex = RegExp(
        r"[\[\(\s]*([+-]?\d+\.?\d+)\s*[,;\s]+\s*([+-]?\d+\.?\d*)[\]\)\s]*");
    Iterable<RegExpMatch> matches = coordRegex.allMatches(pastedText.trim());

    if (matches.isNotEmpty) {
      final match = matches.first;
      final String firstNumStr = match.group(1)!;
      final String secondNumStr = match.group(2)!;

      double? val1 = double.tryParse(firstNumStr);
      double? val2 = double.tryParse(secondNumStr);

      if (val1 != null && val2 != null) {
        double lat, lng;
        if (val1.abs() <= 90 && val2.abs() <= 180) {
          lat = val1;
          lng = val2;
        } else if (val2.abs() <= 90 && val1.abs() <= 180) {
          lat = val2;
          lng = val1;
        } else {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Pasted values out of Lat/Lng range.'),
                  backgroundColor: Colors.orange),
            );
          return;
        }
        _manualLatController.text = lat.toStringAsFixed(6);
        _manualLngController.text = lng.toStringAsFixed(6);
        _pastedCoordsController.clear();
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Coords parsed: Lat: $lat, Lng: $lng'),
                backgroundColor: Colors.green),
          );
        if (mounted)
          setState(() {
            _locationInputType = LocationInputType.manual;
          });
        return;
      }
    }
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Pasted text not recognized as "lat, lng".'),
            backgroundColor: Colors.orange),
      );
  }

  Future<void> _publishBoulder() async {
    if (!mounted) return;
    setState(() {
      _submissionStatus = "";
      _isLoading = true;
    });

    if (!_formKey.currentState!.validate()) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (_selectedGrade == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select a grade.'),
              backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null)
        throw Exception('User not authenticated. Please sign in.');

      double boulderLat;
      double boulderLng;

      if (_locationInputType == LocationInputType.gps) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            throw Exception(
                'Location permission not granted for GPS. Please enable in settings.');
          }
        }
        final Position pos = await Geolocator.getCurrentPosition(
                desiredAccuracy: LocationAccuracy.high)
            .timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException("Getting current location timed out.");
        });
        boulderLat = pos.latitude;
        boulderLng = pos.longitude;
      } else {
        boulderLat = double.parse(_manualLatController.text.trim());
        boulderLng = double.parse(_manualLngController.text.trim());
        if (boulderLat.abs() > 90 || boulderLng.abs() > 180) {
          throw Exception('Manual coordinates out of valid range.');
        }
      }

      final boulderPayload = {
        'name': _nameController.text.trim(),
        'area_id': widget.areaId, // <-- THE KEY CHANGE
        'uploaded_by': userId,
        'latitude': boulderLat,
        'longitude': boulderLng,
        'grade': _selectedGrade!,
        'description': _boulderDescriptionController.text.trim(),
      };

      print('Calling add-boulder with data: $boulderPayload');
      final FunctionResponse boulderResponse =
          await _supabase.functions.invoke('add-boulder', body: boulderPayload);

      if (boulderResponse.status != 201) {
        String errorMsg = boulderResponse.data?['error']?.toString() ??
            'Function returned status ${boulderResponse.status}';
        throw Exception('Failed to add boulder: $errorMsg');
      }

      final newBoulder = boulderResponse.data;
      if (newBoulder == null || newBoulder['id'] == null) {
        throw Exception(
            'Add-boulder function did not return valid new boulder data with ID.');
      }
      final String newBoulderId = newBoulder['id'];
      print('Successfully added boulder with ID: $newBoulderId');

      final String landmarkText = _landmarkDescriptionController.text.trim();
      if (landmarkText.isNotEmpty) {
        print('Adding landmark for boulder ID: $newBoulderId');
        final landmarkPayload = {
          'boulder_id': newBoulderId,
          'description': landmarkText
        };
        _supabase.functions
            .invoke('add-landmark', body: landmarkPayload)
            .then((landmarkResponse) {
          if (landmarkResponse.status != 201) {
            print(
                'Warning: Failed to add landmark: ${landmarkResponse.data?['error'] ?? 'Function error'}');
          } else {
            print('Successfully added landmark.');
          }
        }).catchError((e) {
          print('Error calling add-landmark function: $e');
        });
      }

      Uint8List imageBytesToUpload;
      String fileExtension;
      String? mimeType;
      if (kIsWeb) {
        if (_selectedImageBytes != null) {
          // Web: Drawn image bytes are available
          imageBytesToUpload = _selectedImageBytes!;
          // Try to get original extension/mime, default to png
          final selectedImageXFile =
              _selectedImageXFile; // Create local variable
          fileExtension =
              selectedImageXFile?.name.split('.').last.toLowerCase() ?? 'png';
          mimeType = selectedImageXFile?.mimeType;
          // If drawing always results in PNG, or if _selectedImageBytes already implies a type (e.g. from DrawingPage)
          // you might want to force PNG for consistency if _selectedImageBytes is always PNG.
          // For now, we assume DrawingPage returns bytes that could match original type or be PNG.
          // If DrawingPage always outputs PNG:
          // fileExtension = 'png';
          // mimeType = 'image/png';
        } else if (_selectedImageXFile != null) {
          // Web: No drawn bytes (_selectedImageBytes is null), but original XFile exists.
          // This means user picked an image but perhaps didn't go to drawing page or no drawing was made/returned.
          // Upload the original image.
          print(
              "Web: Uploading original image as no drawn image bytes are available.");
          final selectedImageXFile =
              _selectedImageXFile!; // Create local non-null variable
          imageBytesToUpload = await selectedImageXFile.readAsBytes();
          fileExtension = selectedImageXFile.name.split('.').last.toLowerCase();
          mimeType = selectedImageXFile.mimeType;
        } else {
          // This case should ideally not be reached if the outer 'if' condition is true for kIsWeb
          throw Exception(
              "No image data available for web upload despite selection.");
        }
      } else {
        // Native platforms: _selectedImageXFile is not null (guaranteed by outer if condition)
        // and should point to the (potentially drawn) image file.
        final selectedImageXFile =
            _selectedImageXFile!; // Create local non-null variable
        imageBytesToUpload = await selectedImageXFile.readAsBytes();
        fileExtension = selectedImageXFile.name.split('.').last.toLowerCase();
        mimeType = selectedImageXFile.mimeType;
      }

      final String uniqueFileName =
          '${newBoulderId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
      final String storagePath =
          'public/boulders/$newBoulderId/$uniqueFileName';

      print(
          'Uploading to Supabase Storage bucket "boulder.radar.public.data" at path: $storagePath');
      await _supabase.storage.from('boulder.radar.public.data').uploadBinary(
            storagePath,
            imageBytesToUpload, // Use the determined bytes (original or drawn)
            fileOptions: FileOptions(
                contentType: mimeType ??
                    'image/$fileExtension', // Use determined mimeType
                upsert: false),
          );
      final String publicImageUrl = _supabase.storage
          .from('boulder.radar.public.data')
          .getPublicUrl(storagePath);
      print('Image uploaded. Public URL: $publicImageUrl');

      final imagePayload = {
        'boulder_id': newBoulderId,
        'image_path': publicImageUrl,
        'has_drawings': _drawingResultData?['has_drawings'] ?? false,
        'drawing_data': _drawingResultData?['drawing_data'],
      };
      print('Calling add-image function with payload: $imagePayload');
      _supabase.functions
          .invoke('add-image', body: imagePayload)
          .then((imageDbResponse) {
        if (imageDbResponse.status != 201) {
          print(
              'Warning: Failed to add image record to DB: ${imageDbResponse.data?['error'] ?? 'Function error'}');
        } else {
          print('Successfully added image record to DB.');
        }
      }).catchError((e) {
        print('Error calling add-image function: $e');
      });

      if (mounted) {
        setState(() {
          _submissionStatus =
              '${_nameController.text.trim()} published successfully!';
          _isLoading = false;
          _formKey.currentState?.reset();
          _nameController.clear();
          _landmarkDescriptionController.clear();
          _boulderDescriptionController.clear();
          _manualLatController.clear();
          _manualLngController.clear();
          _pastedCoordsController.clear();
          _selectedGrade = null;
          _selectedImageXFile = null;
          _drawingResultData = null;
          _locationInputType = LocationInputType.gps;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_submissionStatus),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3)),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) Navigator.of(context).pop(true);
      }
    } catch (e) {
      print('Error publishing boulder: $e');
      if (mounted) {
        setState(() {
          _submissionStatus =
              'Error: ${e.toString().replaceFirst("Exception: ", "")}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade900,
      appBar: AppBar(
        // --- THIS IS THE FIX ---
        title: Text(
            'Add Boulder in ${widget.areaName}'), // <-- Use areaName instead of zoneName
        centerTitle: true,
        backgroundColor: Colors.grey.shade800,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_submissionStatus.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _submissionStatus,
                    style: TextStyle(
                      color: _submissionStatus.startsWith("Error")
                          ? Colors.redAccent[700]
                          : Colors.green[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              // --- Image Section ---
              // --- Image Section ---
              GestureDetector(
                onTap: _isLoading
                    ? null
                    : _handleImageTap, // Calls _pickImage or _navigateToDrawingPage
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.grey.shade700, width: 1.5),
                    ),
                    // Check if there's any image data to display
                    child: (_selectedImageXFile != null ||
                            (kIsWeb && _selectedImageBytes != null))
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10.5),
                                // Use the new helper method here
                                child: _buildImageDisplayWidget(),
                              ),
                              // "Edit Lines" overlay if image is selected
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined,
                                          color: Colors.white, size: 18),
                                      SizedBox(width: 6),
                                      Text("Draw/Edit Lines",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13)),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          )
                        : Center(
                            // Placeholder when no image is selected
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 60, color: Colors.white60),
                                const SizedBox(height: 12),
                                const Text('Tap to add image',
                                    style: TextStyle(
                                        color: Colors.white60, fontSize: 16)),
                                const SizedBox(height: 4),
                                const Text('(Optional)',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 12)),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
// UI Cue text below the image
// Check if an image is displayed (either via XFile or bytes for web)
              if (_selectedImageXFile != null ||
                  (kIsWeb && _selectedImageBytes != null))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                  child: Text(
                    _drawingResultData == null
                        ? 'Tap image above to draw lines.'
                        // Ensure has_drawings is accessed safely
                        : (_drawingResultData!['has_drawings'] as bool? ?? false
                            ? 'Lines added/updated! Tap image to re-edit.'
                            : 'Image ready. Tap image to draw lines.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.blueGrey[200],
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),
                )
              else
                const SizedBox(
                    height:
                        12), // Maintain some space if no image & no text cue

              if (_selectedImageXFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                  child: Text(
                    _drawingResultData == null
                        ? 'Tap image above to draw lines.'
                        : (_drawingResultData!['has_drawings'] == true
                            ? 'Lines added/updated! Tap image to re-edit.'
                            : 'Image ready. Tap image to draw lines.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.blueGrey[200],
                        fontSize: 13,
                        fontStyle: FontStyle.italic),
                  ),
                )
              else if (kIsWeb && _selectedImageBytes != null)
                Image.memory(
                  _selectedImageBytes!,
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                )
              else if (_selectedImageXFile != null)
                Image.file(
                  File(_selectedImageXFile!.path),
                  width: 200,
                  height: 200,
                  fit: BoxFit.cover,
                )
              else
                const SizedBox(
                    height:
                        12), // Maintain some space if no image & no text cue

              const SizedBox(height: 12), // Adjust spacing

              _buildSectionTitle("Boulder Details"),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration:
                    _inputDecoration('Boulder Name*', isOptional: false),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Boulder name is required'
                    : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedGrade,
                items:
                    _buildGradeDropdownItems(), // <-- USE THE NEW METHOD HERE
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedGrade = newValue);
                  }
                },
                decoration: _inputDecoration('Select Grade*', isOptional: false)
                    .copyWith(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                ),
                dropdownColor:
                    Colors.grey.shade800, // A bit darker for better contrast
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                validator: (value) =>
                    value == null ? 'Please select a grade' : null,
              ),
              const SizedBox(height: 24),

              _buildSectionTitle("Location*"),
              SegmentedButton<LocationInputType>(
                style: SegmentedButton.styleFrom(
                  backgroundColor: Colors.grey.shade800,
                  foregroundColor: Colors.white70,
                  selectedForegroundColor: Colors.white,
                  selectedBackgroundColor:
                      Colors.deepPurpleAccent.withOpacity(0.8),
                  side: BorderSide(color: Colors.grey.shade700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                segments: const <ButtonSegment<LocationInputType>>[
                  ButtonSegment<LocationInputType>(
                      value: LocationInputType.gps,
                      label: Text('Current GPS'),
                      icon: Icon(Icons.my_location)),
                  ButtonSegment<LocationInputType>(
                      value: LocationInputType.manual,
                      label: Text('Enter Manually'),
                      icon: Icon(Icons.edit_location_alt_outlined)),
                ],
                selected: <LocationInputType>{_locationInputType},
                onSelectionChanged: (Set<LocationInputType> newSelection) {
                  final selection = newSelection.first;
                  if (selection == LocationInputType.gps) {
                    _handleGpsSelection(); // <-- Call our new method
                  } else {
                    setState(() {
                      _locationInputType = LocationInputType.manual;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              if (_locationInputType == LocationInputType.manual) ...[
                TextFormField(
                  controller: _pastedCoordsController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Paste Coordinates String',
                          isOptional: true)
                      .copyWith(
                          hintText: 'e.g., (37.8, -119.3) or 37.8, -119.3',
                          suffixIcon: IconButton(
                            tooltip: 'Paste from clipboard and parse',
                            icon: const Icon(Icons.content_paste_go_outlined,
                                color: Colors.white70),
                            onPressed: () async {
                              final clipboardData =
                                  await Clipboard.getData(Clipboard.kTextPlain);
                              if (clipboardData != null &&
                                  clipboardData.text != null &&
                                  clipboardData.text!.isNotEmpty) {
                                _pastedCoordsController.text =
                                    clipboardData.text!;
                                _parseAndSetPastedCoordinates(
                                    clipboardData.text!);
                              } else {
                                if (mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Clipboard is empty.'),
                                        backgroundColor: Colors.orange),
                                  );
                              }
                            },
                          )),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _manualLatController,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            _inputDecoration('Latitude*', isOptional: false),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        validator: (value) {
                          if (_locationInputType == LocationInputType.manual) {
                            if (value == null || value.trim().isEmpty)
                              return 'Enter latitude';
                            final lat = double.tryParse(value.trim());
                            if (lat == null || lat < -90 || lat > 90)
                              return 'Invalid (-90 to 90)';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _manualLngController,
                        style: const TextStyle(color: Colors.white),
                        decoration:
                            _inputDecoration('Longitude*', isOptional: false),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        validator: (value) {
                          if (_locationInputType == LocationInputType.manual) {
                            if (value == null || value.trim().isEmpty)
                              return 'Enter longitude';
                            final lng = double.tryParse(value.trim());
                            if (lng == null || lng < -180 || lng > 180)
                              return 'Invalid (-180 to 180)';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],

              _buildSectionTitle("Additional Info"),
              TextFormField(
                controller: _landmarkDescriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                    'Specific Landmark / Approach Directions',
                    isOptional: true),
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _boulderDescriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                    'General Boulder Description (e.g., type of holds, style)',
                    isOptional: true),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 32),

              ElevatedButton.icon(
                icon: _isLoading
                    ? Container(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.publish_outlined, color: Colors.white),
                label: Text(_isLoading ? 'Publishing...' : 'Publish Boulder',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _isLoading ? null : _publishBoulder,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildImageDisplayWidget() {
    // Using a key that changes when the image content or source changes.
    // Suffix helps differentiate if multiple aspects change.
    String imageKeySuffix = _drawingResultData?['has_drawings']?.toString() ??
        _selectedImageXFile?.name ?? // Use name as path can be long for web
        _selectedImageBytes?.hashCode.toString() ??
        DateTime.now().millisecondsSinceEpoch.toString();

    if (kIsWeb) {
      if (_selectedImageBytes != null) {
        // WEB: Drawn image bytes are available, use Image.memory
        return Image.memory(
          _selectedImageBytes!,
          fit: BoxFit.contain,
          key: ValueKey(
              'web_drawn_${_selectedImageBytes!.hashCode}_$imageKeySuffix'),
          errorBuilder: (context, error, stackTrace) => Center(
              child: Text("Error loading drawn web image",
                  style: TextStyle(color: Colors.red[400]!))),
        );
      } else if (_selectedImageXFile != null) {
        // WEB: No drawn image bytes yet (initial pick), use Image.network with original path
        return Image.network(
          _selectedImageXFile!.path,
          fit: BoxFit.contain,
          key: ValueKey(
              'web_original_${_selectedImageXFile!.path}_$imageKeySuffix'),
          errorBuilder: (context, error, stackTrace) => Center(
              child: Text("Error loading web image: ${error.toString()}",
                  style: TextStyle(color: Colors.red[400]!))),
        );
      }
    } else {
      // Native platforms
      if (_selectedImageXFile != null) {
        // NATIVE: _selectedImageXFile.path should point to the drawn image (temp file) or original.
        // Image.file is used here.
        return Image.file(
          File(_selectedImageXFile!.path),
          fit: BoxFit.contain,
          key: ValueKey('native_${_selectedImageXFile!.path}_$imageKeySuffix'),
          errorBuilder: (context, error, stackTrace) => Center(
              child: Text("Error loading file image: ${error.toString()}",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red[400]!))),
        );
      }
    }
    // This should ideally not be reached if the parent logic correctly calls this method
    // only when an image is supposed to be visible.
    return const Center(
        child: Text("No image to display.",
            style: TextStyle(color: Colors.white54)));
  }

  InputDecoration _inputDecoration(String label, {required bool isOptional}) {
    String displayLabel = label;
    if (isOptional && !label.toLowerCase().contains("(optional)")) {
      displayLabel = label.replaceFirst(RegExp(r'\*$'), "") +
          ' (Optional)'; // Remove trailing * if present
    }

    return InputDecoration(
      labelText: displayLabel,
      labelStyle: const TextStyle(color: Colors.white70),
      hintText: isOptional && !label.toLowerCase().contains("paste")
          ? 'Optional details'
          : null,
      hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontSize: 14,
          fontStyle: FontStyle.italic),
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: Colors.grey.shade800,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade700, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.deepPurpleAccent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      errorStyle: const TextStyle(
          color: Colors.redAccent, fontWeight: FontWeight.w500, fontSize: 13),
    );
  }
}
