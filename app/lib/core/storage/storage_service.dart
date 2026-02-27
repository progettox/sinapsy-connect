import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_client_provider.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(ref.watch(supabaseClientProvider));
});

class StorageService {
  StorageService(this._client);

  final SupabaseClient _client;

  Future<String> uploadCampaignCoverImage({
    required String brandId,
    required Uint8List bytes,
    required String originalFileName,
    String bucket = 'campaign-covers',
    bool preferSignedUrl = false,
  }) async {
    final safeFileName = _sanitizeFileName(originalFileName);
    final extension = _fileExtension(safeFileName);
    final objectPath =
        '$brandId/${DateTime.now().millisecondsSinceEpoch}_$safeFileName';

    await _client.storage
        .from(bucket)
        .uploadBinary(
          objectPath,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: _contentTypeForExtension(extension),
          ),
        );

    if (preferSignedUrl) {
      try {
        return await _client.storage
            .from(bucket)
            .createSignedUrl(objectPath, 60 * 60 * 24 * 30);
      } on StorageException {
        return _client.storage.from(bucket).getPublicUrl(objectPath);
      }
    }

    final publicUrl = _client.storage.from(bucket).getPublicUrl(objectPath);
    if (publicUrl.isNotEmpty) return publicUrl;

    return _client.storage
        .from(bucket)
        .createSignedUrl(objectPath, 60 * 60 * 24 * 30);
  }

  Future<String> uploadProfileAvatar({
    required String userId,
    required Uint8List bytes,
    required String originalFileName,
    bool preferSignedUrl = false,
  }) {
    return uploadCampaignCoverImage(
      brandId: userId,
      bytes: bytes,
      originalFileName: originalFileName,
      bucket: 'profile-avatars',
      preferSignedUrl: preferSignedUrl,
    );
  }

  String _sanitizeFileName(String fileName) {
    final cleaned = fileName
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    if (cleaned.isEmpty) {
      return 'cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
    }
    return cleaned;
  }

  String _fileExtension(String fileName) {
    final index = fileName.lastIndexOf('.');
    if (index < 0 || index == fileName.length - 1) return '';
    return fileName.substring(index + 1).toLowerCase();
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'jpeg':
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }
}
