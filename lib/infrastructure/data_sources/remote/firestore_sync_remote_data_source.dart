import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:word_stock/core/firebase/firestore_path.dart';
import 'package:word_stock/infrastructure/data_sources/sync_record.dart';
import 'sync_remote_data_source.dart';

/// [SyncRemoteDataSource] の Firestore 実装。
///
/// 各ドキュメントは、データの項目に加えて updatedAt / deletedAt / serverUpdatedAt を持つ。
/// serverUpdatedAt はサーバーの時刻（`FieldValue.serverTimestamp()`）で、差分取得の基準に使う。
class FirestoreSyncRemoteDataSource implements SyncRemoteDataSource {
  FirestoreSyncRemoteDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  static const _serverUpdatedAt = 'serverUpdatedAt';

  /// データの項目（updatedAt / deletedAt / serverUpdatedAt 以外）と、そのうち日時のもの。
  static const _fields = <SyncEntity, List<String>>{
    SyncEntity.folder: ['name', 'parentFolderId', 'createdAt'],
    SyncEntity.word: ['front', 'back', 'createdAt'],
    SyncEntity.flashcardResult: ['folderId', 'totalCount', 'correctCount', 'date'],
    SyncEntity.settings: ['colorTheme', 'darkMode'],
  };
  static const _dateFields = {'createdAt', 'date'};

  @override
  Future<List<SyncRecord>> fetchChanges(
    String userId,
    SyncEntity entity, {
    DateTime? since,
  }) async {
    switch (entity) {
      case SyncEntity.folder:
        final snap = await _changed(
            _firestore.collection(FirestorePath.folders(userId)), since);
        return snap.docs.map((d) => _toRecord(entity, d.id, d.data())).toList();
      case SyncEntity.word:
        // 単語はフォルダごとのサブコレクションにあるので、削除済みを含む全フォルダをたどる
        final folders =
            await _firestore.collection(FirestorePath.folders(userId)).get();
        final out = <SyncRecord>[];
        for (final folder in folders.docs) {
          final snap = await _changed(
            _firestore.collection(FirestorePath.words(userId, folder.id)),
            since,
          );
          out.addAll(snap.docs.map(
              (d) => _toRecord(entity, d.id, d.data(), parentId: folder.id)));
        }
        return out;
      case SyncEntity.flashcardResult:
        final snap = await _changed(
            _firestore.collection(FirestorePath.flashcardResults(userId)), since);
        return snap.docs.map((d) => _toRecord(entity, d.id, d.data())).toList();
      case SyncEntity.settings:
        final doc = await _firestore.doc(FirestorePath.settings(userId)).get();
        final data = doc.data();
        if (data == null) return [];
        final record = _toRecord(entity, userId, data);
        final received = record.serverUpdatedAt;
        // 差分取得では、基準より後に受け付けたものだけを返す
        // （serverUpdatedAt が無い旧いドキュメントは、全件取得のときだけ返す）
        if (since != null && (received == null || !received.isAfter(since))) {
          return [];
        }
        return [record];
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _changed(
    CollectionReference<Map<String, dynamic>> collection,
    DateTime? since,
  ) {
    if (since == null) return collection.get();
    return collection
        .where(_serverUpdatedAt, isGreaterThan: Timestamp.fromDate(since))
        .get();
  }

  @override
  Future<SyncRecord?> writeIfNewer(String userId, SyncRecord record) {
    final ref = _firestore.doc(_path(userId, record));
    return _firestore.runTransaction<SyncRecord?>((transaction) async {
      final snapshot = await transaction.get(ref);
      final data = snapshot.data();
      if (data != null) {
        final remote = _toRecord(record.entity, record.id, data,
            parentId: record.parentId);
        if (!record.updatedAt.isAfter(remote.updatedAt)) return remote;
      }
      transaction.set(ref, _toDocument(record), SetOptions(merge: true));
      return null;
    });
  }

  String _path(String userId, SyncRecord record) {
    switch (record.entity) {
      case SyncEntity.folder:
        return FirestorePath.folder(userId, record.id);
      case SyncEntity.word:
        final folderId = record.parentId;
        if (folderId == null) {
          throw ArgumentError('word ${record.id} has no parent folder');
        }
        return FirestorePath.word(userId, folderId, record.id);
      case SyncEntity.flashcardResult:
        return FirestorePath.flashcardResult(userId, record.id);
      case SyncEntity.settings:
        return FirestorePath.settings(userId);
    }
  }

  Map<String, Object?> _toDocument(SyncRecord record) {
    final doc = <String, Object?>{};
    for (final field in _fields[record.entity]!) {
      if (record.fields.containsKey(field)) doc[field] = record.fields[field];
    }
    doc['updatedAt'] = record.updatedAt;
    if (record.entity != SyncEntity.settings) doc['deletedAt'] = record.deletedAt;
    doc[_serverUpdatedAt] = FieldValue.serverTimestamp();
    return doc;
  }

  SyncRecord _toRecord(
    SyncEntity entity,
    String id,
    Map<String, dynamic> data, {
    String? parentId,
  }) {
    final fields = <String, Object?>{};
    for (final field in _fields[entity]!) {
      final value = data[field];
      fields[field] = _dateFields.contains(field) ? _toDate(value) : value;
    }
    return SyncRecord(
      entity: entity,
      id: id,
      parentId: parentId,
      fields: fields,
      // updatedAt の無い旧いドキュメントは、どのローカルの変更よりも古いものとして扱う
      updatedAt: _toDate(data['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      deletedAt: _toDate(data['deletedAt']),
      serverUpdatedAt: _toDate(data[_serverUpdatedAt]),
    );
  }

  DateTime? _toDate(Object? value) =>
      value is Timestamp ? value.toDate().toUtc() : null;
}
