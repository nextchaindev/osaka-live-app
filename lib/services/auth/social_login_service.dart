import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:osaka_app/config/env_config.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SocialLoginResult {
  const SocialLoginResult({
    required this.status,
    required this.provider,
    this.idToken,
    this.errorCode,
  });

  final String status;
  final String provider;
  final String? idToken;
  final String? errorCode;

  factory SocialLoginResult.success({
    required String provider,
    required String idToken,
  }) {
    return SocialLoginResult(
      status: 'success',
      provider: provider,
      idToken: idToken,
    );
  }

  factory SocialLoginResult.cancelled(String provider) {
    return SocialLoginResult(status: 'cancelled', provider: provider);
  }

  factory SocialLoginResult.error({
    required String provider,
    required String errorCode,
  }) {
    return SocialLoginResult(
      status: 'error',
      provider: provider,
      errorCode: errorCode,
    );
  }
}

class SocialLoginService {
  SocialLoginService._();

  static final SocialLoginService instance = SocialLoginService._();

  Future<void>? _googleInitialization;
  bool _isSigningIn = false;

  Future<SocialLoginResult> signIn(String provider) async {
    debugPrint('[SNS][Flutter] signIn start provider=$provider');
    if (_isSigningIn) {
      debugPrint('[SNS][Flutter] signIn rejected: login already in progress');
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'login_in_progress',
      );
    }

    _isSigningIn = true;
    try {
      final result = switch (provider) {
        'google' => await _signInWithGoogle(),
        'apple' => await _signInWithApple(),
        _ => SocialLoginResult.error(
            provider: provider,
            errorCode: 'unsupported_provider',
          ),
      };
      debugPrint(
        '[SNS][Flutter] signIn complete provider=$provider '
        'status=${result.status} errorCode=${result.errorCode ?? '-'} '
        'hasIdToken=${result.idToken?.isNotEmpty == true}',
      );
      return result;
    } finally {
      _isSigningIn = false;
    }
  }

  Future<SocialLoginResult> _signInWithGoogle() async {
    const provider = 'google';
    final serverClientId = EnvConfig.instance.googleServerClientId.trim();
    final iosClientId = EnvConfig.instance.googleIosClientId.trim();

    if (serverClientId.isEmpty || (Platform.isIOS && iosClientId.isEmpty)) {
      debugPrint(
        '[SNS][Flutter] Google configuration missing '
        'platform=${Platform.operatingSystem} '
        'hasServerClientId=${serverClientId.isNotEmpty} '
        'hasIosClientId=${iosClientId.isNotEmpty}',
      );
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'google_not_configured',
      );
    }

    try {
      debugPrint(
        '[SNS][Flutter] Google initialize '
        'platform=${Platform.operatingSystem}',
      );
      _googleInitialization ??= GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS ? iosClientId : null,
        serverClientId: serverClientId,
      );
      await _googleInitialization;
      debugPrint('[SNS][Flutter] Google initialize success');

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        debugPrint('[SNS][Flutter] Google authenticate is not supported');
        return SocialLoginResult.error(
          provider: provider,
          errorCode: 'google_not_supported',
        );
      }

      debugPrint('[SNS][Flutter] Google authenticate opening account picker');
      final account = await GoogleSignIn.instance.authenticate();
      debugPrint('[SNS][Flutter] Google authenticate returned an account');
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint('[SNS][Flutter] Google account returned without idToken');
        return SocialLoginResult.error(
          provider: provider,
          errorCode: 'missing_id_token',
        );
      }

      return SocialLoginResult.success(
        provider: provider,
        idToken: idToken,
      );
    } on GoogleSignInException catch (error) {
      debugPrint(
        '[SNS][Flutter] GoogleSignInException '
        'code=${error.code} description=${error.description}',
      );
      final description = error.description?.toLowerCase() ?? '';
      final isAccountReauthFailure =
          description.contains('account reauth failed');
      if (error.code == GoogleSignInExceptionCode.canceled &&
          !isAccountReauthFailure) {
        return SocialLoginResult.cancelled(provider);
      }
      return SocialLoginResult.error(
        provider: provider,
        errorCode: isAccountReauthFailure
            ? 'google_account_reauth_failed'
            : 'google_${error.code.name}',
      );
    } catch (error, stackTrace) {
      debugPrint('[SNS][Flutter] Unexpected Google sign-in error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'google_sign_in_failed',
      );
    }
  }

  Future<SocialLoginResult> _signInWithApple() async {
    const provider = 'apple';
    if (!Platform.isIOS) {
      debugPrint('[SNS][Flutter] Apple Sign-In is only supported on iOS');
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'apple_not_supported',
      );
    }

    try {
      debugPrint('[SNS][Flutter] Checking Apple Sign-In availability');
      if (!await SignInWithApple.isAvailable()) {
        debugPrint('[SNS][Flutter] Apple Sign-In is unavailable');
        return SocialLoginResult.error(
          provider: provider,
          errorCode: 'apple_not_supported',
        );
      }

      debugPrint('[SNS][Flutter] Opening Apple authorization sheet');
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      debugPrint('[SNS][Flutter] Apple authorization returned a credential');
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint('[SNS][Flutter] Apple credential returned without idToken');
        return SocialLoginResult.error(
          provider: provider,
          errorCode: 'missing_id_token',
        );
      }

      return SocialLoginResult.success(
        provider: provider,
        idToken: idToken,
      );
    } on SignInWithAppleAuthorizationException catch (error) {
      debugPrint(
        '[SNS][Flutter] Apple authorization exception '
        'code=${error.code} message=${error.message}',
      );
      if (error.code == AuthorizationErrorCode.canceled) {
        return SocialLoginResult.cancelled(provider);
      }
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'apple_${error.code.name}',
      );
    } catch (error, stackTrace) {
      debugPrint('[SNS][Flutter] Unexpected Apple sign-in error: $error');
      debugPrintStack(stackTrace: stackTrace);
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'apple_sign_in_failed',
      );
    }
  }
}
