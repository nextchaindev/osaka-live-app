import 'dart:io';

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
    if (_isSigningIn) {
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'login_in_progress',
      );
    }

    _isSigningIn = true;
    try {
      return switch (provider) {
        'google' => await _signInWithGoogle(),
        'apple' => await _signInWithApple(),
        _ => SocialLoginResult.error(
            provider: provider,
            errorCode: 'unsupported_provider',
          ),
      };
    } finally {
      _isSigningIn = false;
    }
  }

  Future<SocialLoginResult> _signInWithGoogle() async {
    const provider = 'google';
    final serverClientId = EnvConfig.instance.googleServerClientId.trim();
    final iosClientId = EnvConfig.instance.googleIosClientId.trim();

    if (serverClientId.isEmpty || (Platform.isIOS && iosClientId.isEmpty)) {
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'google_not_configured',
      );
    }

    try {
      _googleInitialization ??= GoogleSignIn.instance.initialize(
        clientId: Platform.isIOS ? iosClientId : null,
        serverClientId: serverClientId,
      );
      await _googleInitialization;

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        return SocialLoginResult.error(
          provider: provider,
          errorCode: 'google_not_supported',
        );
      }

      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
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
      if (error.code == GoogleSignInExceptionCode.canceled ||
          error.code == GoogleSignInExceptionCode.interrupted) {
        return SocialLoginResult.cancelled(provider);
      }
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'google_sign_in_failed',
      );
    } catch (_) {
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'google_sign_in_failed',
      );
    }
  }

  Future<SocialLoginResult> _signInWithApple() async {
    const provider = 'apple';
    if (!Platform.isIOS) {
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'apple_not_supported',
      );
    }

    try {
      if (!await SignInWithApple.isAvailable()) {
        return SocialLoginResult.error(
          provider: provider,
          errorCode: 'apple_not_supported',
        );
      }

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
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
      if (error.code == AuthorizationErrorCode.canceled) {
        return SocialLoginResult.cancelled(provider);
      }
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'apple_sign_in_failed',
      );
    } catch (_) {
      return SocialLoginResult.error(
        provider: provider,
        errorCode: 'apple_sign_in_failed',
      );
    }
  }
}
