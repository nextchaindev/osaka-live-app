import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:osaka_app/repositories/auth_repository.dart';
import 'package:osaka_app/widgets/common/toast.dart';

/// Helper for WebView-related operations
/// Contains utility methods for WebView functionality (URL handling, deep links, debug)
///
/// Note: Auth-related methods have been moved to AuthRepository
class WebViewHelper {
  // ==================== URL Utilities (Static Methods) ====================

  /// Convert intent URL to app scheme
  /// Example: intent://... -> supertoss://...
  Uri convertAndAdjustUrl(String url) {
    // Step 1: Check if the URL starts with 'intent:' and handle the scheme
    String? scheme;
    if (url.startsWith('intent:')) {
      // Check if the scheme is embedded in the main URL
      final schemeIndex =
          url.indexOf(':', 7); // Find the first ':' after 'intent:'
      if (schemeIndex != -1 && !url.contains('#Intent;scheme=')) {
        // Scheme is embedded in the main part (e.g., hdcardappcardansimclick)
        scheme = url.substring(7, schemeIndex);
        url = url.replaceFirst('intent:$scheme', 'https');
      } else if (url.contains('#Intent;scheme=')) {
        // Scheme is in the #Intent section
        final intentPart = url.split('#Intent;').last;
        final intentRegex = RegExp(r'scheme=([^;]+);');
        final match = intentRegex.firstMatch(intentPart);
        if (match != null) {
          scheme = Uri.decodeComponent(match.group(1)!);
          url = url.replaceFirst('intent:', 'https:');
        }
      }
    }

    if (scheme == null) {
      throw Exception('Unable to extract scheme from the URL');
    }

    // Parse the modified URL using Uri
    final uri = Uri.parse(url);

    // Extract query parameters from the main part of the URL
    final queryParameters = Map<String, String>.from(uri.queryParameters);

    // Step 2: Extract intent parameters from the #Intent section
    final intentPart = url.split('#Intent;').last;
    final intentParameters = <String, String>{};
    final intentRegex = RegExp(r'([a-zA-Z0-9._-]+)=([^;]+);');
    for (final match in intentRegex.allMatches(intentPart)) {
      intentParameters[match.group(1)!] = Uri.decodeComponent(match.group(2)!);
    }

    // Remove unnecessary parameters like 'scheme' and 'package'
    intentParameters.remove('scheme');
    intentParameters.remove('package');

    // Merge all query parameters
    final allParameters = {...queryParameters, ...intentParameters};

    // Step 3: Construct the final URL with the correct scheme
    final finalUri = Uri(
      scheme: scheme,
      host: uri.host,
      path: uri.path,
      queryParameters: allParameters,
    );

    return finalUri;
  }

  /// Extract package name from intent URL
  String? getIntentPackage(String intentUri) {
    // Extract the package using a regex or splitting based on ";"
    final packageMatch = RegExp(r'package=([^;]+)').firstMatch(intentUri);
    return packageMatch?.group(1);
  }

  /// Check if URL is non-website URL (not http/https)
  static bool isNonWebsiteUrl(String url) {
    try {
      Uri uri = Uri.parse(url);
      return uri.scheme != 'http' && uri.scheme != 'https';
    } catch (e) {
      return true; // Return true for invalid URLs
    }
  }

  // ==================== Debug Utilities ====================

  /// Copy FCM token to clipboard for debugging
  Future<void> handleCopyFCMToken(FToast fToast) async {
    String? myDeviceToken = await AuthRepository().getFcmToken();

    if (myDeviceToken != null) {
      Clipboard.setData(ClipboardData(text: myDeviceToken));
      fToast.showToast(
        child: AppToast.toast("Copied FCM Token to clipboard!"),
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 2),
      );
    } else {
      fToast.showToast(
        child: AppToast.toast("Copied failed!"),
        gravity: ToastGravity.BOTTOM,
        toastDuration: const Duration(seconds: 2),
      );
    }
  }
}
