import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:renogy_client/utils/io.dart';
import 'package:test/expect.dart';

/// A memory buffer, stores all written bytes to [writtenBytes]; [readFully] will offer
/// bytes from [toReturn].
class Buffer implements IO {
   /// max number of bytes to accept during [write] and offer during [read].
  final int maxIOBytes;

  /// Holds bytes written via [write]
  final writtenBytes = BytesBuilder();

  /// Will be returned via [read].
  final toReturn = BytesBuilder();

  /// The current read pointer; next call to [readFully] will return byte from [toReturn]
  /// at this index. Automatically increased as [readFully] is called further.
  var readPointer = 0;

  Buffer({this.maxIOBytes = 1024});

  @override
  void close() {}

  @override
  Uint8List read(int bytes, {int timeout = -1}) {
    if (bytes < 0) throw ArgumentError.value(bytes, "bytes");

    final availableBytes = toReturn.length - readPointer;
    if (availableBytes <= 0) return Uint8List(0);
    final readLength = [bytes, maxIOBytes, availableBytes].min;

    final result = toReturn.toBytes().sublist(readPointer, readPointer + readLength);
    readPointer += readLength;
    return result;
  }

  @override
  int write(Uint8List bytes, {int timeout = -1}) {
    final byteCount = min(bytes.length, maxIOBytes);
    writtenBytes.add(bytes.sublist(0, byteCount).toList());
    return byteCount;
  }

  @override
  String toString() =>
      "Buffer(written=${writtenBytes.toBytes().toHex()}, toReturn=${toReturn.toBytes().toHex()}, readPointer=$readPointer)";

  void expectWrittenBytes(String hexBytes) {
    expect(hexBytes, writtenBytes.toBytes().toHex());
  }

  void toReturnAdd(String hex) {
    toReturn.add(_hexToBytes(hex).toList());
  }
}

extension Hex on Uint8List {
  String toHex() => map((e) => e.toRadixString(16).padLeft(2, '0')).join();
}

Uint8List _hexToBytes(String hex) {
  final result = <int>[];
  for (int i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return Uint8List.fromList(result);
}
