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

/// A resource that can be closed.
abstract class AsyncCloseable {
  /// Closes this resource. May throw an exception if the close fails.
  Future close();
}

extension AsyncCloseQuietly on AsyncCloseable {
  /// Closes this resource. Does not throw an exception.
  Future closeQuietly() async {
    try {
      await close();
    } on Exception catch (e, s) {
      Logger(runtimeType.toString()).warning("Failed to close $this", e, s);
    }
  }
}
