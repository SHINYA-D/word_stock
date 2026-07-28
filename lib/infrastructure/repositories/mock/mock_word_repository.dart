import 'package:fpdart/fpdart.dart';
import 'package:word_stock/core/error/failure.dart';
import 'package:word_stock/domain/entities/word.dart';
import 'package:word_stock/domain/repositories/word_repository.dart';

/// 開発用インメモリ単語リポジトリ。
class MockWordRepository implements WordRepository {
  // key: "$userId/$folderId"
  final _store = <String, List<Word>>{};
  int _idCounter = 1;

  MockWordRepository() {
    // サンプルデータ
    const userId = 'mock-user-id';
    _store['$userId/folder-1'] = [
      Word(
        id: 'word-1',
        front: 'apple',
        back: 'りんご',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Word(
        id: 'word-2',
        front: 'banana',
        back: 'バナナ',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Word(
        id: 'word-3',
        front: 'cherry',
        back: 'さくらんぼ',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
    _store['$userId/folder-2'] = [
      Word(
        id: 'word-4',
        front: 'accomplish',
        back: '達成する・成し遂げる',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Word(
        id: 'word-5',
        front: 'adequate',
        back: '十分な・適切な',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  String _key(String userId, String folderId) => '$userId/$folderId';

  List<Word> _words(String userId, String folderId) =>
      _store.putIfAbsent(_key(userId, folderId), () => []);

  @override
  Future<Either<Failure, List<Word>>> getWords({
    required String userId,
    required String folderId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return Right(List.of(_words(userId, folderId)));
  }

  @override
  Future<Either<Failure, Word>> createWord({
    required String userId,
    required String folderId,
    required String front,
    required String back,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final now = DateTime.now();
    final word = Word(
      id: 'word-${_idCounter++}',
      front: front,
      back: back,
      createdAt: now,
      updatedAt: now,
    );
    _words(userId, folderId).add(word);
    return Right(word);
  }

  @override
  Future<Either<Failure, Word>> updateWord({
    required String userId,
    required String folderId,
    required String wordId,
    required String front,
    required String back,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final list = _words(userId, folderId);
    final idx = list.indexWhere((w) => w.id == wordId);
    if (idx == -1) return const Left(Failure.notFound());
    final updated = list[idx].copyWith(front: front, back: back, updatedAt: DateTime.now());
    list[idx] = updated;
    return Right(updated);
  }

  @override
  Future<Either<Failure, Unit>> deleteWord({
    required String userId,
    required String folderId,
    required String wordId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _words(userId, folderId).removeWhere((w) => w.id == wordId);
    return const Right(unit);
  }
}
