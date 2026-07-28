class FirestorePath {
  // --- folders ---
  static String folders(String userId) => 'users/$userId/folders';

  static String folder(String userId, String folderId) =>
      'users/$userId/folders/$folderId';

  // --- words ---
  static String words(String userId, String folderId) =>
      'users/$userId/folders/$folderId/words';

  static String word(String userId, String folderId, String wordId) =>
      'users/$userId/folders/$folderId/words/$wordId';

  // --- flashcard_results ---
  static String flashcardResults(String userId) =>
      'users/$userId/flashcard_results';

  static String flashcardResult(String userId, String flashcardResultId) =>
      'users/$userId/flashcard_results/$flashcardResultId';

  // --- settings ---
  static String settings(String userId) => 'users/$userId/settings/config';
}
