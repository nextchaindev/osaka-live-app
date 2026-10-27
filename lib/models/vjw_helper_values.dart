class VjwHelperValues {
  const VjwHelperValues({
    this.flightNumber = '',
    this.arrivalDate = '',
    this.stayName = '',
    this.stayPostalCode = '',
    this.stayPrefecture = '',
    this.stayCity = '',
    this.stayAddressLine = '',
    this.stayBuilding = '',
    this.stayPhone = '',
    this.contactPhone = '',
  });

  final String flightNumber;
  final String arrivalDate;
  final String stayName;
  final String stayPostalCode;
  final String stayPrefecture;
  final String stayCity;
  final String stayAddressLine;
  final String stayBuilding;
  final String stayPhone;
  final String contactPhone;

  static String normalizeFlightNumber(String value) =>
      value.replaceAll(RegExp(r'\s+'), '').toUpperCase().trim();

  static String normalizePostalCode(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 7) {
      return '${digits.substring(0, 3)}-${digits.substring(3)}';
    }
    return value.trim();
  }

  static String normalizePhone(String value) =>
      value.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^81'), '');

  factory VjwHelperValues.fromJson(Map<String, dynamic> json) =>
      VjwHelperValues(
        flightNumber:
            normalizeFlightNumber(json['flightNumber']?.toString() ?? ''),
        arrivalDate: json['arrivalDate']?.toString() ?? '',
        stayName: json['stayName']?.toString() ?? '',
        stayPostalCode:
            normalizePostalCode(json['stayPostalCode']?.toString() ?? ''),
        stayPrefecture: json['stayPrefecture']?.toString() ?? '',
        stayCity: json['stayCity']?.toString() ?? '',
        stayAddressLine: json['stayAddressLine']?.toString() ?? '',
        stayBuilding: json['stayBuilding']?.toString() ?? '',
        stayPhone: normalizePhone(json['stayPhone']?.toString() ?? ''),
        contactPhone: normalizePhone(json['contactPhone']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'flightNumber': flightNumber,
        'arrivalDate': arrivalDate,
        'stayName': stayName,
        'stayPostalCode': stayPostalCode,
        'stayPrefecture': stayPrefecture,
        'stayCity': stayCity,
        'stayAddressLine': stayAddressLine,
        'stayBuilding': stayBuilding,
        'stayPhone': stayPhone,
        'contactPhone': contactPhone,
      };

  VjwHelperValues copyWith({
    String? flightNumber,
    String? arrivalDate,
    String? stayName,
    String? stayPostalCode,
    String? stayPrefecture,
    String? stayCity,
    String? stayAddressLine,
    String? stayBuilding,
    String? stayPhone,
    String? contactPhone,
  }) =>
      VjwHelperValues(
        flightNumber: normalizeFlightNumber(flightNumber ?? this.flightNumber),
        arrivalDate: arrivalDate ?? this.arrivalDate,
        stayName: stayName ?? this.stayName,
        stayPostalCode:
            normalizePostalCode(stayPostalCode ?? this.stayPostalCode),
        stayPrefecture: stayPrefecture ?? this.stayPrefecture,
        stayCity: stayCity ?? this.stayCity,
        stayAddressLine: stayAddressLine ?? this.stayAddressLine,
        stayBuilding: stayBuilding ?? this.stayBuilding,
        stayPhone: normalizePhone(stayPhone ?? this.stayPhone),
        contactPhone: normalizePhone(contactPhone ?? this.contactPhone),
      );
}
