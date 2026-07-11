import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart' show XFile;

/// Web-safe multipart file builder for image uploads.
///
/// `MultipartFile.fromFile()` uses `dart:io` and throws on Flutter web
/// ("MultipartFile is only supported where dart:io is available"), so any photo upload fails in Chrome.
/// Reading the bytes via `XFile(path).readAsBytes()` works on EVERY platform — on mobile it reads the file,
/// on web it fetches the picked blob — so we build the part from bytes instead. No behavior change on
/// Android/iOS; the server receives the same multipart image field.
Future<MultipartFile> multipartFromPath(String path, {String? filename}) async {
  final bytes = await XFile(path).readAsBytes();
  var name = (filename == null || filename.isEmpty)
      ? path.split('/').last.split('?').first
      : filename;
  // Web blob URLs carry no extension; give the server a sane image filename so ImageField validation is happy.
  if (!name.contains('.')) name = '$name.jpg';
  return MultipartFile.fromBytes(bytes, filename: name);
}
