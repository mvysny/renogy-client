import 'dart:io';

import 'package:logging/logging.dart';
import 'package:renogy_client/clients/renogy_client.dart';
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
}
