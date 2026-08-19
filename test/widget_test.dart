import 'package:droid_purifier/adb_service.dart';
import 'package:droid_purifier/package_policy.dart';
import 'package:flutter_test/flutter_test.dart';

const device = DeviceInfo(
  id: 'test',
  status: 'device',
  model: 'Test Phone',
  manufacturer: 'OnePlus',
  brand: 'OnePlus',
  deviceCodename: 'test',
  androidVersion: '15',
  sdkInt: 35,
  battery: '100%',
  setupComplete: true,
  buildFingerprint: 'oneplus/test/test:15/test',
  securityPatch: '2026-08-01',
  romName: 'OxygenOS',
);

PackageMetadata meta(String packageName, {bool system = true, bool launcher = false, bool privileged = false, bool deviceAdmin = false, String label = ''}) => PackageMetadata(
  packageName: packageName,
  label: label.isEmpty ? packageName : label,
  versionName: '1.0',
  versionCode: 1,
  sourceDir: system ? '/system/app/$packageName/base.apk' : '/data/app/$packageName/base.apk',
  installer: system ? '' : 'com.android.vending',
  uid: 10001,
  isSystem: system,
  isUpdatedSystem: false,
  enabled: true,
  hasLauncher: launcher,
  privileged: privileged,
  deviceAdmin: deviceAdmin,
  requestedPermissions: const {},
  servicePermissions: const {},
);

PackageInfo classify(String packageName, {bool system = true, bool launcher = false, bool privileged = false, bool apex = false, bool overlay = false, bool role = false, bool webView = false, bool setupComplete = true, String label = ''}) => PackagePolicy.classify(
  packageName,
  device: device,
  metadata: meta(packageName, system: system, launcher: launcher, privileged: privileged, label: label),
  isApex: apex,
  isOverlay: overlay,
  isCriticalRole: role,
  isCurrentWebView: webView,
  setupComplete: setupComplete,
);

void main() {
  group('Dynamic app detection', () {
    test('ordinary user apps are dynamically removable', () {
      final info = classify('com.example.futureapp', system: false, launcher: true, label: 'Future App');
      expect(info.safety, SafetyClass.removable);
      expect(info.category, AppCategory.userApp);
      expect(info.name, 'Future App');
    });
    test('unknown user-installed Google apps are dynamically removable', () {
      final info = classify('com.google.android.apps.future', system: false, launcher: true, label: 'Future Google App');
      expect(info.safety, SafetyClass.removable);
      expect(info.category, AppCategory.googleApp);
      expect(PackagePolicy.recommendedCandidate(info), isTrue);
    });
    test('unknown preloaded Google launcher apps can be detected as consumer apps', () {
      final info = classify('com.google.android.apps.future', system: true, launcher: true, label: 'Future Google App');
      expect(info.safety, SafetyClass.removable);
      expect(PackagePolicy.recommendedCandidate(info), isTrue);
    });
    test('unknown background Google system packages stay review', () {
      final info = classify('com.google.android.future.service', system: true, launcher: false);
      expect(info.safety, SafetyClass.review);
      expect(PackagePolicy.recommendedCandidate(info), isFalse);
    });
  });

  group('OEM detection', () {
    test('OnePlus namespace is identified dynamically', () {
      final info = classify('com.oneplus.example', system: true, launcher: true, label: 'OnePlus Example');
      expect(info.category, AppCategory.oemApp);
      expect(info.safety, SafetyClass.caution);
    });
    test('unknown OEM background service stays review', () {
      final info = classify('com.oplus.hidden.service', system: true);
      expect(info.category, AppCategory.oemApp);
      expect(info.safety, SafetyClass.review);
    });
  });

  group('Protection overrides', () {
    test('Android core is protected', () {
      expect(classify('android').safety, SafetyClass.protected);
      expect(classify('com.android.systemui').safety, SafetyClass.protected);
    });
    test('APEX and overlays are protected', () {
      expect(classify('com.google.android.future.module', apex: true).safety, SafetyClass.protected);
      expect(classify('com.oneplus.overlay.example', overlay: true).safety, SafetyClass.protected);
    });
    test('current critical roles override removable apps', () {
      expect(classify('com.android.chrome', role: true).safety, SafetyClass.protected);
      expect(classify('com.google.android.apps.future', system: false, launcher: true, role: true).safety, SafetyClass.protected);
    });
    test('current WebView is protected', () {
      expect(classify('com.google.android.webview', webView: true).safety, SafetyClass.protected);
    });
  });

  group('Google presets and data safety', () {
    test('Chrome is recommended when not a critical role', () {
      final info = classify('com.android.chrome', system: true, launcher: true, label: 'Chrome');
      expect(info.safety, SafetyClass.removable);
      expect(PackagePolicy.recommendedCandidate(info), isTrue);
    });
    test('Authenticator is removable but requires data warning', () {
      final info = classify('com.google.android.apps.authenticator2', system: false, launcher: true);
      expect(info.safety, SafetyClass.removable);
      expect(info.dataWarning, isNotNull);
      expect(PackagePolicy.recommendedCandidate(info), isFalse);
    });
    test('Full De-Google includes framework caution but not core', () {
      expect(PackagePolicy.fullCandidate(classify('com.google.android.gms')), isTrue);
      expect(PackagePolicy.fullCandidate(classify('com.google.android.gsf')), isTrue);
      expect(PackagePolicy.fullCandidate(classify('com.google.android.permissioncontroller')), isFalse);
    });
  });
}
