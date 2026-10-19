import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:osaka_app/provider/download_provider.dart';
import 'package:osaka_app/provider/app_global_key.dart';
import 'package:osaka_app/l10n/generated/app_localizations.dart';

/// Widget that listens to DownloadProvider and shows snackbars
/// Should be placed at the root of the widget tree
class DownloadSnackBar extends StatefulWidget {
  final Widget child;

  const DownloadSnackBar({
    super.key,
    required this.child,
  });

  @override
  State<DownloadSnackBar> createState() => _DownloadSnackBarState();
}

class _DownloadSnackBarState extends State<DownloadSnackBar> {
  DownloadStatus? _lastShownStatus;

  Widget _buildModernSnackBar({
    required BuildContext context,
    required Widget content,
    required Color backgroundColor,
    required Color iconColor,
    IconData? icon,
    Widget? customIcon,
  }) {
    // Create gradient colors with accent
    final baseColor = backgroundColor;
    final accentColor = Color.lerp(
      baseColor,
      iconColor,
      0.08,
    )!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            baseColor.withValues(alpha: 0.95),
            accentColor.withValues(alpha: 0.90),
            baseColor.withValues(alpha: 0.85),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: iconColor.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 2),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null || customIcon != null)
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: customIcon ??
                    Icon(
                      icon,
                      color: iconColor,
                      size: 20,
                    ),
              ),
            ),
          if (icon != null || customIcon != null) const SizedBox(width: 12),
          Expanded(child: content),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, provider, child) {
        final strings = AppLocalizations.of(context)!;
        // Get context from navigatorKey to ensure ScaffoldMessenger is available
        final scaffoldContext = navigatorKey.currentContext ?? context;

        // Show downloading snackbar
        if (provider.isDownloading &&
            provider.fileName != null &&
            _lastShownStatus != DownloadStatus.downloading) {
          _lastShownStatus = DownloadStatus.downloading;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(scaffoldContext).clearSnackBars();
            ScaffoldMessenger.of(scaffoldContext).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 30),
                backgroundColor: Colors.transparent,
                elevation: 0,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                padding: EdgeInsets.zero,
                content: _buildModernSnackBar(
                  context: scaffoldContext,
                  backgroundColor: const Color(0xFF1E1E1E),
                  iconColor: const Color(0xFF4A90E2),
                  customIcon: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.downloading,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.fileName!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4A90E2)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              provider.progress,
                              style: TextStyle(
                                color: const Color(0xFF4A90E2),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          });
        }

        // Show success snackbar
        if (provider.hasSuccess &&
            provider.fileName != null &&
            _lastShownStatus != DownloadStatus.success) {
          _lastShownStatus = DownloadStatus.success;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(scaffoldContext).clearSnackBars();
            ScaffoldMessenger.of(scaffoldContext).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 4),
                backgroundColor: Colors.transparent,
                elevation: 0,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                padding: EdgeInsets.zero,
                content: _buildModernSnackBar(
                  context: scaffoldContext,
                  backgroundColor: const Color(0xFF1E1E1E),
                  iconColor: const Color(0xFF4CAF50),
                  icon: Icons.check_circle_rounded,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.downloadComplete,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              provider.fileName!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () async {
                              await provider.openFile();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.open_in_new,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    strings.open,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
            // Clear state after showing success
            Future.delayed(const Duration(seconds: 4), () {
              provider.clearState();
              _lastShownStatus = null;
            });
          });
        }

        // Show error snackbar
        if (provider.hasError &&
            provider.fileName != null &&
            _lastShownStatus != DownloadStatus.error) {
          _lastShownStatus = DownloadStatus.error;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(scaffoldContext).clearSnackBars();
            ScaffoldMessenger.of(scaffoldContext).showSnackBar(
              SnackBar(
                duration: const Duration(seconds: 4),
                backgroundColor: Colors.transparent,
                elevation: 0,
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.all(16),
                padding: EdgeInsets.zero,
                content: _buildModernSnackBar(
                  context: scaffoldContext,
                  backgroundColor: const Color(0xFF1E1E1E),
                  iconColor: const Color(0xFFEF5350),
                  icon: Icons.error_rounded,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        strings.downloadFailed,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        provider.fileName!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (provider.hasError) ...[
                        const SizedBox(height: 2),
                        Text(
                          strings.downloadFailedDetail,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
            // Clear state after showing error
            Future.delayed(const Duration(seconds: 4), () {
              provider.clearState();
              _lastShownStatus = null;
            });
          });
        }

        // Reset tracking when status changes to idle
        if (provider.status == DownloadStatus.idle) {
          _lastShownStatus = null;
        }

        return widget.child;
      },
      child: widget.child,
    );
  }
}
