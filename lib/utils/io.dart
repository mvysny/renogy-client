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
  /// If `timeout` is 0 or greater, the read operation is blocking.
  /// The timeout is specified in milliseconds. Pass 0 to wait infinitely.
  ///
  /// May return fewer data than requested if the operation timed out.
  Uint8List read(int bytes, {int timeout = -1});

  /// Write data to the serial port.
  ///
  /// If `timeout` is 0 or greater, the write operation is blocking.
  /// The timeout is specified in milliseconds. Pass 0 to wait infinitely.
  ///
  /// Returns the amount of bytes written. May write less data if the operation
  /// timed out.
  int write(Uint8List bytes, {int timeout = -1});
}

extension FullyIO on IO {
  /// Writes all [bytes] to the underlying IO. Blocks until the bytes are written.
  /// Does nothing if the array is empty.
  void writeFully(Uint8List bytes) {
    if (bytes.isEmpty) return;
    var bytesWritten = write(bytes, timeout: 0);
    if (bytesWritten != bytes.length) throw StateError("write returned $bytesWritten");
  }

  /// Reads exactly [noBytes] from this IO, blocking indefinitely.
  Uint8List readFully(int noBytes) {
    RangeError.checkNotNegative(noBytes, "noBytes");
    if (noBytes == 0) return Uint8List(0);
    final result = read(noBytes, timeout: 0);
    if (result.length != noBytes) throw StateError("Expected $noBytes bytes but got $result");
    return result;
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
    // _serialPort.config = config;
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
    var result = _serialPort.write(bytes, timeout: timeout);
    _serialPort.drain();
    return result;
  }

  static final Logger _log = Logger((SerialPortIO).toString());

  @override
  String toString() => 'SerialPortIO{devName: $devName}';
}
