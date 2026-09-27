/// ローカルとリモートの同期のうち、UseCase から呼ぶもの。
///
/// 同期の失敗は例外にせず、次のきっかけで再試行する（呼び出し側の成否に影響させない）。
abstract class SyncRepository {
  /// ログイン成功時の同期（取得 → 送信）。取得の基準がなければ、すべてのデータを取得する。
  Future<void> syncRemoteToLocalOnLogin();

  /// ログアウト前に未送信の変更を送信し、送れずに残った件数を返す。
  /// 残った変更は消さず、同じユーザーが次にログインしたときに送信する。
  Future<int> pushBeforeSignOut();
}
