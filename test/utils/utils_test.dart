import 'dart:io';
import 'dart:typed_data';

import 'package:renogy_client/clients/dummy_renogy_client.dart';
import 'package:renogy_client/clients/renogy_client.dart';
import 'package:renogy_client/utils/modbus_crc.dart';
import 'package:test/test.dart';

void main() {
  group('ModbusCRC', () {
    test('emptyArray', () {
      expect(0xFFFF, ModbusCRC().crc);
    });
    test('simpleArray', () {
      var crc = ModbusCRC();
      crc.update(Uint8List.fromList([1, 3, 0, 10, 0, 1]));
      expect(0x08A4, crc.crc);
    });
    test('simpleArray2', () {
      var crc = ModbusCRC();
      crc.update(Uint8List.fromList([1, 3, 2, 0x18, 0x14]));
      expect(0x4BB2, crc.crc);
    });
    test('simpleArray3', () {
      expect(0x4BB2, crcOf(Uint8List.fromList([1, 3, 2, 0x18, 0x14])));
      expect(0x4BB2, crcOf2(Uint8List.fromList([1, 3, 2]), Uint8List.fromList([0x18, 0x14])));
    });
  });
}
