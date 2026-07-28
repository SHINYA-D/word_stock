import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:word_stock/core/firebase/firestore_path.dart';
import 'package:word_stock/domain/entities/folder.dart';
import 'package:word_stock/domain/entities/flashcard_result.dart';
import 'package:word_stock/domain/entities/user_settings.dart';
import 'package:word_stock/domain/entities/word.dart';

class FirestoreDataSource {
  FirestoreDataSource({required FirebaseFirestore firestore})
      : _firestore = firestore;

  final FirebaseFirestore _firestore;

  // ---- オフライン同期対応：エンティティを直接書き込むメソッド ----

  Future<void> writeFolder(Folder folder, String userId) {
    return _firestore.doc(FirestorePath.folder(userId, folder.id)).set({
      'name': folder.name,
      'parentFolderId': folder.parentFolderId,
      'createdAt': folder.createdAt,
      'updatedAt': folder.updatedAt,
    });
  }

  Future<void> deleteRemoteFolder(String userId, String folderId) {
    return _firestore.doc(FirestorePath.folder(userId, folderId)).delete();
  }

  Future<void> writeWord(Word word, String userId, String folderId) {
    return _firestore
        .doc(FirestorePath.word(userId, folderId, word.id))
        .set({
      'front': word.front,
      'back': word.back,
      'createdAt': word.createdAt,
      'updatedAt': word.updatedAt,
    });
  }

  Future<void> deleteRemoteWord(
      String userId, String folderId, String wordId) {
    return _firestore
        .doc(FirestorePath.word(userId, folderId, wordId))
        .delete();
  }

  Future<void> writeFlashcardResult(FlashcardResult result, String userId) {
    return _firestore
        .doc(FirestorePath.flashcardResult(userId, result.id))
        .set({
      'folderId': result.folderId,
      'totalCount': result.totalCount,
      'correctCount': result.correctCount,
      'date': result.date,
      'updatedAt': result.updatedAt,
    });
  }

  Future<void> deleteRemoteFlashcardResult(String userId, String flashcardResultId) {
    return _firestore.doc(FirestorePath.flashcardResult(userId, flashcardResultId)).delete();
  }

  Future<void> writeSettings(UserSettings settings, String userId) {
    return _firestore.doc(FirestorePath.settings(userId)).set({
      'colorTheme': settings.colorTheme,
      'darkMode': settings.darkMode,
      'updatedAt': settings.updatedAt ?? DateTime.now(),
    });
  }
}
