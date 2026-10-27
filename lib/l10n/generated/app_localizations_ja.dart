// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => '大阪ライブ';

  @override
  String get openSettings => '設定を開く';

  @override
  String get later => 'あとで';

  @override
  String get cameraPermissionTitle => 'カメラとマイクへのアクセスが必要です';

  @override
  String get cameraPermissionMessage =>
      'ライブ動画の撮影にはカメラとマイクへのアクセスが必要です。設定で許可してください。';

  @override
  String get locationPermissionTitle => '位置情報へのアクセスが必要です';

  @override
  String get locationPermissionMessage =>
      '近くのライブコンテンツの表示と地図の更新には位置情報が必要です。設定で許可してください。';

  @override
  String get storagePermissionTitle => 'ストレージへのアクセスが必要です';

  @override
  String get storagePermissionMessage =>
      'ファイルのダウンロードにはストレージへのアクセスが必要です。設定で許可してください。';

  @override
  String get noInternetTitle => 'インターネットに接続されていません';

  @override
  String get noInternetMessage => '接続を確認して、もう一度お試しください。';

  @override
  String get retry => '再試行';

  @override
  String get pageError => '予期しないエラーが発生しました。';

  @override
  String get pageNotFound => 'ページが見つかりません。';

  @override
  String get refresh => '再読み込み';

  @override
  String get downloading => 'ダウンロード中...';

  @override
  String get downloadComplete => 'ダウンロード完了';

  @override
  String get downloadFailed => 'ダウンロード失敗';

  @override
  String get open => '開く';

  @override
  String get cancel => 'キャンセル';

  @override
  String get album => 'アルバム';

  @override
  String get photo => '写真';

  @override
  String get video => '動画';

  @override
  String get profilePhoto => 'プロフィール写真';

  @override
  String get coverPhoto => 'カバー写真';

  @override
  String get retake => '撮り直す';

  @override
  String get next => '次へ';

  @override
  String get takePhoto => '写真を撮影してください';

  @override
  String get chatPhotoPrompt => 'チャットに送る写真を撮影してください';

  @override
  String get chatVideoPrompt => 'チャットに送る動画を撮影してください';

  @override
  String get liveOnlyPrompt => '🔒 ギャラリーからのアップロード不可 · ライブ撮影のみ';

  @override
  String get liveVideoOnly => '5〜30秒のライブ動画のみ撮影できます';

  @override
  String get maxVideoDuration => '最大30秒まで撮影できます';

  @override
  String get choosePhoto => '写真を選択してください';

  @override
  String get callReviewGps => '通話レビュー · GPS確認中';

  @override
  String get photoMode => '写真';

  @override
  String get videoMode => '動画 · 最大30秒';

  @override
  String get chooseMedia => '写真または動画を選択してください';

  @override
  String get pageUrlError => 'ページが見つかりません。再試行するか、インターネット接続を確認してください。';

  @override
  String get invalidUrl => 'URLが正しくありません。もう一度お試しください。';

  @override
  String get exitConfirm => 'アプリを終了しますか？';

  @override
  String get no => 'いいえ';

  @override
  String get yes => 'はい';

  @override
  String get updateRequired => 'アップデートが必要です';

  @override
  String get updateMessage => '最新バージョンに更新して、より快適にご利用ください。';

  @override
  String get updateNow => '今すぐ更新';

  @override
  String get updateContinueMessage => '続行するにはアップデートが必要です。';

  @override
  String get splashHeadline => '大阪を見つけよう。\n今をライブで。';

  @override
  String get splashSubhead => 'この瞬間を一緒に。';

  @override
  String get splashDescription =>
      'ライブ映像、本物の人々、実際の場所。\n現地の情報を確認して\nより良い計画を立てましょう。';

  @override
  String get cameraNotFound => 'このデバイスにカメラが見つかりません。';

  @override
  String get cameraStartError => 'カメラを起動できません。もう一度お試しください。';

  @override
  String get recordStartError => '録画を開始できません。';

  @override
  String get recordPauseError => '録画を一時停止できません。';

  @override
  String get recordResumeError => '録画を再開できません。';

  @override
  String get recordStopError => '録画を終了できません。';

  @override
  String get takePhotoError => '写真を撮影できません。もう一度お試しください。';

  @override
  String get sendVideoError => '動画を送信できません。もう一度お試しください。';

  @override
  String get downloadFailedDetail => 'ファイルを保存できませんでした。もう一度お試しください。';
}
