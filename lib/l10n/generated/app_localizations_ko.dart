// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appName => '오사카라이브';

  @override
  String get openSettings => '설정 열기';

  @override
  String get later => '나중에 하기';

  @override
  String get cameraPermissionTitle => '카메라와 마이크 권한이 필요합니다';

  @override
  String get cameraPermissionMessage =>
      '라이브 영상을 촬영하려면 카메라와 마이크 권한이 필요합니다. 설정에서 권한을 허용해 주세요.';

  @override
  String get locationPermissionTitle => '위치 권한이 필요합니다';

  @override
  String get locationPermissionMessage => '내 주변 라이브를 보여드리려면 위치 권한이 필요해요';

  @override
  String get storagePermissionTitle => '저장 공간 권한이 필요합니다';

  @override
  String get storagePermissionMessage =>
      '파일을 다운로드하려면 저장 공간 권한이 필요합니다. 설정에서 권한을 허용해 주세요.';

  @override
  String get noInternetTitle => '인터넷이 끊겼어요';

  @override
  String get noInternetMessage => '와이파이나 데이터가 켜져 있는지 확인해 주세요';

  @override
  String get retry => '다시 시도';

  @override
  String get pageError => '화면을 불러오지 못했어요';

  @override
  String get pageNotFound => '페이지를 찾을 수 없습니다.';

  @override
  String get refresh => '새로고침';

  @override
  String get downloading => '다운로드 중...';

  @override
  String get downloadComplete => '다운로드 완료';

  @override
  String get downloadFailed => '다운로드 실패';

  @override
  String get open => '열기';

  @override
  String get cancel => '취소';

  @override
  String get album => '앨범';

  @override
  String get photo => '사진';

  @override
  String get video => '동영상';

  @override
  String get profilePhoto => '프로필 사진';

  @override
  String get coverPhoto => '대표 사진';

  @override
  String get retake => '다시 찍기';

  @override
  String get next => '다음';

  @override
  String get takePhoto => '사진을 촬영해 주세요';

  @override
  String get chatPhotoPrompt => '채팅에 보낼 사진을 촬영하세요';

  @override
  String get chatVideoPrompt => '채팅에 보낼 동영상을 촬영하세요';

  @override
  String get liveOnlyPrompt => '🔒 저장된 영상은 못 올려요 · 지금 여기서만';

  @override
  String get liveVideoOnly => '5초에서 30초까지 찍을 수 있어요';

  @override
  String get maxVideoDuration => '최대 30초까지 촬영할 수 있어요';

  @override
  String get choosePhoto => '사진을 선택해 주세요';

  @override
  String get callReviewGps => '여기 계신지 확인 중';

  @override
  String get photoMode => '사진';

  @override
  String get videoMode => '동영상 · 최대 30초';

  @override
  String get chooseMedia => '사진 또는 동영상을 선택해 주세요';

  @override
  String get pageUrlError => '페이지를 찾을 수 없습니다. 다시 시도하거나 인터넷 연결을 확인해 주세요.';

  @override
  String get invalidUrl => '잘못된 URL입니다. 다시 시도해 주세요.';

  @override
  String get exitConfirm => '오사카 라이브를 닫을까요?';

  @override
  String get no => '아니요';

  @override
  String get yes => '네';

  @override
  String get updateRequired => '업데이트가 필요합니다';

  @override
  String get updateMessage => '오사카 라이브 새 버전이 나왔어요.\n지금 업데이트해 주세요.';

  @override
  String get updateNow => '업데이트하기';

  @override
  String get updateContinueMessage => '계속 사용하려면 업데이트가 필요합니다.';

  @override
  String get splashHeadline => '오사카를 만나보세요.\n지금, 라이브로.';

  @override
  String get splashSubhead => '이 순간에 함께하세요.';

  @override
  String get splashDescription =>
      '실시간 영상, 진짜 사람들, 실제 장소.\n현장의 생생한 정보를 확인하고\n더 나은 계획을 세워보세요.';

  @override
  String get cameraNotFound => '기기에서 카메라를 찾을 수 없습니다.';

  @override
  String get cameraStartError => '카메라를 시작할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get recordStartError => '녹화를 시작할 수 없습니다.';

  @override
  String get recordPauseError => '녹화를 일시 중지할 수 없습니다.';

  @override
  String get recordResumeError => '녹화를 다시 시작할 수 없습니다.';

  @override
  String get recordStopError => '녹화를 종료할 수 없습니다.';

  @override
  String get takePhotoError => '사진을 촬영할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get sendVideoError => '동영상을 전송할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get downloadFailedDetail => '파일을 저장하지 못했습니다. 다시 시도해 주세요.';
}
