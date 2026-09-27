import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/infrastructure/data_sources/local/local_date.dart';

void main() {
  group('toDateColumn', () {
    test('端末ローカルのDateTimeを渡した場合、末尾がZのUTC文字列になる', () {
      final local = DateTime(2024, 1, 1, 9, 0, 0);

      final result = toDateColumn(local);

      expect(result, endsWith('Z'));
      expect(DateTime.parse(result).isAtSameMomentAs(local), isTrue);
    });

    test('UTCのDateTimeを渡した場合、そのままの時刻でZ付き文字列になる', () {
      final utc = DateTime.utc(2024, 1, 1, 9, 0, 0);

      final result = toDateColumn(utc);

      expect(result, '2024-01-01T09:00:00.000Z');
    });
  });

  group('toNullableDateColumn', () {
    test('nullを渡した場合、nullが返る（保存側）', () {
      expect(toNullableDateColumn(null), isNull);
    });

    test('値を渡した場合、toDateColumnと同じ結果が返る', () {
      final local = DateTime(2024, 1, 1, 9, 0, 0);

      final result = toNullableDateColumn(local);

      expect(result, toDateColumn(local));
    });
  });

  group('fromDateColumn', () {
    test('Z付きの文字列を渡した場合、同じ時刻でisUtcがfalseのDateTimeが返る', () {
      const column = '2024-01-01T09:00:00.000Z';

      final result = fromDateColumn(column);

      expect(result.isAtSameMomentAs(DateTime.parse(column)), isTrue);
      expect(result.isUtc, isFalse);
    });

    test('バージョン1のZなし文字列を渡した場合、端末のタイムゾーンの時刻として読む', () {
      const column = '2024-01-01T09:00:00.000';

      final result = fromDateColumn(column);

      expect(result, DateTime(2024, 1, 1, 9, 0, 0));
      expect(result.isUtc, isFalse);
    });
  });

  group('fromNullableDateColumn', () {
    test('nullを渡した場合、nullが返る（読み出し側）', () {
      expect(fromNullableDateColumn(null), isNull);
    });

    test('値を渡した場合、fromDateColumnと同じ結果が返る', () {
      const column = '2024-01-01T09:00:00.000Z';

      final result = fromNullableDateColumn(column);

      expect(result, fromDateColumn(column));
    });
  });

  group('往復変換', () {
    test('保存してから読み出した場合、同じ時刻に戻る', () {
      final original = DateTime(2024, 6, 15, 12, 34, 56);

      final restored = fromDateColumn(toDateColumn(original));

      expect(restored.isAtSameMomentAs(original), isTrue);
    });
  });
}
