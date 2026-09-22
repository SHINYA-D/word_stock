import 'package:freezed_annotation/freezed_annotation.dart';

part 'sample.freezed.dart';
part 'sample.g.dart';

@freezed
abstract class Sample with _$Sample {
  const factory Sample({
    required String id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Sample;

  factory Sample.fromJson(Map<String, dynamic> json) => _$SampleFromJson(json);
}
