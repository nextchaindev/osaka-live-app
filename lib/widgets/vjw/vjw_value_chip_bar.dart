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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(strings.vjwCopied)));
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
                                    if (code == 'injection_failed' ||
                                        code == 'unknown') {
                                      await Clipboard.setData(
                                          ClipboardData(text: item.$2));
                                    }
                                    await _analytics.logEvent(
                                        name: 'vjw_chip_inject',
                                        parameters: {'result': code});
                                    if (context.mounted && code != 'ok') {
                                      final message = switch (code) {
                                        'select_unsupported' =>
                                          strings.vjwSelectUnsupported,
                                        'unsupported_type' =>
                                          strings.vjwUnsupportedType,
                                        'no_focus' => strings.vjwNoFocus,
                                        _ => strings.vjwCopied,
                                      };
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                              SnackBar(content: Text(message)));
                                    }
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
