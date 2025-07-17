import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:boulder_radar/src/full_screen_map_picker_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:image_picker/image_picker.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart'
    hide LatLng, Size, ImageSource;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:boulder_radar/services/upload_service.dart'; // Adjust path if needed

import 'drawing_page.dart';
import '../widgets/interactive_map_picker.dart';
import 'dart:ui' as ui;

enum LocationInputType { map, manual }

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
  static const String _mapboxAccessToken = 'YOUR_MAPBOX_PUBLIC_TOKEN_HERE';
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _landmarkDescriptionController = TextEditingController();
  final _boulderDescriptionController = TextEditingController();
  final _manualLatController = TextEditingController();
  final _manualLngController = TextEditingController();
  final _pastedCoordsController = TextEditingController();
  // Point? _selectedMapPoint; // Use Point instead of ScreenCoordinate

  XFile? _selectedImageXFile;
  Uint8List? _selectedImageBytes;
  Map<String, dynamic>? _drawingResultData;
  String? _selectedGrade;
  // ScreenCoordinate? _selectedMapCoordinates;
  Point? _selectedMapPoint;

  LocationInputType _locationInputType = LocationInputType.map;
  bool _isLoading = false;
  String _submissionStatus = "";

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

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameController.clear();
    _landmarkDescriptionController.clear();
    _boulderDescriptionController.clear();
    _manualLatController.clear();
    _manualLngController.clear();
    _pastedCoordsController.clear();
    setState(() {
      _submissionStatus = '';
      _isLoading = false;
      _selectedGrade = null;
      _selectedImageXFile = null;
      _selectedImageBytes = null;
      _drawingResultData = null;
      _selectedMapPoint = null;
      _locationInputType = LocationInputType.map;
    });
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

  List<DropdownMenuItem<String>> _buildGradeDropdownItems() {
    final List<DropdownMenuItem<String>> items = [];
    items.add(DropdownMenuItem(
      enabled: false,
      child: Text(
        "Hueco Scale (USA)",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.deepPurpleAccent[100],
        ),
      ),
    ));
    items.addAll(_vScaleGrades.map(
      (grade) => DropdownMenuItem<String>(
        value: grade,
        child: Text(grade, style: const TextStyle(color: Colors.white)),
      ),
    ));
    items.add(const DropdownMenuItem(
        enabled: false, child: Divider(color: Colors.white30)));
    items.add(DropdownMenuItem(
      enabled: false,
      child: Text(
        "Fontainebleau Scale (Font)",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.deepPurpleAccent[100],
        ),
      ),
    ));
    items.addAll(_fontScaleGrades.map(
      (grade) => DropdownMenuItem<String>(
        value: grade,
        child: Text(grade, style: const TextStyle(color: Colors.white)),
      ),
    ));
    return items;
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
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (imageXFile != null && mounted) {
        setState(() {
          _selectedImageXFile = imageXFile;
          _selectedImageBytes = null;
          _drawingResultData = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
      final hasDrawings = result['has_drawings'] as bool? ?? false;
      setState(() {
        _drawingResultData = result;
        if (kIsWeb) {
          _selectedImageBytes = result['updatedImageBytes'] as Uint8List;
        } else {
          _selectedImageXFile = XFile(result['updatedImagePath'] as String);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hasDrawings ? 'Lines updated!' : 'No lines drawn.',
          ),
          backgroundColor: hasDrawings ? Colors.blueAccent : Colors.orange,
        ),
      );
    }
  }

  void _parseAndSetPastedCoordinates(String pastedText) {
    if (pastedText.trim().isEmpty) return;
    final RegExp coordRegex = RegExp(
      r"[\[\(\s]*([+-]?\d+\.?\d+)\s*[,;\s]+\s*([+-]?\d+\.?\d*)[\]\)\s]*",
    );
    final match = coordRegex.firstMatch(pastedText.trim());

    if (match != null) {
      double? val1 = double.tryParse(match.group(1)!);
      double? val2 = double.tryParse(match.group(2)!);

      if (val1 != null && val2 != null) {
        double lat, lng;
        if (val1.abs() <= 90 && val2.abs() <= 180) {
          lat = val1;
          lng = val2;
        } else if (val2.abs() <= 90 && val1.abs() <= 180) {
          lat = val2;
          lng = val1;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pasted values out of Lat/Lng range.'),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        _manualLatController.text = lat.toStringAsFixed(6);
        _manualLngController.text = lng.toStringAsFixed(6);
        _pastedCoordsController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Coords parsed: Lat: $lat, Lng: $lng'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pasted text not recognized as "lat, lng".'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // REPLACE the entire _publishBoulder function in add_boulder_page.dart with this one.

// Future<void> _publishBoulder() async {
//   if (!mounted) return;
//   setState(() {
//     _submissionStatus = "";
//     _isLoading = true;
//   });

//   if (!_formKey.currentState!.validate()) {
//     if (mounted) setState(() => _isLoading = false);
//     return;
//   }
//   if (_selectedGrade == null) {
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please select a grade.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       setState(() => _isLoading = false);
//     }
//     return;
//   }

//   try {
//     final userId = _supabase.auth.currentUser?.id;
//     if (userId == null) throw Exception('User not authenticated.');

//     double? boulderLat;
//     double? boulderLng;

//     if (_locationInputType == LocationInputType.map) {
//       if (_selectedMapPoint == null) {
//         setState(() => _submissionStatus = 'No location pinned, using current GPS...');
//         final pos = await geo.Geolocator.getCurrentPosition(
//           desiredAccuracy: geo.LocationAccuracy.high,
//         );
//         boulderLat = pos.latitude;
//         boulderLng = pos.longitude;
//       } else {
//         // Correctly access coordinates from the Point object
//         boulderLat = _selectedMapPoint!.coordinates.lat as double?;
//         boulderLng = _selectedMapPoint!.coordinates.lng as double?;
//       }
//     } else {
//       boulderLat = double.parse(_manualLatController.text.trim());
//       boulderLng = double.parse(_manualLngController.text.trim());
//       if (boulderLat.abs() > 90 || boulderLng.abs() > 180) {
//         throw Exception('Manual coordinates out of valid range.');
//       }
//     }

//     // 1. Create the Boulder Record
//     final boulderPayload = {
//       'name': _nameController.text.trim(),
//       'area_id': widget.areaId,
//       'uploaded_by': userId,
//       'latitude': boulderLat,
//       'longitude': boulderLng,
//       'grade': _selectedGrade!,
//       'description': _boulderDescriptionController.text.trim(),
//     };

//     final boulderResponse = await _supabase.functions.invoke(
//       'add-boulder',
//       body: boulderPayload,
//     );
//     if (boulderResponse.status != 201) {
//       throw Exception('Failed to add boulder: ${boulderResponse.data?['error']?.toString() ?? 'Function error'}');
//     }
//     final newBoulderId = boulderResponse.data['id'];
//     if (newBoulderId == null) {
//       throw Exception('Function did not return new boulder ID.');
//     }

//     // 2. Add Landmark (if provided)
//     final String landmarkText = _landmarkDescriptionController.text.trim();
//     if (landmarkText.isNotEmpty) {
//       final landmarkPayload = {
//         'boulder_id': newBoulderId,
//         'description': landmarkText
//       };
//       // No need to `await` this, can run in the background
//       _supabase.functions.invoke('add-landmark', body: landmarkPayload);
//     }

//     // 3. --- THIS IS THE MISSING IMAGE LOGIC ---
//     if (_selectedImageXFile != null || (kIsWeb && _selectedImageBytes != null)) {
//       Uint8List imageBytesToUpload;
//       String fileExtension;
//       String? mimeType;

//       if (kIsWeb) {
//         if (_selectedImageBytes != null) {
//           // Web: Use the drawn image bytes
//           imageBytesToUpload = _selectedImageBytes!;
//           fileExtension = _selectedImageXFile?.name.split('.').last.toLowerCase() ?? 'png';
//           mimeType = _selectedImageXFile?.mimeType ?? 'image/png';
//         } else {
//           // Web: No drawing, use original image bytes
//           imageBytesToUpload = await _selectedImageXFile!.readAsBytes();
//           fileExtension = _selectedImageXFile!.name.split('.').last.toLowerCase();
//           mimeType = _selectedImageXFile!.mimeType;
//         }
//       } else {
//         // Native: Use the XFile path (which is updated after drawing)
//         imageBytesToUpload = await _selectedImageXFile!.readAsBytes();
//         fileExtension = _selectedImageXFile!.name.split('.').last.toLowerCase();
//         mimeType = _selectedImageXFile!.mimeType;
//       }

//       final String uniqueFileName = '${newBoulderId}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
//       // Make sure the bucket name is correct!
//       final String storagePath = 'public/boulders/$newBoulderId/$uniqueFileName';

//       // 3a. Upload image to Supabase Storage
//       await _supabase.storage.from('boulder.radar.public.data').uploadBinary(
//             storagePath,
//             imageBytesToUpload,
//             fileOptions: FileOptions(
//                 contentType: mimeType ?? 'image/$fileExtension', upsert: false),
//           );

//       // 3b. Get the public URL
//       final String publicImageUrl = _supabase.storage
//           .from('boulder.radar.public.data')
//           .getPublicUrl(storagePath);

//       // 3c. Save image metadata to your database via another edge function
//       final imagePayload = {
//         'boulder_id': newBoulderId,
//         'image_path': publicImageUrl,
//         'has_drawings': _drawingResultData?['has_drawings'] ?? false,
//         'drawing_data': _drawingResultData?['drawing_data'],
//       };

//       // No need to `await` this, can run in the background
//       _supabase.functions.invoke('add-image', body: imagePayload);
//     }
//     // --- END OF MISSING LOGIC ---

//     if (mounted) {
//       setState(() {
//         _submissionStatus =
//             '${_nameController.text.trim()} published successfully!';
//         _isLoading = false;
//         _formKey.currentState?.reset();
//         _nameController.clear();
//         _landmarkDescriptionController.clear();
//         _boulderDescriptionController.clear();
//         _manualLatController.clear();
//         _manualLngController.clear();
//         _pastedCoordsController.clear();
//         _selectedGrade = null;
//         _selectedImageXFile = null;
//         _selectedImageBytes = null;
//         _drawingResultData = null;
//         _selectedMapPoint = null;
//         _locationInputType = LocationInputType.map;
//       });
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(_submissionStatus),
//           backgroundColor: Colors.green,
//           duration: const Duration(seconds: 3),
//         ),
//       );
//       await Future.delayed(const Duration(milliseconds: 500));
//       if (mounted) Navigator.of(context).pop(true);
//     }
//   } catch (e) {
//     if (mounted) {
//       setState(() {
//         _submissionStatus =
//             'Error: ${e.toString().replaceFirst("Exception: ", "")}';
//         _isLoading = false;
//       });
//     }
//   }
// }

// REPLACE the entire _publishBoulder function with this one.
  Future<void> _publishBoulder() async {
    if (!mounted) return;
    // 1. Validate the form and grade selection
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGrade == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please select a grade.'),
              backgroundColor: Colors.red),
        );
      }
      return;
    }

    setState(() {
      _submissionStatus = "";
      _isLoading = true;
    });

    try {
      double? boulderLat;
      double? boulderLng;

      // 2. Determine the location coordinates
      if (_locationInputType == LocationInputType.map) {
        if (_selectedMapPoint == null) {
          // Fallback to current location if no point is pinned
          final pos = await geo.Geolocator.getCurrentPosition(
              desiredAccuracy: geo.LocationAccuracy.high);
          boulderLat = pos.latitude;
          boulderLng = pos.longitude;
        } else {
          boulderLat = _selectedMapPoint!.coordinates.lat as double?;
          boulderLng = _selectedMapPoint!.coordinates.lng as double?;
        }
      } else {
        boulderLat = double.parse(_manualLatController.text.trim());
        boulderLng = double.parse(_manualLngController.text.trim());
      }

      // 3. Prepare the image bytes for storage
      Uint8List? imageBytesForUpload;
      String? imageFileExt;
      if (_selectedImageXFile != null) {
        if (kIsWeb && _selectedImageBytes != null) {
          imageBytesForUpload = _selectedImageBytes;
        } else {
          imageBytesForUpload = await _selectedImageXFile!.readAsBytes();
        }
        imageFileExt = _selectedImageXFile!.name.split('.').last.toLowerCase();
      }

      // 4. Create the data payload object for our queue
      // FIX for latitude and longitude nullability
      final uploadData = PendingUpload(
        boulderName: _nameController.text.trim(),
        areaId: widget.areaId,
        grade: _selectedGrade!,
        latitude: boulderLat!, // Add '!'
        longitude: boulderLng!, // Add '!'
        boulderDescription: _boulderDescriptionController.text.trim(),
        landmarkDescription: _landmarkDescriptionController.text.trim(),
        imageBytes: imageBytesForUpload,
        imageFileExtension: imageFileExt,
        drawingData: _drawingResultData,
      );

      // 5. Check connectivity and decide whether to upload or queue
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        // Use '==' instead of '.contains()'
        // --- OFFLINE LOGIC ---
        await UploadService.instance.queueUpload(uploadData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offline. Upload added to queue to sync later.'),
              backgroundColor: Colors.blueAccent,
            ),
          );
        }
      } else {
        // --- ONLINE LOGIC ---
        final success = await UploadService.instance.performUpload(uploadData);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('${uploadData.boulderName} published successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // --- On success (either queued or uploaded), reset and leave ---
      if (mounted) {
        _resetForm(); // Use a helper to clean up the form
        await Future.delayed(const Duration(milliseconds: 300));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
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
        title: Text('Add Boulder in ${widget.areaName}'),
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
              if (_submissionStatus.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _submissionStatus,
                    style: TextStyle(
                      color: _submissionStatus.startsWith("Error")
                          ? Colors.redAccent[700]
                          : Colors.green[600],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              GestureDetector(
                onTap: _isLoading ? null : _handleImageTap,
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.grey.shade700, width: 1.5),
                    ),
                    child: (_selectedImageXFile != null ||
                            (kIsWeb && _selectedImageBytes != null))
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10.5),
                                child: _buildImageDisplayWidget(),
                              ),
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit_outlined,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        "Draw/Edit Lines",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_photo_alternate_outlined,
                                  size: 60,
                                  color: Colors.white60,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Tap to add image',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '(Optional)',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              if (_selectedImageXFile != null ||
                  (kIsWeb && _selectedImageBytes != null))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                  child: Text(
                    (_drawingResultData?['has_drawings'] as bool? ?? false)
                        ? 'Lines updated! Tap image to re-edit.'
                        : 'Tap image to draw lines.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blueGrey[200],
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              else
                const SizedBox(height: 12),
              _buildSectionTitle("Boulder Details"),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration:
                    _inputDecoration('Boulder Name*', isOptional: false),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Boulder name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGrade,
                items: _buildGradeDropdownItems(),
                onChanged: (String? v) {
                  if (v != null) setState(() => _selectedGrade = v);
                },
                decoration: _inputDecoration('Select Grade*', isOptional: false)
                    .copyWith(
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                ),
                dropdownColor: Colors.grey.shade800,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Colors.white70,
                ),
                style: const TextStyle(color: Colors.white, fontSize: 16),
                validator: (v) => v == null ? 'Please select a grade' : null,
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                segments: const <ButtonSegment<LocationInputType>>[
                  ButtonSegment<LocationInputType>(
                    value: LocationInputType.map,
                    label: Text('Use Map'),
                    icon: Icon(Icons.map_outlined),
                  ),
                  ButtonSegment<LocationInputType>(
                    value: LocationInputType.manual,
                    label: Text('Enter Manually'),
                    icon: Icon(Icons.edit_location_alt_outlined),
                  ),
                ],
                selected: <LocationInputType>{_locationInputType},
                onSelectionChanged: (Set<LocationInputType> newSelection) =>
                    setState(() => _locationInputType = newSelection.first),
              ),
              const SizedBox(height: 16),
              // In add_boulder_page.dart, inside the build method's Column:

              if (_locationInputType == LocationInputType.map)
                _MapPickerPreview(
                  selectedPoint: _selectedMapPoint,
                  onTap: () async {
                    final result = await Navigator.of(context).push<Point?>(
                      MaterialPageRoute(
                        builder: (_) => FullScreenMapPickerPage(
                          initialPoint: _selectedMapPoint,
                        ),
                      ),
                    );

                    // When the full-screen picker returns a result, update the form.
                    if (result != null && mounted) {
                      setState(() {
                        _selectedMapPoint = result;
                        _manualLatController.text =
                            result.coordinates.lat.toStringAsFixed(6);
                        _manualLngController.text =
                            result.coordinates.lng.toStringAsFixed(6);
                      });
                    }
                  },
                ),
              if (_locationInputType == LocationInputType.manual) ...[
                TextFormField(
                  controller: _pastedCoordsController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration(
                    'Paste Coordinates String',
                    isOptional: true,
                  ).copyWith(
                    hintText: 'e.g., (37.8, -119.3)',
                    suffixIcon: IconButton(
                      tooltip: 'Paste & Parse',
                      icon: const Icon(
                        Icons.content_paste_go_outlined,
                        color: Colors.white70,
                      ),
                      onPressed: () async {
                        final data =
                            await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          _pastedCoordsController.text = data!.text!;
                          _parseAndSetPastedCoordinates(data!.text!);
                        }
                      },
                    ),
                  ),
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
                        validator: (v) {
                          if (_locationInputType == LocationInputType.manual) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter latitude';
                            }
                            final lat = double.tryParse(v.trim());
                            if (lat == null || lat < -90 || lat > 90) {
                              return 'Invalid (-90 to 90)';
                            }
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
                        validator: (v) {
                          if (_locationInputType == LocationInputType.manual) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Enter longitude';
                            }
                            final lng = double.tryParse(v.trim());
                            if (lng == null || lng < -180 || lng > 180) {
                              return 'Invalid (-180 to 180)';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              _buildSectionTitle("Additional Info"),
              TextFormField(
                controller: _landmarkDescriptionController,
                style: const TextStyle(color: Colors.white),
                decoration:
                    _inputDecoration('Approach Directions', isOptional: true),
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _boulderDescriptionController,
                style: const TextStyle(color: Colors.white),
                decoration:
                    _inputDecoration('General Description', isOptional: true),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 32),
              // In your build method, inside the Column children:

              ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(
                        Icons.publish_outlined,
                        color: Colors.white,
                      ),
                label: Text(
                  _isLoading ? 'Publishing...' : 'Publish Boulder',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  // FIX: Removed 'const' from the next line
                  minimumSize: ui.Size(double.infinity, 50),
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

  Widget _buildSectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
        child: Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  Widget _buildImageDisplayWidget() {
    if (kIsWeb) {
      if (_selectedImageBytes != null) {
        return Image.memory(_selectedImageBytes!, fit: BoxFit.contain);
      }
      if (_selectedImageXFile != null) {
        return Image.network(_selectedImageXFile!.path, fit: BoxFit.contain);
      }
    } else {
      if (_selectedImageXFile != null) {
        return Image.file(File(_selectedImageXFile!.path), fit: BoxFit.contain);
      }
    }
    return const Center(
      child: Text(
        "No image to display.",
        style: TextStyle(color: Colors.white54),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {required bool isOptional}) {
    String displayLabel = isOptional
        ? label.replaceFirst(RegExp(r'\*$'), "") + ' (Optional)'
        : label;
    return InputDecoration(
      labelText: displayLabel,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 14,
        fontStyle: FontStyle.italic,
      ),
      filled: true,
      fillColor: Colors.grey.shade800,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: Colors.grey.shade700,
          width: 1,
        ),
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
        color: Colors.redAccent,
        fontWeight: FontWeight.w500,
        fontSize: 13,
      ),
    );
  }
}

// In add_boulder_page.dart, add this new class BEFORE the final '}' of _AddBoulderPageState

// In add_boulder_page.dart, replace the existing _MapPickerPreview class

// In add_boulder_page.dart, replace the existing _MapPickerPreview class

class _MapPickerPreview extends StatefulWidget {
  final Point? selectedPoint;
  final VoidCallback onTap;

  const _MapPickerPreview({
    this.selectedPoint,
    required this.onTap,
  });

  @override
  State<_MapPickerPreview> createState() => _MapPickerPreviewState();
}

class _MapPickerPreviewState extends State<_MapPickerPreview> {
  MapboxMap? _mapController;
  PointAnnotation? _annotation;
  PointAnnotationManager? _annotationManager;
  Uint8List? _markerImage;

  @override
  void initState() {
    super.initState();
    // Create a simple red dot for the preview marker.
    _createMarkerImage().then((image) {
      if (mounted) setState(() => _markerImage = image);
    });
  }

  @override
  void didUpdateWidget(covariant _MapPickerPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPoint != oldWidget.selectedPoint) {
      _updateCameraAndMarker();
    }
  }

  Future<void> _onMapCreated(MapboxMap controller) async {
    _mapController = controller;
    _annotationManager =
        await _mapController?.annotations.createPointAnnotationManager();
    _updateCameraAndMarker();
  }

  void _updateCameraAndMarker() async {
    if (_mapController == null || !mounted) return;
    if (widget.selectedPoint != null) {
      _mapController?.flyTo(
        CameraOptions(center: widget.selectedPoint, zoom: 15),
        MapAnimationOptions(duration: 600),
      );
      if (_markerImage != null) {
        if (_annotation == null) {
          _annotation = await _annotationManager?.create(
            PointAnnotationOptions(
                geometry: widget.selectedPoint!, image: _markerImage!),
          );
        } else {
          _annotation!.geometry = widget.selectedPoint!;
          _annotationManager?.update(_annotation!);
        }
      }
    } else {
      // If no point is selected, maybe center on a default location
      _mapController?.flyTo(
        CameraOptions(center: Point(coordinates: Position(0, 0)), zoom: 1),
        MapAnimationOptions(duration: 1),
      );
    }
  }

  Future<Uint8List> _createMarkerImage() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    final Paint paint = Paint()..color = Colors.redAccent;
    canvas.drawCircle(const Offset(15, 15), 15, paint);
    final img = await recorder.endRecording().toImage(30, 30);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AspectRatio(
        aspectRatio: 16 / 12,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade800,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade700, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10.5),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Non-interactive map background
                MapWidget(
                  onMapCreated: _onMapCreated,
                  styleUri: MapboxStyles.SATELLITE_STREETS,
                ),
                // AbsorbPointer prevents any interaction with the map itself
                AbsorbPointer(
                  child: Container(color: Colors.transparent),
                ),
                // Consistent "Tap to select" overlay
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.touch_app,
                            color: Colors.white, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          widget.selectedPoint == null
                              ? 'Tap to Select Location'
                              : 'Tap to Change Location',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
