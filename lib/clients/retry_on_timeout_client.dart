import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/clients/renogy_modbus_client.dart';
import 'package:renogy_client/utils/closeable.dart';
import 'package:renogy_client/utils/io.dart';

/// Workarounds [Issue 10](https://github.com/mvysny/solar-controller-client/issues/10) by closing/reopening
/// the pipe on timeout.
///
/// The client will then re-throw the exception and will not reattempt to re-read new data. The reason is
/// that the main loop will call us again anyways.
class RetryOnTimeoutClient implements RenogyClient {
  /// The timeout, e.g. 1 second.
  final Duration timeout;
  /// The serial device name, e.g. `/dev/ttyUSB0`. [SerialPortIO] is constructed out of it.
  final File devName;
  RetryOnTimeoutClient(this.timeout, this.devName);

  /// Currently used [IO]. Closed on timeout.
  SerialPortIO? _io;

  /// Gets the current [IO], opening a new [SerialPortIO] if there's no current one.
  IO _getIO() {
    if (_io == null) {
      _io = SerialPortIO(devName);
      _io!.configure();
      _io!.drainQuietly(timeout);
    }
    return _io!;
  }

  static final _log = Logger((RetryOnTimeoutClient).toString());

  @override
  void close() {
    _io?.close();
    _io = null;
  }

  /// On timeout exception, the [_io] is closed and the exception is rethrown.
  T _runAndMitigateTimeouts<T>(T Function(IO) block) {
    try {
      return block(_getIO());
    } on RenogyException catch (e) {
      // perhaps there's some leftover data in the serial port? Drain.
      _log.warning("Caught $e, draining $_io");
      _io?.drainQuietly(timeout);
      rethrow;
    } on TimeoutException catch (e) {
      // the serial port would simply endlessly fail with TimeoutException.
      // Try to remedy the situation by closing the IO and opening it again on next request.
      _log.warning("Caught $e, closing $_io");
      _io?.closeQuietly();
      _io = null;
      rethrow;
    }
  }

  @override
  RenogyData getAllData({SystemInfo? cachedSystemInfo}) {
    return _runAndMitigateTimeouts<RenogyData>((io) => RenogyModbusClient(io, timeout).getAllData(cachedSystemInfo: cachedSystemInfo));
  }

  @override
  SystemInfo getSystemInfo() {
    return _runAndMitigateTimeouts<SystemInfo>((io) => RenogyModbusClient(io, timeout).getSystemInfo());
  }
}
