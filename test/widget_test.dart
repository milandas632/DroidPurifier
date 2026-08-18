import 'package:droid_purifier/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core Android packages are protected', () {
    expect(RiskDatabase.isProtected('com.android.systemui'), isTrue);
    expect(RiskDatabase.isProtected('com.android.settings'), isTrue);
  });

  test('Google preset excludes critical Google infrastructure', () {
    expect(PresetDatabase.googleConsumer.contains('com.google.android.gms'), isFalse);
    expect(PresetDatabase.googleConsumer.contains('com.google.android.gsf'), isFalse);
    expect(PresetDatabase.googleConsumer.contains('com.android.vending'), isFalse);
  });
}
