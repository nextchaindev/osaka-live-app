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
  bool _isEditing = true;

  bool _hasSavedValues(VjwHelperValues values) =>
      values.toJson().values.any((value) => value.toString().trim().isNotEmpty);

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
      final hasStoredValues = _hasSavedValues(values);
      if (!hasStoredValues && widget.prefill != null) {
        values = values.copyWith(
            stayName: widget.prefill!['stayName']?.toString(),
            stayAddressLine: widget.prefill!['stayAddress']?.toString(),
            stayPhone: widget.prefill!['stayPhone']?.toString());
      }
      if (!mounted) return;
      setState(() {
        _values = values;
        _isEditing = !hasStoredValues;
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
    setState(() {
      _values = v;
      _isEditing = false;
    });
    await _analytics.logEvent(name: 'vjw_values_saved');
  }

  Future<void> _clearAll() async {
    await _repository.clear();
    await _analytics.logEvent(name: 'vjw_values_cleared');
    if (!mounted) return;
    setState(() {
      _values = const VjwHelperValues();
      _isEditing = true;
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

  Future<void> _pickArrivalDate() async {
    final controller = _controllers['arrivalDate'];
    final today = DateTime.now();
    final lastDate = DateTime(today.year + 3, 12, 31);
    final parsed = DateTime.tryParse(controller?.text ?? '');
    final initialDate = parsed == null ||
            parsed.isBefore(DateTime(2020)) ||
            parsed.isAfter(lastDate)
        ? today
        : parsed;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: lastDate,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xffd66a3d),
            onPrimary: Colors.white,
            surface: Color(0xfff4efe6),
            onSurface: Color(0xff17231f),
          ),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    controller?.text = '${picked.year.toString().padLeft(4, '0')}-'
        '${picked.month.toString().padLeft(2, '0')}-'
        '${picked.day.toString().padLeft(2, '0')}';
    setState(() {});
  }

  Widget _field(String key, String label,
          {TextInputType? keyboardType,
          bool readOnly = false,
          VoidCallback? onTap,
          Widget? suffixIcon}) =>
      TextField(
          controller: _controllers[key],
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
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
                      const BorderSide(color: Color(0xffd66a3d), width: 1.5)),
              suffixIcon: suffixIcon));

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
                        color: const Color(0xfffff7e0),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xffffd98a))),
                    child: Text(s.vjwPrivacyNotice,
                        style: const TextStyle(
                            color: Color(0xff79501b),
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w600)),
                  ),
                  _vjwBrandBanner(),
                  if (_isEditing || !_hasSavedValues(_values)) ...[
                    _sectionTitle(
                        s.vjwFlightSection, Icons.flight_takeoff_rounded),
                    _field('flightNumber', s.vjwFlightNumber),
                    const SizedBox(height: 9),
                    _field('arrivalDate', s.vjwArrivalDate,
                        readOnly: true,
                        onTap: _pickArrivalDate,
                        suffixIcon: const Icon(Icons.calendar_month_rounded,
                            color: Color(0xffd66a3d))),
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
                  ] else ...[
                    _buildSummary(s),
                    const SizedBox(height: 18),
                    OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xff9b4b32),
                          side: const BorderSide(color: Color(0xffd66a3d)),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => setState(() => _isEditing = true),
                        icon: const Icon(Icons.edit_rounded),
                        label: Text(s.vjwEdit)),
                    const SizedBox(height: 16),
                  ],
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

  Widget _buildSummary(AppLocalizations s) {
    final entries = <(String, String)>[
      (s.vjwFlightNumber, _values.flightNumber),
      (s.vjwArrivalDate, _values.arrivalDate),
      (s.vjwStayName, _values.stayName),
      (s.vjwPostalCode, _values.stayPostalCode),
      (s.vjwPrefecture, _values.stayPrefecture),
      (s.vjwCity, _values.stayCity),
      (s.vjwAddress, _values.stayAddressLine),
      (s.vjwBuilding, _values.stayBuilding),
      (s.vjwStayPhone, _values.stayPhone),
      (s.vjwContactPhone, _values.contactPhone),
    ].where((entry) => entry.$2.trim().isNotEmpty).toList();

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: entries
              .map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: Text(entry.$1,
                                style: const TextStyle(
                                    color: Color(0xff7b827d), fontSize: 13))),
                        const SizedBox(width: 16),
                        Flexible(
                            child: Text(entry.$2,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                    color: Color(0xff17231f),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  Widget _vjwBrandBanner() => Image.asset(
        'assets/images/vjw_prepare_banner_transparent.png',
        width: double.infinity,
        height: 112,
        fit: BoxFit.cover,
      );
}
