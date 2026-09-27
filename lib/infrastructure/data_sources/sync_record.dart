/// 同期の対象になるデータの種類。
enum SyncEntity { folder, word, flashcardResult, settings }

/// 同期でローカルとリモートの間を受け渡す 1 件分のデータ。
///
/// Firestore や SQLite の型に依存しない形で持つ（日時は常に UTC の [DateTime]）。
/// [fields] には updatedAt / deletedAt / serverUpdatedAt 以外の項目を入れる。
class SyncRecord {
  const SyncRecord({
    required this.entity,
    required this.id,
    required this.fields,
    required this.updatedAt,
    this.parentId,
    this.deletedAt,
    this.serverUpdatedAt,
  });

  final SyncEntity entity;

  /// データの id。設定は userId。
  final String id;

  /// 単語の親フォルダの id。単語以外は null。
  final String? parentId;

  final Map<String, Object?> fields;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// リモートが受け取った時刻（サーバーの時計）。ローカルのデータでは null。
  final DateTime? serverUpdatedAt;

  bool get isDeleted => deletedAt != null;
}
