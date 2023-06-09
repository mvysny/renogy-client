import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:libserialport/libserialport.dart';
import 'package:logging/logging.dart';
import 'package:renogy_client/utils/closeable.dart';

/// An IO pipe supporting most basic operations. Basically a thin wrap over [SerialPort]. Synchronous.
abstract class IO implements Closeable {
  /// Read data from the serial port.
  ///
  /// The operation attempts to read N `bytes` of data.
  ///
  /// If [timeout] is 0 or greater, the read operation is blocking.
  /// The [timeout] is specified in milliseconds. Pass 0 to wait infinitely.
  ///
  /// May return fewer data than requested if the operation timed out.
  Uint8List read(int bytes, {int timeout = -1});

  /// Write data to the serial port.
  ///
  /// If [timeout] is 0 or greater, the write operation is blocking.
  /// The [timeout] is specified in milliseconds. Pass 0 to wait infinitely.
  ///
  /// Returns the amount of bytes written. May write less data if the operation
  /// timed out.
  int write(Uint8List bytes, {int timeout = -1});
}

extension FullyIO on IO {
  /// Writes all [bytes] to the underlying IO. Blocks until the bytes are written,
  /// or until the timeout passes. Throws [TimeoutException] on timeout. Does nothing if the array is empty.
  ///
  /// The [timeout] is specified in milliseconds. Pass 0 to wait infinitely.
  void writeFully(Uint8List bytes, {Duration timeout = Duration.zero}) {
    RangeError.checkNotNegative(timeout.inMilliseconds, "timeout");
    if (bytes.isEmpty) return;
    var bytesWritten = write(bytes, timeout: timeout.inMilliseconds);
    if (bytesWritten != bytes.length) {
      throw TimeoutException("Timeout writing data; expected to write ${bytes.length} bytes but wrote $bytesWritten bytes", timeout);
    }
  }

  /// Reads exactly [noBytes] from this IO, blocking until the bytes are read,
  /// or until the timeout passes. Throws [TimeoutException] on timeout. Does nothing if 0 bytes are to be read.
  ///
  /// The [timeout] is specified in milliseconds. Pass 0 to wait infinitely.
  Uint8List readFully(int noBytes, {Duration timeout = Duration.zero}) {
    RangeError.checkNotNegative(noBytes, "noBytes");
    RangeError.checkNotNegative(timeout.inMilliseconds, "timeout");
    if (noBytes == 0) return Uint8List(0);
    final result = read(noBytes, timeout: timeout.inMilliseconds);
    if (result.length != noBytes) {
      throw TimeoutException("Timeout reading data; expected to read $noBytes bytes but got $result bytes", timeout);
    }
    return result;
  }

  /// Drains the pipe so that there are no stray bytes left. Blocks up until [timeout].
  void drain([Duration timeout = const Duration(seconds : 1)]) {
    try {
      while(true) {
        readFully(128, timeout: timeout);
      }
    } on TimeoutException {
      // okay
    }
  }

  void drainQuietly([Duration timeout = const Duration(seconds : 1)]) {
    final log = Logger((SerialPortIO).toString());
    log.fine("Draining $this");
    try {
      drain(timeout);
    } catch (e, s) {
      log.warning("Failed to drain $this", e, s);
    }
  }
}

/// Wraps [SerialPort] as [IO].
class SerialPortIO implements IO {
  /// The serial device name, e.g. `/dev/ttyUSB0`.
  final File devName;
  final SerialPort _serialPort;
  SerialPortIO(this.devName) : _serialPort = SerialPort(devName.path);

  void configure() {
    _serialPort.openReadWrite();
    final SerialPortConfig config = _serialPort.config;
    config.parity = SerialPortParity.none;
    config.stopBits = 0;
    config.bits = 8;
    config.cts = SerialPortCts.ignore;
    config.rts = SerialPortRts.off;
    config.xonXoff = SerialPortXonXoff.disabled;
    config.baudRate = 9600;
    config.setFlowControl(SerialPortFlowControl.none);
  }

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
    final result = _serialPort.write(bytes, timeout: timeout);
    _serialPort.drain();
    return result;
  }

  static final Logger _log = Logger((SerialPortIO).toString());

  @override
  String toString() => 'SerialPortIO{devName: $devName}';
}
