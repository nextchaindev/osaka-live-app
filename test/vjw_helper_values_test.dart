import 'package:flutter_test/flutter_test.dart';
import 'package:osaka_app/models/vjw_helper_values.dart';

void main() {
  test('normalizes flight, postal code, and phone values', () {
    final values = VjwHelperValues.fromJson({
      'flightNumber': ' ke 723 ',
      'stayPostalCode': '5560017',
      'stayPhone': '+81 06-6645-1111',
    });

    expect(values.flightNumber, 'KE723');
    expect(values.stayPostalCode, '556-0017');
    expect(values.stayPhone, '0666451111');
  });

  test('serializes and copies values without passport fields', () {
    const values = VjwHelperValues(stayName: 'Hotel', contactPhone: '01012345678');
    expect(VjwHelperValues.fromJson(values.toJson()).stayName, 'Hotel');
    expect(values.copyWith(stayName: 'New hotel').stayName, 'New hotel');
    expect(values.toJson().containsKey('passportNumber'), isFalse);
  });
}
