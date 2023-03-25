import 'dart:typed_data';

import 'package:libserialport/libserialport.dart';
import 'package:logging/logging.dart';
import 'package:renogy_client/utils/closeable.dart';

/// An IO pipe supporting most basic operations.
abstract class IO implements Closeable {
  /// Read data from the serial port.
  ///
  /// The operation attempts to read N `bytes` of data.
  ///
  /// If `timeout` is 0 or greater, the read operation is blocking.
  /// The timeout is specified in milliseconds. Pass 0 to wait infinitely.
  Uint8List read(int bytes, {int timeout = -1});

  /// Write data to the serial port.
  ///
  /// If `timeout` is 0 or greater, the write operation is blocking.
  /// The timeout is specified in milliseconds. Pass 0 to wait infinitely.
  ///
  /// Returns the amount of bytes written.
  int write(Uint8List bytes, {int timeout = -1});
}

extension FullyIO on IO {
  /// Writes all [bytes] to the underlying IO. Blocks until the bytes are written.
  /// Does nothing if the array is empty.
  void writeFully(Uint8List bytes) {
    if (bytes.isEmpty) return;

    var current = 0;
    while (current < bytes.length) {
      var bytesWritten = write(bytes.sublist(current), timeout: 0);
      if (bytesWritten <= 0) throw StateError("write returned $bytesWritten");
      current += bytesWritten;
    }
  }

  /// Reads exactly [noBytes] from this IO, blocking indefinitely.
  Uint8List readFully(int noBytes) {
    if (noBytes < 0) throw ArgumentError.value(noBytes, "noBytes", "must be 0 or greater");
    if (noBytes == 0) return Uint8List(0);
    final result = read(noBytes, timeout: 10000);
    if (result.length != noBytes) throw StateError("Expected $noBytes bytes but got $result");
    return result;
  }
}

/// Wraps [SerialPort] as [IO].
class SerialPortIO implements IO {
  final SerialPort _serialPort;
  SerialPortIO(this._serialPort);

  @override
  void close() {
    if (!_serialPort.close()) {
      _log.warning("Failed to close $_serialPort");
    }
  }

  @override
  Uint8List read(int bytes, {int timeout = -1}) {
    return _serialPort.read(bytes, timeout: timeout);
  }

  @override
  int write(Uint8List bytes, {int timeout = -1}) {
    return _serialPort.write(bytes, timeout: timeout);
  }

  static final Logger _log = Logger((SerialPortIO).toString());
}
