import 'package:droid_purifier/package_policy.dart';
import 'package:flutter_test/flutter_test.dart';

PackageInfo classify(
  String packageName, {
  bool system = true,
  bool apex = false,
  bool overlay = false,
  bool role = false,
  bool webView = false,
  bool setupComplete = true,
}) {
  return PackagePolicy.classify(
    packageName,
    isSystem: system,
    isApex: apex,
    isOverlay: overlay,
    isCriticalRole: role,
    isCurrentWebView: webView,
    setupComplete: setupComplete,
  );
}

void main() {
  group('Fail-safe classification', () {
    test('Android framework is protected', () {
      expect(classify('android').safety, SafetyClass.protected);
      expect(classify('com.android.systemui').safety, SafetyClass.protected);
      expect(classify('com.android.settings').safety, SafetyClass.protected);
    });

    test('unknown Android and OEM system packages are never called removable', () {
      expect(classify('android.some.future.component').safety, SafetyClass.unknown);
      expect(classify('com.android.some.future.component').safety, SafetyClass.unknown);
      expect(classify('com.vendor.hidden.framework').safety, SafetyClass.unknown);
      expect(
        PackagePolicy.knownRemovableCandidate(
          classify('com.vendor.hidden.framework'),
        ),
        isFalse,
      );
    });

    test('unknown Google packages fail safe', () {
      final info = classify('com.google.android.some.future.service');
      expect(info.safety, SafetyClass.unknown);
      expect(info.autoSelect, isFalse);
      expect(info.deGoogleTier, DeGoogleTier.manual);
    });
  });

  group('Dynamic device protection', () {
    test('APEX packages are protected even if unknown', () {
      expect(
        classify('com.google.android.future.module', apex: true).safety,
        SafetyClass.protected,
      );
    });

    test('runtime overlays are protected even if unknown', () {
      expect(
        classify('android.miui.overlay', overlay: true).safety,
        SafetyClass.protected,
      );
    });

    test('current device roles override a removable rule', () {
      expect(
        classify('com.google.android.inputmethod.latin', role: true).safety,
        SafetyClass.protected,
      );
      expect(
        classify('com.google.android.apps.nexuslauncher', role: true).safety,
        SafetyClass.protected,
      );
    });

    test('current WebView provider is protected', () {
      expect(
        classify('com.google.android.webview', webView: true).safety,
        SafetyClass.protected,
      );
    });

    test('setup wizard is protected until provisioning finishes', () {
      expect(
        classify(
          'com.google.android.setupwizard',
          setupComplete: false,
        ).safety,
        SafetyClass.protected,
      );
      expect(
        classify(
          'com.google.android.setupwizard',
          setupComplete: true,
        ).safety,
        SafetyClass.featureDependent,
      );
    });
  });

  group('De-Google presets', () {
    test('recommended only auto-selects explicitly known removable Google apps', () {
      expect(
        PackagePolicy.recommendedCandidate(
          classify('com.google.android.youtube'),
        ),
        isTrue,
      );
      expect(
        PackagePolicy.recommendedCandidate(
          classify('com.google.android.gm'),
        ),
        isTrue,
      );
      expect(
        PackagePolicy.recommendedCandidate(
          classify('com.google.android.gms'),
        ),
        isFalse,
      );
    });

    test('full includes Google framework but never protected Android core', () {
      expect(
        PackagePolicy.fullCandidate(classify('com.google.android.gms')),
        isTrue,
      );
      expect(
        PackagePolicy.fullCandidate(classify('com.google.android.gsf')),
        isTrue,
      );
      expect(
        PackagePolicy.fullCandidate(classify('com.android.vending')),
        isTrue,
      );
      expect(
        PackagePolicy.fullCandidate(
          classify('com.google.android.permissioncontroller'),
        ),
        isFalse,
      );
      expect(
        PackagePolicy.fullCandidate(
          classify('com.google.android.documentsui'),
        ),
        isFalse,
      );
    });

    test('role-sensitive apps remain manual by default', () {
      expect(
        PackagePolicy.fullCandidate(
          classify('com.google.android.inputmethod.latin'),
        ),
        isFalse,
      );
      expect(
        PackagePolicy.fullCandidate(
          classify('com.google.android.dialer'),
        ),
        isFalse,
      );
      expect(
        PackagePolicy.fullCandidate(
          classify('com.google.android.apps.messaging'),
        ),
        isFalse,
      );
    });
  });
}
