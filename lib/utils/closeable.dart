import 'package:logging/logging.dart';

/// A resource that can be closed.
abstract class Closeable {
  /// Closes this resource. May throw an exception if the close fails.
  void close();
}

extension CloseQuietly on Closeable {
  /// Closes this resource. Does not throw an exception.
  void closeQuietly() {
    try {
      close();
    } on Exception catch (e, s) {
      Logger(runtimeType.toString()).warning("Failed to close $this", e, s);
    }
  }
}
