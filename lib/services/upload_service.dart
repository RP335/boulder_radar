// lib/services/upload_service.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// This line is crucial. It tells Dart that a generated file is part of this one.
// It will show an error until you run the build_runner command.
part 'upload_service.g.dart';

// 1. Data model for a pending upload
@HiveType(typeId: 0)
class PendingUpload extends HiveObject {
  @HiveField(0)
  final String boulderName;
  @HiveField(1)
  final String areaId;
  @HiveField(2)
  final String grade;
  @HiveField(3)
  final double latitude;
  @HiveField(4)
  final double longitude;
  @HiveField(5)
  final String boulderDescription;
  @HiveField(6)
  final String landmarkDescription;
  @HiveField(7)
  final Uint8List? imageBytes;
  @HiveField(8)
  final String? imageFileExtension;
  @HiveField(9)
  final Map<String, dynamic>? drawingData;

  PendingUpload({
    required this.boulderName,
    required this.areaId,
    required this.grade,
    required this.latitude,
    required this.longitude,
    required this.boulderDescription,
    required this.landmarkDescription,
    this.imageBytes,
    this.imageFileExtension,
    this.drawingData,
  });
}

// 2. The Singleton Service to manage the queue
class UploadService {
  UploadService._privateConstructor();
  static final UploadService instance = UploadService._privateConstructor();

  final SupabaseClient _supabase = Supabase.instance.client;
  late final Box<PendingUpload> _queueBox;
  StreamSubscription? _connectivitySubscription;

  void init() {
    _queueBox = Hive.box<PendingUpload>('upload_queue');

    // THE FIX: The incorrect type cast has been completely removed from this line.
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen(_handleConnectivityChange);

    _processQueue();
  }

  Future<void> queueUpload(PendingUpload upload) async {
    await _queueBox.add(upload);
  }

  void _handleConnectivityChange(ConnectivityResult result) {
    // MODIFIED: The check no longer uses .contains()
    if (result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi) {
      print("Connection restored! Processing upload queue...");
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_queueBox.isEmpty) return;

    final connectivityResult = await (Connectivity().checkConnectivity());
    // MODIFIED: The check no longer uses .contains()
    if (connectivityResult == ConnectivityResult.none) return;

    print("Processing ${_queueBox.length} items in the queue.");
    final List<int> keys = _queueBox.keys.cast<int>().toList();
    for (final key in keys) {
      final upload = _queueBox.get(key);
      if (upload == null) continue;
      try {
        final success = await performUpload(upload);
        if (success) {
          await upload.delete();
        }
      } catch (e) {
        print("Failed to upload queued item. Will retry later. Error: $e");
      }
    }
  }

  Future<bool> performUpload(PendingUpload data) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null)
      throw Exception('User not authenticated for queued upload.');

    final boulderPayload = {
      'name': data.boulderName,
      'area_id': data.areaId,
      'uploaded_by': userId,
      'latitude': data.latitude,
      'longitude': data.longitude,
      'grade': data.grade,
      'description': data.boulderDescription,
    };
    final boulderResponse =
        await _supabase.functions.invoke('add-boulder', body: boulderPayload);
    if (boulderResponse.status != 201) {
      throw Exception(
          'Failed to add boulder from queue: ${boulderResponse.data}');
    }
    final newBoulderId = boulderResponse.data['id'];

    if (data.landmarkDescription.isNotEmpty) {
      _supabase.functions.invoke('add-landmark', body: {
        'boulder_id': newBoulderId,
        'description': data.landmarkDescription
      });
    }

    if (data.imageBytes != null && data.imageFileExtension != null) {
      final uniqueFileName =
          '${newBoulderId}_${DateTime.now().millisecondsSinceEpoch}.${data.imageFileExtension}';
      final storagePath = 'public/boulders/$newBoulderId/$uniqueFileName';
      await _supabase.storage.from('boulder.radar.public.data').uploadBinary(
            storagePath,
            data.imageBytes!,
            fileOptions: FileOptions(
                contentType: 'image/${data.imageFileExtension}', upsert: false),
          );
      final publicImageUrl = _supabase.storage
          .from('boulder.radar.public.data')
          .getPublicUrl(storagePath);
      _supabase.functions.invoke('add-image', body: {
        'boulder_id': newBoulderId,
        'image_path': publicImageUrl,
        'has_drawings': data.drawingData?['has_drawings'] ?? false,
        'drawing_data': data.drawingData?['drawing_data'],
      });
    }
    return true;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }
}
