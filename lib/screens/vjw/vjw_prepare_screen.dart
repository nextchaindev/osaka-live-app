import 'package:flutter/material.dart';
import 'package:osaka_app/l10n/generated/app_localizations.dart';
import 'package:osaka_app/constants/vjw_prefectures.dart';
import 'package:osaka_app/models/vjw_helper_values.dart';
import 'package:osaka_app/repositories/vjw_helper_repository.dart';
import 'package:osaka_app/screens/vjw/vjw_webview_screen.dart';
import 'package:osaka_app/services/analytics/analytics_service.dart';

class VjwPrepareScreen extends StatefulWidget {
  const VjwPrepareScreen({this.prefill, this.initialValues, super.key});
  final Map<String, dynamic>? prefill;
  final VjwHelperValues? initialValues;

  static Route<void> route({Map<String, dynamic>? prefill}) {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          VjwPrepareScreen(prefill: prefill),
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final eased = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0.2, end: 1.0).animate(eased),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1.0).animate(eased),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.18, 0),
                end: Offset.zero,
              ).animate(eased),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  State<VjwPrepareScreen> createState() => _VjwPrepareScreenState();
}

class _VjwPrepareScreenState extends State<VjwPrepareScreen> {
  final _repository = VjwHelperRepository();
  final _analytics = AnalyticsService();
  VjwHelperValues _values = const VjwHelperValues();
  final _controllers = <String, TextEditingController>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialValues != null) _values = widget.initialValues!;
    _syncControllers();
    _load();
  }

  Future<void> _load() async {
    try {
      var values = widget.initialValues ?? await _repository.load();
      if (values.toJson().values.every((value) => value.toString().isEmpty) &&
          widget.prefill != null) {
        values = values.copyWith(
            stayName: widget.prefill!['stayName']?.toString(),
            stayAddressLine: widget.prefill!['stayAddress']?.toString(),
            stayPhone: widget.prefill!['stayPhone']?.toString());
      }
      if (!mounted) return;
      setState(() {
        _values = values;
        _syncControllers();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncControllers() {
    for (final entry in _values.toJson().entries) {
      _controllers
          .putIfAbsent(entry.key,
              () => TextEditingController(text: entry.value.toString()))
          .text = entry.value.toString();
    }
  }

  Future<void> _save() async {
    final v = _values.copyWith(
      flightNumber: _controllers['flightNumber']?.text,
      arrivalDate: _controllers['arrivalDate']?.text,
      stayName: _controllers['stayName']?.text,
      stayPostalCode: _controllers['stayPostalCode']?.text,
      stayPrefecture: _controllers['stayPrefecture']?.text,
      stayCity: _controllers['stayCity']?.text,
      stayAddressLine: _controllers['stayAddressLine']?.text,
      stayBuilding: _controllers['stayBuilding']?.text,
      stayPhone: _controllers['stayPhone']?.text,
      contactPhone: _controllers['contactPhone']?.text,
    );
    await _repository.save(v);
    if (!mounted) return;
    setState(() => _values = v);
    await _analytics.logEvent(name: 'vjw_values_saved');
  }

  Future<void> _clearAll() async {
    await _repository.clear();
    await _analytics.logEvent(name: 'vjw_values_cleared');
    if (!mounted) return;
    setState(() {
      _values = const VjwHelperValues();
      _syncControllers();
    });
  }

  Route<void> _buildVjwRoute() {
    return PageRouteBuilder<void>(
      pageBuilder: (context, animation, secondaryAnimation) =>
          VjwWebViewScreen(values: _values),
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final eased = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: Tween<double>(begin: 0.2, end: 1.0).animate(eased),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1.0).animate(eased),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.18, 0),
                end: Offset.zero,
              ).animate(eased),
              child: child,
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(String key, String label, {TextInputType? keyboardType}) =>
      TextField(
          controller: _controllers[key],
          keyboardType: keyboardType,
          style: const TextStyle(
              color: Color(0xff17231f),
              fontSize: 15,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(
                  color: Color(0xff7b827d),
                  fontSize: 13,
                  fontWeight: FontWeight.w500),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      const BorderSide(color: Color(0xffd66a3d), width: 1.5))));

  Widget _prefectureField(BuildContext context, String label) {
    final locale = Localizations.localeOf(context).languageCode;
    String name(VjwPrefecture option) => switch (locale) {
          'ko' => option.ko,
          'ja' => option.ja,
          _ => option.en,
        };
    final selected = vjwPrefectures
        .where((option) =>
            option.en == _controllers['stayPrefecture']?.text ||
            option.ko == _controllers['stayPrefecture']?.text ||
            option.ja == _controllers['stayPrefecture']?.text)
        .firstOrNull;
    return DropdownButtonFormField<String>(
      initialValue: selected == null ? null : name(selected),
      decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: Color(0xff7b827d),
              fontSize: 13,
              fontWeight: FontWeight.w500),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none)),
      items: vjwPrefectures
          .map((option) =>
              DropdownMenuItem(value: name(option), child: Text(name(option))))
          .toList(),
      onChanged: (value) {
        if (value != null) _controllers['stayPrefecture']?.text = value;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xfff4efe6),
      appBar: AppBar(
          backgroundColor: const Color(0xfff4efe6),
          surfaceTintColor: Colors.transparent,
          title: Text(s.vjwPrepareTitle,
              style: const TextStyle(
                  color: Color(0xff17231f), fontWeight: FontWeight.w800))),
      body: _isLoading
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(
                  color: Color(0xffd66a3d), strokeWidth: 2.5),
              const SizedBox(height: 14),
              Text(s.vjwLoading,
                  style: const TextStyle(
                      color: Color(0xff68716b),
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ]))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                        color: const Color(0xff17231f),
                        borderRadius: BorderRadius.circular(22)),
                    child: Text(s.vjwPrivacyNotice,
                        style: const TextStyle(
                            color: Color(0xfff4efe6),
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle(
                      s.vjwFlightSection, Icons.flight_takeoff_rounded),
                  _field('flightNumber', s.vjwFlightNumber),
                  const SizedBox(height: 9),
                  _field('arrivalDate', s.vjwArrivalDate,
                      keyboardType: TextInputType.datetime),
                  const SizedBox(height: 22),
                  _sectionTitle(s.vjwStaySection, Icons.hotel_rounded),
                  _field('stayName', s.vjwStayName),
                  const SizedBox(height: 9),
                  _field('stayPostalCode', s.vjwPostalCode,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 9),
                  _prefectureField(context, s.vjwPrefecture),
                  const SizedBox(height: 9),
                  _field('stayCity', s.vjwCity),
                  const SizedBox(height: 9),
                  _field('stayAddressLine', s.vjwAddress),
                  const SizedBox(height: 9),
                  _field('stayBuilding', s.vjwBuilding),
                  const SizedBox(height: 9),
                  _field('stayPhone', s.vjwStayPhone,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 22),
                  _sectionTitle(s.vjwContactSection, Icons.phone_rounded),
                  _field('contactPhone', s.vjwContactPhone,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 24),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xffd66a3d),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16))),
                      onPressed: () async {
                        await _save();
                        if (!context.mounted) return;
                        Navigator.of(context).push(_buildVjwRoute());
                      },
                      child: Text(s.vjwOpen,
                          style: const TextStyle(fontWeight: FontWeight.w800))),
                  const SizedBox(height: 6),
                  TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xff9b4b32)),
                      onPressed: _clearAll,
                      child: Text(s.vjwDeleteAll)),
                ]),
    );
  }

  Widget _sectionTitle(String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icon, color: const Color(0xffd66a3d), size: 19),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  color: Color(0xff17231f),
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
        ]),
      );
}
