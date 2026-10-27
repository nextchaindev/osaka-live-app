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
  String get openSettings => '설정으로 이동';

  @override
  String get later => '나중에';

  @override
  String get cameraPermissionTitle => '카메라와 마이크 권한이 필요합니다';

  @override
  String get cameraPermissionMessage =>
      '라이브 영상을 촬영하려면 카메라와 마이크 권한이 필요합니다. 설정에서 권한을 허용해 주세요.';

  @override
  String get locationPermissionTitle => '위치 권한이 필요합니다';

  @override
  String get locationPermissionMessage =>
      '주변 라이브 콘텐츠를 확인하고 지도를 업데이트하려면 위치 권한이 필요합니다. 설정에서 권한을 허용해 주세요.';

  @override
  String get storagePermissionTitle => '저장 공간 권한이 필요합니다';

  @override
  String get storagePermissionMessage =>
      '파일을 다운로드하려면 저장 공간 권한이 필요합니다. 설정에서 권한을 허용해 주세요.';

  @override
  String get noInternetTitle => '인터넷 연결이 없습니다';

  @override
  String get noInternetMessage => '인터넷 연결을 확인한 후 다시 시도해 주세요.';

  @override
  String get retry => '다시 시도';

  @override
  String get pageError => '알 수 없는 오류가 발생했습니다.';

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
  String get liveOnlyPrompt => '🔒 갤러리 업로드 불가 · 현장 라이브만';

  @override
  String get liveVideoOnly => '5~30초 라이브 영상만 허용';

  @override
  String get maxVideoDuration => '최대 30초까지 촬영할 수 있어요';

  @override
  String get choosePhoto => '사진을 선택해 주세요';

  @override
  String get callReviewGps => '통화 리뷰 · GPS 인증중';

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
  String get exitConfirm => '앱을 종료하시겠습니까?';

  @override
  String get no => '아니요';

  @override
  String get yes => '네';

  @override
  String get updateRequired => '업데이트가 필요합니다';

  @override
  String get updateMessage => '최신 버전으로 업데이트하고 더 나은 경험을 누려보세요.';

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

  @override
  String get vjwPrepareTitle => 'Visit Japan Web 입력 도우미';

  @override
  String get vjwPrivacyNotice => '여권 정보는 저장하지 않아요. 입력값은 이 기기에만 보관돼요.';

  @override
  String get vjwFlightSection => '항공편';

  @override
  String get vjwStaySection => '숙소';

  @override
  String get vjwContactSection => '연락처';

  @override
  String get vjwFlightNumber => '항공편명';

  @override
  String get vjwArrivalDate => '도착일';

  @override
  String get vjwStayName => '숙소명';

  @override
  String get vjwPostalCode => '우편번호';

  @override
  String get vjwPrefecture => '도도부현';

  @override
  String get vjwCity => '시구정촌';

  @override
  String get vjwAddress => '주소';

  @override
  String get vjwBuilding => '건물명';

  @override
  String get vjwStayPhone => '숙소 전화번호';

  @override
  String get vjwContactPhone => '연락처 전화번호';

  @override
  String get vjwOpen => 'Visit Japan Web 열기';

  @override
  String get vjwDeleteAll => '저장된 값 모두 삭제';

  @override
  String get vjwInjected => '입력했어요';

  @override
  String get vjwNoFocus => '먼저 입력할 칸을 눌러주세요';

  @override
  String get vjwSelectUnsupported => '이 칸은 직접 선택해 주세요';

  @override
  String get vjwUnsupportedType => '이 칸에는 입력할 수 없어요';

  @override
  String get vjwCopied => '복사했어요. 길게 눌러 붙여넣기 하세요';

  @override
  String get vjwLoading => '저장된 값을 불러오는 중...';
}
