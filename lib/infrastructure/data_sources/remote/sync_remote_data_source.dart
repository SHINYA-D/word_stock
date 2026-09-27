import 'package:word_stock/infrastructure/data_sources/sync_record.dart';

/// 同期で使うリモートの読み書き。
///
/// リモートの種類（現在は Firestore）に依存する処理は、この実装クラスだけに閉じ込める。
/// Firebase をやめる場合は、このインターフェースの別の実装を用意して差し替える。
abstract class SyncRemoteDataSource {
  /// [since] より後にリモートが受け付けた変更（削除を含む）を返す。
  /// [since] が null なら、すべてのデータを返す。
  Future<List<SyncRecord>> fetchChanges(
    String userId,
    SyncEntity entity, {
    DateTime? since,
  });

  /// リモートの同じデータの updatedAt が [record] より古い（または存在しない）ときだけ書き込む。
  ///
  /// 比べてから書き込むまでの間に、他の端末の書き込みが割り込まないようにする。
  /// 書き込んだら null、書き込まなかった（リモートの方が新しいか同じ）ら、そのリモートのデータを返す。
  Future<SyncRecord?> writeIfNewer(String userId, SyncRecord record);
}
