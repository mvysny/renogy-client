import 'dart:io';
import 'package:path/path.dart';

extension FileExtention on FileSystemEntity{
  /// Returns the file/directory name, excluding path, but including the extension (if any).
  String get name {
    return basename(path);
  }
}
