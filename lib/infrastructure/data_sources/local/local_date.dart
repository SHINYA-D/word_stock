/// SQLite の日時列と [DateTime] の変換（変換は LocalDataSource 層だけで行う）。
///
/// 保存は UTC の ISO8601 文字列（末尾 `Z`）。読み出すときは端末のタイムゾーンに戻す。
/// バージョン1で保存した `Z` なしの文字列は、端末のタイムゾーンの時刻として読む。
String toDateColumn(DateTime value) => value.toUtc().toIso8601String();

String? toNullableDateColumn(DateTime? value) =>
    value == null ? null : toDateColumn(value);

DateTime fromDateColumn(Object? value) =>
    DateTime.parse(value! as String).toLocal();

DateTime? fromNullableDateColumn(Object? value) =>
    value == null ? null : fromDateColumn(value);
