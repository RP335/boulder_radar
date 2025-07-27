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
import 'dart:math';

import 'drawing_page.dart';
import 'dart:ui' as ui;

enum LocationInputType { map, manual }

class EditBoulderPage extends StatefulWidget {
  final Map<String, dynamic> initialData;

  const EditBoulderPage({
    Key? key,
    required this.initialData,
  }) : super(key: key);

  @override
  State<EditBoulderPage> createState() => _EditBoulderPageState();
}

class _EditBoulderPageState extends State<EditBoulderPage> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _boulderId;

  final _nameController = TextEditingController();
  final _landmarkDescriptionController = TextEditingController();
  final _boulderDescriptionController = TextEditingController();
  final _manualLatController = TextEditingController();
  final _manualLngController = TextEditingController();
  final _pastedCoordsController = TextEditingController();
  final _firstAscentController = TextEditingController();
  final _firstAscentFocusNode = FocusNode();

  Map<String, String>? _selectedFirstAscentUser;
  List<dynamic> _userSearchResults = [];
  Timer? _debounce;
  bool _isSearchingUsers = false;

  XFile? _selectedImageXFile;
  Uint8List? _selectedImageBytes;
  String? _initialImageUrl;
  Map<String, dynamic>? _drawingResultData;
  String? _selectedGrade;
  Point? _selectedMapPoint;

  LocationInputType _locationInputType = LocationInputType.map;
  bool _isLoading = false;
  String _submissionStatus = "";

  final List<String> _fontScaleGrades = [
    '4', '5', '5+', '6A', '6A+', '6B', '6B+', '6C', '6C+', '7A', '7A+',
    '7B', '7B+', '7C', '7C+', '8A', '8A+', '8B', '8B+', '8C', '8C+', '9A'
  ];

  @override
  void initState() {
    super.initState();
    _populateFormWithInitialData();
    _firstAscentFocusNode.addListener(() {
      if (_firstAscentFocusNode.hasFocus && _firstAscentController.text.isEmpty) {
        _searchUsers("");
      }
    });
  }

  void _populateFormWithInitialData() {
    final data = widget.initialData;
    _boulderId = data['id'] as String?;

    _nameController.text = data['name'] ?? '';
    _boulderDescriptionController.text = data['description'] ?? '';

    final landmarks = data['landmarks'] as List<dynamic>?;
    if (landmarks != null && landmarks.isNotEmpty) {
      _landmarkDescriptionController.text = landmarks[0]['description'] ?? '';
    }

    _selectedGrade = data['grade'] as String?;

    final location = data['location'] as Map<String, dynamic>?;
    final coords = location?['coordinates'] as List<dynamic>?;
    if (coords != null && coords.length == 2) {
      final lat = coords[1] as double;
      final lon = coords[0] as double;
      _selectedMapPoint = Point(coordinates: Position(lon, lat));
      _manualLatController.text = lat.toStringAsFixed(6);
      _manualLngController.text = lon.toStringAsFixed(6);
    }

    final faUserName = data['first_ascent_user_name'] as String?;
    final faUserId = data['first_ascent_user_id'] as String?;
    if (faUserName != null && faUserId != null) {
      _firstAscentController.text = faUserName;
      _selectedFirstAscentUser = {'id': faUserId, 'name': faUserName};
    }

    final imagesList = data['images'] as List<dynamic>?;
    if (imagesList != null && imagesList.isNotEmpty) {
      _initialImageUrl = (imagesList[0] as Map<String, dynamic>?)?['url'] as String?;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _landmarkDescriptionController.dispose();
    _boulderDescriptionController.dispose();
    _manualLatController.dispose();
    _manualLngController.dispose();
    _pastedCoordsController.dispose();
    _firstAscentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _userSearchResults = []);
      return;
    }
    setState(() => _isSearchingUsers = true);
    try {
      final response = await _supabase.functions.invoke(
        'first-ascent-search',
        body: {'searchTerm': query},
      );
      if (response.status == 200) {
        setState(() => _userSearchResults = response.data);
      }
    } catch (e) {
      // Handle error
    } finally {
      setState(() => _isSearchingUsers = false);
    }
  }

  List<DropdownMenuItem<String>> _buildGradeDropdownItems() {
    final List<DropdownMenuItem<String>> items = [];
    items.add(DropdownMenuItem(
      enabled: false,
      child: Text("Fontainebleau Scale (Font)",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurpleAccent[100])),
    ));
    items.addAll(_fontScaleGrades.map((grade) =>
        DropdownMenuItem<String>(value: grade, child: Text(grade, style: const TextStyle(color: Colors.white)))));
    return items;
  }

  Future<void> _handleImageTap() async {
    if (_isLoading) return;
    if (_selectedImageXFile == null && _initialImageUrl == null) {
      await _showImageSourceDialog();
    } else {
      await _navigateToDrawingPage();
    }
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Colors.white70),
                title: const Text('Choose from Gallery', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _getImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Colors.white70),
                title: const Text('Take a Photo', style: TextStyle(color: Colors.white)),
                onTap: () {
                  _getImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _getImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? imageXFile = await picker.pickImage(
        source: source, imageQuality: 70, maxWidth: 1200, maxHeight: 1200);
      if (imageXFile != null && mounted) {
        setState(() {
          _selectedImageXFile = imageXFile;
          _selectedImageBytes = null;
          _drawingResultData = null;
          _initialImageUrl = null; // A new image overrides the initial one
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error picking image: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  void _cancelImage() {
    setState(() {
      _selectedImageXFile = null;
      _selectedImageBytes = null;
      _drawingResultData = null;
      _initialImageUrl = null;
    });
  }

  Future<void> _navigateToDrawingPage() async {
    if (_selectedImageXFile == null && _initialImageUrl == null) return;
    
    // To navigate to drawing page, we need a local file path.
    // If we only have a network URL, we can't edit it this way.
    // This is a limitation to consider. For now, only new images can be drawn on.
    if (_selectedImageXFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Drawing on existing images is not yet supported. Please select a new image to draw on.'),
            backgroundColor: Colors.orange));
        return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DrawingPage(imageXFile: _selectedImageXFile!)),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(hasDrawings ? 'Lines updated!' : 'No lines drawn.'),
          backgroundColor: hasDrawings ? Colors.blueAccent : Colors.orange));
    }
  }

  void _parseAndSetPastedCoordinates(String pastedText) {
    if (pastedText.trim().isEmpty) return;
    final RegExp coordRegex = RegExp(r"[\[\(\s]*([+-]?\d+\.?\d+)\s*[,;\s]+\s*([+-]?\d+\.?\d*)[\]\)\s]*");
    final match = coordRegex.firstMatch(pastedText.trim());

    if (match != null) {
      double? val1 = double.tryParse(match.group(1)!);
      double? val2 = double.tryParse(match.group(2)!);

      if (val1 != null && val2 != null) {
        double lat, lng;
        if (val1.abs() <= 90 && val2.abs() <= 180) {
          lat = val1; lng = val2;
        } else if (val2.abs() <= 90 && val1.abs() <= 180) {
          lat = val2; lng = val1;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Pasted values out of Lat/Lng range.'), backgroundColor: Colors.orange));
          return;
        }
        _manualLatController.text = lat.toStringAsFixed(6);
        _manualLngController.text = lng.toStringAsFixed(6);
        _pastedCoordsController.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Coords parsed: Lat: $lat, Lng: $lng'), backgroundColor: Colors.green));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Pasted text not recognized as "lat, lng".'), backgroundColor: Colors.orange));
    }
  }

  Future<void> _updateBoulder() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGrade == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please select a grade.'), backgroundColor: Colors.red));
      return;
    }
    if (_selectedImageXFile == null && _initialImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('An image of the boulder is required.'), backgroundColor: Colors.red));
      return;
    }

    setState(() {
      _submissionStatus = "";
      _isLoading = true;
    });

    try {
      String? finalImageUrl = _initialImageUrl;

      // If a new image was selected, upload it and get the new URL
      if (_selectedImageXFile != null) {
        final imageBytes = await _selectedImageXFile!.readAsBytes();
        final imageExt = _selectedImageXFile!.name.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$imageExt';
        final userId = _supabase.auth.currentUser!.id;
        final filePath = '$userId/$fileName';

        await _supabase.storage.from('boulder.radar.public.data').uploadBinary(
              filePath,
              imageBytes,
              fileOptions: FileOptions(contentType: 'image/$imageExt'),
            );
        finalImageUrl = _supabase.storage.from('boulder.radar.public.data').getPublicUrl(filePath);
      }

      double latitude = double.parse(_manualLatController.text.trim());
      double longitude = double.parse(_manualLngController.text.trim());

      final response = await _supabase.functions.invoke(
        'update-boulder',
        body: {
          'boulder_id': _boulderId,
          'name': _nameController.text.trim(),
          'grade': _selectedGrade!,
          'latitude': latitude,
          'longitude': longitude,
          'boulder_description': _boulderDescriptionController.text.trim(),
          'landmark_description': _landmarkDescriptionController.text.trim(),
          'first_ascent_user_id': _selectedFirstAscentUser?['id'],
          'image_url': finalImageUrl,
        },
      );

      if (response.status == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Boulder updated successfully!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      } else {
        throw Exception(response.data?['error']?.toString() ?? 'Failed to update boulder.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submissionStatus = 'Error: ${e.toString().replaceFirst("Exception: ", "")}';
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
        title: const Text('Edit Boulder'),
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
                        fontWeight: FontWeight.bold),
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
                      border: Border.all(color: Colors.grey.shade700, width: 1.5),
                    ),
                    child: (_selectedImageXFile != null || _initialImageUrl != null)
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
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      borderRadius: BorderRadius.circular(6)),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit_outlined, color: Colors.white, size: 18),
                                      SizedBox(width: 6),
                                      Text("Change/Draw Route",
                                          style: TextStyle(color: Colors.white, fontSize: 13)),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: GestureDetector(
                                  onTap: _isLoading ? null : _cancelImage,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.65),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_photo_alternate_outlined,
                                    size: 60, color: Colors.white60),
                                SizedBox(height: 12),
                                Text('Tap to add image*',
                                    style: TextStyle(color: Colors.white60, fontSize: 16)),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildSectionTitle("Boulder Details"),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Boulder Name*', isOptional: false),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Boulder name is required' : null,
              ),
              const SizedBox(height: 16),
              _buildSectionTitle("First Ascent (Optional)"),
              TextFormField(
                focusNode: _firstAscentFocusNode,
                controller: _firstAscentController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Search user...', isOptional: true),
                onChanged: (value) {
                  if (_debounce?.isActive ?? false) _debounce!.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), () {
                    _searchUsers(value);
                  });
                },
                onTap: () {
                  if (_firstAscentController.text.isEmpty) {
                    _searchUsers("");
                  }
                },
              ),
              if (_isSearchingUsers)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator(color: Colors.white70)),
                ),
              if (_userSearchResults.isNotEmpty)
                Container(
                  height: (_userSearchResults.length * 52.0).clamp(52.0, 208.0),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade700)),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: min(_userSearchResults.length, 4),
                    itemBuilder: (context, index) {
                      final user = _userSearchResults[index];
                      return ListTile(
                        title: Text(user['name'], style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          setState(() {
                            _selectedFirstAscentUser = {'id': user['id'], 'name': user['name']};
                            _firstAscentController.text = user['name'];
                            _userSearchResults = [];
                          });
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGrade,
                items: _buildGradeDropdownItems(),
                onChanged: (String? v) {
                  if (v != null) setState(() => _selectedGrade = v);
                },
                decoration: _inputDecoration('Select Grade*', isOptional: false)
                    .copyWith(contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12)),
                dropdownColor: Colors.grey.shade800,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70),
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
                  selectedBackgroundColor: Colors.deepPurpleAccent.withOpacity(0.8),
                  side: BorderSide(color: Colors.grey.shade700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                segments: const <ButtonSegment<LocationInputType>>[
                  ButtonSegment<LocationInputType>(
                      value: LocationInputType.map,
                      label: Text('Use Map'),
                      icon: Icon(Icons.map_outlined)),
                  ButtonSegment<LocationInputType>(
                      value: LocationInputType.manual,
                      label: Text('Enter Manually'),
                      icon: Icon(Icons.edit_location_alt_outlined)),
                ],
                selected: <LocationInputType>{_locationInputType},
                onSelectionChanged: (Set<LocationInputType> newSelection) =>
                    setState(() => _locationInputType = newSelection.first),
              ),
              const SizedBox(height: 16),
              if (_locationInputType == LocationInputType.map)
                _MapPickerPreview(
                  selectedPoint: _selectedMapPoint,
                  onTap: () async {
                    final result = await Navigator.of(context).push<Point?>(
                      MaterialPageRoute(builder: (_) => FullScreenMapPickerPage(initialPoint: _selectedMapPoint)),
                    );
                    if (result != null && mounted) {
                      setState(() {
                        _selectedMapPoint = result;
                        _manualLatController.text = result.coordinates.lat.toStringAsFixed(6);
                        _manualLngController.text = result.coordinates.lng.toStringAsFixed(6);
                      });
                    }
                  },
                ),
              if (_locationInputType == LocationInputType.manual) ...[
                TextFormField(
                  controller: _pastedCoordsController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Paste Coordinates String', isOptional: true).copyWith(
                    hintText: 'e.g., (37.8, -119.3)',
                    suffixIcon: IconButton(
                      tooltip: 'Paste & Parse',
                      icon: const Icon(Icons.content_paste_go_outlined, color: Colors.white70),
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data?.text != null) {
                          _pastedCoordsController.text = data!.text!;
                          _parseAndSetPastedCoordinates(data.text!);
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
                        decoration: _inputDecoration('Latitude*', isOptional: false),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: (v) {
                          if (_locationInputType == LocationInputType.manual) {
                            if (v == null || v.trim().isEmpty) return 'Enter latitude';
                            final lat = double.tryParse(v.trim());
                            if (lat == null || lat < -90 || lat > 90) return 'Invalid (-90 to 90)';
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
                        decoration: _inputDecoration('Longitude*', isOptional: false),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        validator: (v) {
                          if (_locationInputType == LocationInputType.manual) {
                            if (v == null || v.trim().isEmpty) return 'Enter longitude';
                            final lng = double.tryParse(v.trim());
                            if (lng == null || lng < -180 || lng > 180) return 'Invalid (-180 to 180)';
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
                decoration: _inputDecoration('Approach Directions', isOptional: true),
                maxLines: 3,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _boulderDescriptionController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('General Description', isOptional: true),
                maxLines: 4,
                minLines: 1,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Icon(Icons.check_circle_outline, color: Colors.white),
                label: Text(_isLoading ? 'Updating...' : 'Update Boulder',
                    style: const TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _isLoading ? null : _updateBoulder,
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
        child: Text(title,
            style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 18,
                fontWeight: FontWeight.w600)),
      );

  Widget _buildImageDisplayWidget() {
    if (_selectedImageXFile != null) {
      if (kIsWeb) {
        return Image.network(_selectedImageXFile!.path, fit: BoxFit.contain);
      } else {
        return Image.file(File(_selectedImageXFile!.path), fit: BoxFit.contain);
      }
    }
    if (_initialImageUrl != null) {
      return Image.network(_initialImageUrl!, fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Center(child: Text("Could not load image.", style: TextStyle(color: Colors.white54))),
      );
    }
    return const Center(child: Text("No image to display.", style: TextStyle(color: Colors.white54)));
  }

  InputDecoration _inputDecoration(String label, {required bool isOptional}) {
    String displayLabel = isOptional ? '$label (Optional)' : label;
    return InputDecoration(
      labelText: displayLabel,
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: TextStyle(
          color: Colors.grey.shade500, fontSize: 14, fontStyle: FontStyle.italic),
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

class _MapPickerPreview extends StatefulWidget {
  final Point? selectedPoint;
  final VoidCallback onTap;

  const _MapPickerPreview({this.selectedPoint, required this.onTap});

  @override
  State<_MapPickerPreview> createState() => _MapPickerPreviewState();
}

class _MapPickerPreviewState extends State<_MapPickerPreview> {
  MapboxMap? _mapController;
  PointAnnotation? _annotation;
  PointAnnotationManager? _annotationManager;
  Uint8List? _markerImage;
  bool _isLoadingPreview = true;

  @override
  void initState() {
    super.initState();
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
    _annotationManager = await _mapController?.annotations.createPointAnnotationManager();
    await _centerMapInitially();
  }

  Future<void> _centerMapInitially() async {
    if (_mapController == null || !mounted) return;

    Point? targetPoint = widget.selectedPoint;
    double targetZoom = 15.0;

    if (targetPoint == null) {
      try {
        final permission = await geo.Geolocator.checkPermission();
        if (permission == geo.LocationPermission.denied || permission == geo.LocationPermission.deniedForever) {
          targetPoint = Point(coordinates: Position(0, 0));
          targetZoom = 1.0;
        } else {
          final pos = await geo.Geolocator.getCurrentPosition(desiredAccuracy: geo.LocationAccuracy.high);
          targetPoint = Point(coordinates: Position(pos.longitude, pos.latitude));
          targetZoom = 14.0;
        }
      } catch (e) {
        targetPoint = Point(coordinates: Position(0, 0));
        targetZoom = 1.0;
      }
    }

    _mapController?.flyTo(CameraOptions(center: targetPoint, zoom: targetZoom),
        MapAnimationOptions(duration: 800));
    _updateCameraAndMarker();

    if (mounted) {
      setState(() => _isLoadingPreview = false);
    }
  }

  void _updateCameraAndMarker() async {
    if (_mapController == null || !mounted || widget.selectedPoint == null) return;

    final currentCamera = await _mapController!.getCameraState();
    if (currentCamera.center.coordinates.lat != widget.selectedPoint!.coordinates.lat ||
        currentCamera.center.coordinates.lng != widget.selectedPoint!.coordinates.lng) {
      _mapController?.flyTo(
          CameraOptions(center: widget.selectedPoint, zoom: 15), MapAnimationOptions(duration: 600));
    }

    if (_markerImage != null) {
      if (_annotation == null) {
        _annotationManager
            ?.create(PointAnnotationOptions(geometry: widget.selectedPoint!, image: _markerImage!))
            .then((newAnnotation) {
          if (mounted) _annotation = newAnnotation;
        });
      } else {
        _annotation!.geometry = widget.selectedPoint!;
        _annotationManager?.update(_annotation!);
      }
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
                MapWidget(onMapCreated: _onMapCreated, styleUri: MapboxStyles.MAPBOX_STREETS),
                if (_isLoadingPreview)
                  Container(
                    color: Colors.black.withOpacity(0.6),
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
                AbsorbPointer(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _isLoadingPreview ? Colors.transparent : Colors.black.withOpacity(0.5),
                    ),
                    child: Center(
                      child: _isLoadingPreview
                          ? const SizedBox.shrink()
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.touch_app, color: Colors.white, size: 40),
                                const SizedBox(height: 8),
                                Text(
                                  widget.selectedPoint == null
                                      ? 'Tap to Select Location'
                                      : 'Tap to Change Location',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
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
