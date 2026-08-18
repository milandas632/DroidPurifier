import 'package:droid_purifier/package_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android core protection', () {
    test('protects classic Android packages', () {
      expect(RiskDatabase.isProtected('com.android.systemui'), isTrue);
      expect(RiskDatabase.isProtected('com.android.settings'), isTrue);
      expect(RiskDatabase.isProtected('com.android.packageinstaller'), isTrue);
    });

    test('protects Google-build Android 10 core modules', () {
      expect(
        RiskDatabase.isProtected(
          'com.google.android.permissioncontroller',
          sdkInt: 29,
        ),
        isTrue,
      );
      expect(
        RiskDatabase.isProtected('com.google.android.documentsui', sdkInt: 29),
        isTrue,
      );
      expect(
        RiskDatabase.isProtected('com.google.android.ext.services', sdkInt: 29),
        isTrue,
      );
      expect(
        RiskDatabase.isProtected('com.google.android.modulemetadata', sdkInt: 29),
        isTrue,
      );
    });

    test('protects modern Mainline aliases and future APEX packages', () {
      expect(
        RiskDatabase.isProtected('com.google.android.permission', sdkInt: 34),
        isTrue,
      );
      expect(
        RiskDatabase.isProtected('com.google.android.conscrypt', sdkInt: 34),
        isTrue,
      );
      expect(
        RiskDatabase.isProtected('com.google.android.resolv', sdkInt: 34),
        isTrue,
      );
      expect(
        RiskDatabase.isProtected(
          'com.google.android.future.module',
          sdkInt: 36,
          isApex: true,
        ),
        isTrue,
      );
    });

    test('protects Google Android overlays', () {
      expect(
        RiskDatabase.isProtected(
          'com.google.android.overlay.modules.permissioncontroller',
          sdkInt: 29,
        ),
        isTrue,
      );
      expect(
        RiskDatabase.isProtected(
          'com.google.android.overlay.modules.ext.services',
          sdkInt: 29,
        ),
        isTrue,
      );
    });

    test('protects WebView by default', () {
      expect(
        RiskDatabase.isProtected('com.google.android.webview', sdkInt: 29),
        isTrue,
      );
    });
  });

  group('De-Google presets', () {
    test('recommended preset removes ordinary Google apps but keeps framework', () {
      expect(RiskDatabase.isRecommendedDeGoogle('com.google.android.gm'), isTrue);
      expect(
        RiskDatabase.isRecommendedDeGoogle('com.google.android.youtube'),
        isTrue,
      );
      expect(
        RiskDatabase.isRecommendedDeGoogle('com.google.android.gms'),
        isFalse,
      );
      expect(
        RiskDatabase.isRecommendedDeGoogle('com.google.android.gsf'),
        isFalse,
      );
      expect(
        RiskDatabase.isRecommendedDeGoogle('com.android.vending'),
        isFalse,
      );
    });

    test('full preset includes Google framework but never Android core', () {
      expect(RiskDatabase.isFullDeGoogle('com.google.android.gms'), isTrue);
      expect(RiskDatabase.isFullDeGoogle('com.google.android.gsf'), isTrue);
      expect(RiskDatabase.isFullDeGoogle('com.android.vending'), isTrue);
      expect(
        RiskDatabase.isFullDeGoogle('com.google.android.permissioncontroller'),
        isFalse,
      );
      expect(
        RiskDatabase.isFullDeGoogle('com.google.android.documentsui'),
        isFalse,
      );
    });

    test('supports legacy Google packages on older Android', () {
      expect(
        RiskDatabase.isFullDeGoogle('com.google.android.gsf.login', sdkInt: 23),
        isTrue,
      );
      expect(
        RiskDatabase.isFullDeGoogle(
          'com.google.android.backuptransport',
          sdkInt: 23,
        ),
        isTrue,
      );
      expect(
        RiskDatabase.isRecommendedDeGoogle('com.google.android.music', sdkInt: 23),
        isTrue,
      );
    });

    test('does not auto-select role apps requiring replacements', () {
      expect(RiskDatabase.isFullDeGoogle('com.google.android.inputmethod.latin'), isFalse);
      expect(RiskDatabase.isFullDeGoogle('com.google.android.dialer'), isFalse);
      expect(RiskDatabase.isFullDeGoogle('com.google.android.apps.messaging'), isFalse);
      expect(RiskDatabase.isFullDeGoogle('com.google.android.GoogleCamera'), isFalse);
    });

    test('unknown future Google packages fail safe', () {
      final info = RiskDatabase.get('com.google.android.some.future.service', sdkInt: 36);
      expect(info.level, RiskLevel.high);
      expect(info.autoSelect, isFalse);
      expect(info.deGoogleTier, DeGoogleTier.manual);
    });

    test('setup wizard is locked until provisioning completes', () {
      expect(
        RiskDatabase.isProtected(
          'com.google.android.setupwizard',
          sdkInt: 29,
          setupComplete: false,
        ),
        isTrue,
      );
      expect(
        RiskDatabase.isFullDeGoogle(
          'com.google.android.setupwizard',
          sdkInt: 29,
          setupComplete: true,
        ),
        isTrue,
      );
    });
  });
}
