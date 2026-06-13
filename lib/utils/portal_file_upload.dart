import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<TaskSnapshot> uploadPortalFile(
  Reference reference,
  File file, {
  SettableMetadata? metadata,
}) async {
  if (!kIsWeb) {
    return reference.putFile(file, metadata);
  }

  final Uint8List bytes = await XFile(file.path).readAsBytes();
  return reference.putData(
    bytes,
    metadata ?? SettableMetadata(contentType: _contentType(file.path)),
  );
}

Widget portalPickedImage(
  File file, {
  BoxFit fit = BoxFit.cover,
  double? width,
  double? height,
}) {
  if (kIsWeb) {
    return Image.network(file.path, fit: fit, width: width, height: height);
  }
  return Image.file(file, fit: fit, width: width, height: height);
}

ImageProvider portalPickedImageProvider(File file) {
  if (kIsWeb) return NetworkImage(file.path);
  return FileImage(file);
}

String _contentType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.mp4')) return 'video/mp4';
  if (lower.endsWith('.mov')) return 'video/quicktime';
  return 'image/jpeg';
}
