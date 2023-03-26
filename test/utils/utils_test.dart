import 'dart:io';
import 'dart:typed_data';

import 'package:renogy_client/clients/dummy_renogy_client.dart';
import 'package:renogy_client/clients/renogy_client.dart';
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
  group('LocalTime', () {
    test('toString()', () {
      expect('00:00:00', LocalTime.midnight.toString());
      expect('22:12:02', LocalTime(22, 12, 2).toString());
    });
    test('today()', () {
      LocalTime.now();
    });
    test('compare', () {
      expect(true, LocalTime(2, 1, 1) > LocalTime(1, 12, 25));
    });
  });
}
