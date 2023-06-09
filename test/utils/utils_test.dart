import 'dart:convert';
import 'dart:typed_data';

import 'package:renogy_client/utils/modbus_crc.dart';
import 'package:renogy_client/utils/time_utils.dart';
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
  group('LocalDate', () {
    test('toString()', () {
      expect('2022-01-01', LocalDate(2022, 1, 1).toString());
      expect('1995-12-25', LocalDate(1995, 12, 25).toString());
    });
    test('today()', () {
      LocalDate.today();
    });
    test('compare', () {
      expect(true, LocalDate(2022, 1, 1) > LocalDate(1995, 12, 25));
    });
  });
  test('decodeAscii', () {
    expect("    MT4830      ", ascii.decode([0x20, 0x20, 0x20, 0x20, 0x4D, 0x54, 0x34, 0x38, 0x33, 0x30, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20]));
    expect("", ascii.decode([]));
  });
}
