import 'package:flutter_test/flutter_test.dart';
import 'package:word_stock/core/firebase/firestore_path.dart';

void main() {
  group('FirestorePath', () {
    test('folders()は3セグメント(コレクション)のパスを返す', () {
      expect(FirestorePath.folders('user-1'), 'users/user-1/folders');
    });

    test('folder()は4セグメント(ドキュメント)のパスを返す', () {
      expect(
        FirestorePath.folder('user-1', 'folder-1'),
        'users/user-1/folders/folder-1',
      );
    });

    test('words()は5セグメント(コレクション)のパスを返す', () {
      expect(
        FirestorePath.words('user-1', 'folder-1'),
        'users/user-1/folders/folder-1/words',
      );
    });

    test('word()は6セグメント(ドキュメント)のパスを返す', () {
      expect(
        FirestorePath.word('user-1', 'folder-1', 'word-1'),
        'users/user-1/folders/folder-1/words/word-1',
      );
    });

    test('testResults()は3セグメント(コレクション)のパスを返す', () {
      expect(
        FirestorePath.testResults('user-1'),
        'users/user-1/test_results',
      );
    });

    test('testResult()は4セグメント(ドキュメント)のパスを返す', () {
      expect(
        FirestorePath.testResult('user-1', 'result-1'),
        'users/user-1/test_results/result-1',
      );
    });

    test(
      'settings()は4セグメント(ドキュメント)のパスを返し、末尾がconfigである'
      '(旧実装は users/{userId}/settings という3セグメントの'
      'コレクションパスを誤って返しており、_firestore.doc()に渡すと'
      '実行時例外になっていたバグの回帰テスト)',
      () {
        final path = FirestorePath.settings('user-1');

        expect(path, 'users/user-1/settings/config');
        expect(path.split('/'), hasLength(4));
        expect(path.split('/').last, 'config');
      },
    );

    test('settings()はuserIdごとに異なるパスを返す', () {
      expect(
        FirestorePath.settings('user-1'),
        isNot(FirestorePath.settings('user-2')),
      );
    });
  });
}
