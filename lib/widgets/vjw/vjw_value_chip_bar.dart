import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:osaka_app/constants/javascript.dart';
import 'package:osaka_app/l10n/generated/app_localizations.dart';
import 'package:osaka_app/models/vjw_helper_values.dart';
import 'package:osaka_app/services/analytics/analytics_service.dart';

class VjwValueChipBar extends StatelessWidget {
  const VjwValueChipBar(
      {required this.values, required this.controller, super.key});
  final VjwHelperValues values;
  final InAppWebViewController? controller;
  static final _analytics = AnalyticsService();

  void _showToast(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 78),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          elevation: 0,
          duration: const Duration(seconds: 2),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xff172d9d),
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(message,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final items = <(String, String)>[
      (strings.vjwFlightNumber, values.flightNumber),
      (strings.vjwArrivalDate, values.arrivalDate),
      (strings.vjwStayName, values.stayName),
      (strings.vjwPostalCode, values.stayPostalCode),
      (strings.vjwPrefecture, values.stayPrefecture),
      (strings.vjwCity, values.stayCity),
      (strings.vjwAddress, values.stayAddressLine),
      (strings.vjwBuilding, values.stayBuilding),
      (strings.vjwStayPhone, values.stayPhone),
      (strings.vjwContactPhone, values.contactPhone),
    ].where((item) => item.$2.trim().isNotEmpty).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Material(
          color: Colors.transparent,
          elevation: 10,
          shadowColor: const Color.fromRGBO(23, 35, 31, 0.25),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Container(
            color: Colors.white,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromRGBO(226, 232, 255, 0.97),
                    Color.fromRGBO(184, 199, 255, 0.92),
                  ],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(
                  top: BorderSide(color: Color(0xff081dc9), width: 2.5),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                  child: Row(
                    children: items
                        .map((item) => Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: GestureDetector(
                                onLongPress: () async {
                                  await Clipboard.setData(
                                      ClipboardData(text: item.$2));
                                  if (context.mounted) {
                                    _showToast(context, strings.vjwCopied);
                                  }
                                },
                                child: ActionChip(
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                      color: Color(0xffb8c7ff), width: 1),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13)),
                                  label: Text(
                                    '${item.$1}  ${item.$2}',
                                    style: const TextStyle(
                                        color: Color(0xff172d9d),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  onPressed: () async {
                                    String code;
                                    try {
                                      final result =
                                          await controller?.evaluateJavascript(
                                              source:
                                                  injectValueIntoActiveElement(
                                                      item.$2));
                                      code = result
                                              ?.toString()
                                              .replaceAll('"', '') ??
                                          'no_focus';
                                    } on Exception {
                                      code = 'injection_failed';
                                    }
                                    final shouldCopyFallback = {
                                      'injection_failed',
                                      'unknown',
                                      'select_unsupported',
                                      'unsupported_type',
                                    }.contains(code);
                                    if (shouldCopyFallback) {
                                      await Clipboard.setData(
                                          ClipboardData(text: item.$2));
                                    }
                                    await _analytics.logEvent(
                                        name: 'vjw_chip_inject',
                                        parameters: {'result': code});
                                    if (!context.mounted) return;
                                    final message = code == 'ok'
                                        ? strings.vjwInjected
                                        : shouldCopyFallback
                                            ? strings.vjwCopied
                                            : switch (code) {
                                                'select_unsupported' =>
                                                  strings.vjwSelectUnsupported,
                                                'unsupported_type' =>
                                                  strings.vjwUnsupportedType,
                                                'no_focus' =>
                                                  strings.vjwNoFocus,
                                                _ => strings.vjwCopied,
                                              };
                                    _showToast(context, message);
                                  },
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
