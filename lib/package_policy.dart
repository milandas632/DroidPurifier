import 'adb_service.dart';

enum SafetyClass { removable, caution, review, protected }

enum AppCategory { userApp, googleApp, oemApp, carrierApp, system, unknownVendor }

enum DeGoogleTier { none, recommended, full, manual, core }

class PackageInfo {
  const PackageInfo({
    required this.name,
    required this.category,
    required this.safety,
    required this.note,
    this.deGoogleTier = DeGoogleTier.none,
    this.autoSelect = false,
    this.dataWarning,
    this.confidence = 'medium',
  });

  final String name;
  final AppCategory category;
  final SafetyClass safety;
  final String note;
  final DeGoogleTier deGoogleTier;
  final bool autoSelect;
  final String? dataWarning;
  final String confidence;

  bool get protected => safety == SafetyClass.protected;
  bool get removable => safety == SafetyClass.removable;
}

class _Rule {
  const _Rule(
    this.name,
    this.safety,
    this.note, {
    this.category,
    this.deGoogleTier = DeGoogleTier.none,
    this.autoSelect = false,
    this.dataWarning,
  });
  final String name;
  final SafetyClass safety;
  final String note;
  final AppCategory? category;
  final DeGoogleTier deGoogleTier;
  final bool autoSelect;
  final String? dataWarning;
}

class PackagePolicy {
  static const Set<String> _coreAndroid = {
    'android',
    'com.android.systemui',
    'com.android.settings',
    'com.android.phone',
    'com.android.providers.settings',
    'com.android.packageinstaller',
    'com.google.android.packageinstaller',
    'com.android.permissioncontroller',
    'com.google.android.permissioncontroller',
    'com.google.android.permission',
    'com.android.documentsui',
    'com.google.android.documentsui',
    'com.android.ext.services',
    'com.google.android.ext.services',
    'com.android.ext.shared',
    'com.google.android.ext.shared',
    'com.android.modulemetadata',
    'com.google.android.modulemetadata',
    'com.android.networkstack',
    'com.google.android.networkstack',
    'com.android.networkstack.permissionconfig',
    'com.google.android.networkstack.permissionconfig',
    'com.android.captiveportallogin',
    'com.google.android.captiveportallogin',
    'com.android.webview',
    'com.google.android.webview',
    'com.google.android.conscrypt',
    'com.google.android.resolv',
    'com.google.android.cellbroadcast',
    'com.google.android.tzdata2',
    'com.google.android.media',
    'com.google.android.media.swcodec',
    'com.google.android.mediaprovider',
    'com.google.android.sdkext',
    'com.google.android.os.statsd',
    'com.google.android.tethering',
    'com.google.android.wifi',
    'com.google.android.ipsec',
    'com.google.android.neuralnetworks',
    'com.google.android.art',
    'com.google.android.adbd',
  };

  static const Map<String, _Rule> _known = {
    'com.google.android.youtube': _Rule('YouTube', SafetyClass.removable, 'Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.gm': _Rule('Gmail', SafetyClass.removable, 'Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.docs': _Rule('Google Drive', SafetyClass.removable, 'Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.photos': _Rule('Google Photos', SafetyClass.removable, 'Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.maps': _Rule('Google Maps', SafetyClass.removable, 'Navigation app. Keep another maps app if needed.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.tachyon': _Rule('Google Meet', SafetyClass.removable, 'Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.podcasts': _Rule('Google Podcasts', SafetyClass.removable, 'Legacy Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.videos': _Rule('Google TV', SafetyClass.removable, 'Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.music': _Rule('Google Play Music', SafetyClass.removable, 'Legacy Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.ar.lens': _Rule('Google Lens', SafetyClass.removable, 'Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.translate': _Rule('Google Translate', SafetyClass.removable, 'Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.chromecast.app': _Rule('Google Home', SafetyClass.removable, 'Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.subscriptions.red': _Rule('Google One', SafetyClass.removable, 'Google consumer app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.walletnfcrel': _Rule('Google Wallet', SafetyClass.caution, 'Wallet/payment app. Review local cards and passes before removal.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.manual, dataWarning: 'Check cards, passes and locally stored wallet data before removal.'),
    'com.google.android.apps.authenticator2': _Rule('Google Authenticator', SafetyClass.removable, 'Authenticator app; Android itself does not depend on it.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.manual, dataWarning: 'Export or migrate your 2FA accounts before removal.'),
    'com.android.chrome': _Rule('Google Chrome', SafetyClass.removable, 'Google browser app.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.googlequicksearchbox': _Rule('Google App / Assistant', SafetyClass.caution, 'Removing it disables Google Search/Assistant integration.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.feedback': _Rule('Google Feedback', SafetyClass.removable, 'Google feedback/reporting component.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.gms': _Rule('Google Play Services', SafetyClass.caution, 'Many third-party apps depend on Google APIs, FCM or Play Integrity.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.gsf': _Rule('Google Services Framework', SafetyClass.caution, 'Google account/service framework. Google-dependent apps may fail.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.gsf.login': _Rule('Google Account Manager', SafetyClass.caution, 'Google account sign-in component.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.android.vending': _Rule('Google Play Store', SafetyClass.caution, 'Install another trusted app source before removing if desired.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.apps.restore': _Rule('Google Restore', SafetyClass.caution, 'Google device restore functionality.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.backuptransport': _Rule('Google Backup Transport', SafetyClass.caution, 'Google cloud backup transport.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.apps.turbo': _Rule('Device Health Services', SafetyClass.caution, 'Google battery/device-health prediction features.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.partnersetup': _Rule('Google Partner Setup', SafetyClass.caution, 'Google partner/setup integration.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.onetimeinitializer': _Rule('Google One-Time Initializer', SafetyClass.caution, 'Google first-run initialization component.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.syncadapters.calendar': _Rule('Google Calendar Sync', SafetyClass.caution, 'Google calendar account sync.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.syncadapters.contacts': _Rule('Google Contacts Sync', SafetyClass.caution, 'Google contacts account sync.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.gms.location.history': _Rule('Google Location History', SafetyClass.caution, 'Google location-history service.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.projection.gearhead': _Rule('Android Auto', SafetyClass.caution, 'Android Auto will stop working.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.apps.wellbeing': _Rule('Digital Wellbeing', SafetyClass.caution, 'Digital Wellbeing features will be removed.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.tts': _Rule('Google Text-to-Speech', SafetyClass.caution, 'Install another TTS engine first if speech output is needed.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.configupdater': _Rule('Google Config Updater', SafetyClass.caution, 'Google-delivered configuration updates will stop.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.setupwizard': _Rule('Google Setup Wizard', SafetyClass.caution, 'Only remove after initial device setup has completed.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.inputmethod.latin': _Rule('Gboard', SafetyClass.caution, 'Install and enable another keyboard first.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.manual),
    'com.google.android.dialer': _Rule('Google Phone', SafetyClass.caution, 'Select another dialer first.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.manual),
    'com.google.android.apps.messaging': _Rule('Google Messages', SafetyClass.caution, 'Select another SMS app first.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.manual),
    'com.google.android.GoogleCamera': _Rule('Google Camera', SafetyClass.removable, 'Camera app. Keep another camera app available.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.manual),
    'com.google.android.apps.nexuslauncher': _Rule('Pixel Launcher', SafetyClass.caution, 'Install/select another launcher first.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.manual),
    'com.google.android.marvin.talkback': _Rule('TalkBack', SafetyClass.caution, 'Do not remove if you rely on screen-reading accessibility.', category: AppCategory.googleApp, deGoogleTier: DeGoogleTier.manual),
    'com.google.android.ims': _Rule('Carrier Services', SafetyClass.caution, 'Can affect RCS/carrier messaging features.', category: AppCategory.carrierApp, deGoogleTier: DeGoogleTier.manual),
    'com.facebook.katana': _Rule('Facebook', SafetyClass.removable, 'Consumer app.', category: AppCategory.userApp, autoSelect: true),
    'com.facebook.appmanager': _Rule('Meta App Manager', SafetyClass.removable, 'Meta/Facebook preload manager.', category: AppCategory.oemApp, autoSelect: true),
    'com.facebook.services': _Rule('Meta Services', SafetyClass.removable, 'Meta/Facebook preload service.', category: AppCategory.oemApp, autoSelect: true),
    'com.facebook.system': _Rule('Meta App Installer', SafetyClass.removable, 'Meta/Facebook preload installer.', category: AppCategory.oemApp, autoSelect: true),
    'com.miui.analytics': _Rule('MIUI Analytics', SafetyClass.removable, 'Xiaomi analytics component.', category: AppCategory.oemApp, autoSelect: true),
    'com.miui.msa.global': _Rule('MIUI System Ads', SafetyClass.removable, 'Xiaomi advertising service.', category: AppCategory.oemApp, autoSelect: true),
    'com.miui.daemon': _Rule('MIUI Daemon', SafetyClass.caution, 'Xiaomi telemetry/system diagnostics component.', category: AppCategory.oemApp),
    'com.samsung.android.game.gamehome': _Rule('Samsung Gaming Hub', SafetyClass.removable, 'Optional Samsung gaming app.', category: AppCategory.oemApp, autoSelect: true),
    'com.samsung.android.app.spage': _Rule('Samsung Free', SafetyClass.removable, 'Optional Samsung content feed.', category: AppCategory.oemApp, autoSelect: true),
  };

  static bool isGoogleRelated(String packageName) =>
      packageName.startsWith('com.google.') ||
      packageName == 'com.android.vending' ||
      packageName == 'com.android.chrome';

  static bool _matchesAnyPrefix(String value, Iterable<String> prefixes) =>
      prefixes.any((prefix) => value.startsWith(prefix));

  static Set<String> _oemPrefixes(DeviceInfo device) {
    final maker = '${device.manufacturer} ${device.brand} ${device.romName}'.toLowerCase();
    if (maker.contains('oneplus') || maker.contains('oplus') || maker.contains('oppo')) {
      return const {'com.oneplus.', 'net.oneplus.', 'com.oplus.', 'com.oppo.', 'com.coloros.', 'com.heytap.'};
    }
    if (maker.contains('realme')) return const {'com.realme.', 'com.oplus.', 'com.coloros.', 'com.heytap.'};
    if (maker.contains('xiaomi') || maker.contains('redmi') || maker.contains('poco') || maker.contains('miui') || maker.contains('hyperos')) {
      return const {'com.miui.', 'com.xiaomi.', 'com.mi.', 'com.mi.android.', 'com.xiaomi.mipicks'};
    }
    if (maker.contains('samsung')) return const {'com.samsung.', 'com.sec.', 'com.samsung.android.'};
    if (maker.contains('motorola') || maker.contains('lenovo')) return const {'com.motorola.', 'com.lenovo.'};
    if (maker.contains('vivo') || maker.contains('iqoo')) return const {'com.vivo.', 'com.iqoo.', 'com.bbk.'};
    if (maker.contains('nothing')) return const {'com.nothing.'};
    if (maker.contains('asus')) return const {'com.asus.'};
    if (maker.contains('sony')) return const {'com.sonymobile.', 'com.sony.'};
    if (maker.contains('huawei') || maker.contains('honor')) return const {'com.huawei.', 'com.hihonor.'};
    return const <String>{};
  }

  static bool isOemPackage(String packageName, DeviceInfo device) =>
      _matchesAnyPrefix(packageName, _oemPrefixes(device));

  static AppCategory _category(String packageName, DeviceInfo device, PackageMetadata meta) {
    if (isGoogleRelated(packageName)) return AppCategory.googleApp;
    if (isOemPackage(packageName, device)) return AppCategory.oemApp;
    if (!meta.isSystem) return AppCategory.userApp;
    if (packageName.startsWith('com.android.') || packageName.startsWith('android.')) return AppCategory.system;
    if (packageName.contains('carrier') || packageName.contains('ims')) return AppCategory.carrierApp;
    return AppCategory.unknownVendor;
  }

  static bool _deepSystemSignal(PackageMetadata meta) {
    const protectedServicePermissions = {
      'android.permission.BIND_INPUT_METHOD',
      'android.permission.BIND_ACCESSIBILITY_SERVICE',
      'android.permission.BIND_VPN_SERVICE',
      'android.permission.BIND_AUTOFILL_SERVICE',
    };
    return meta.privileged ||
        meta.deviceAdmin ||
        meta.servicePermissions.any(protectedServicePermissions.contains);
  }

  static PackageInfo classify(
    String packageName, {
    required DeviceInfo device,
    required PackageMetadata metadata,
    required bool isApex,
    required bool isOverlay,
    required bool isCriticalRole,
    required bool isCurrentWebView,
    required bool setupComplete,
  }) {
    final rule = _known[packageName];
    final label = metadata.label.trim().isEmpty || metadata.label == packageName
        ? (rule?.name ?? packageName)
        : metadata.label.trim();
    final category = rule?.category ?? _category(packageName, device, metadata);

    if (packageName == 'android' || _coreAndroid.contains(packageName)) {
      return PackageInfo(
        name: label,
        category: AppCategory.system,
        safety: SafetyClass.protected,
        note: 'Android core/platform component. Droid Purifier will not remove it in normal mode.',
        deGoogleTier: isGoogleRelated(packageName) ? DeGoogleTier.core : DeGoogleTier.none,
        confidence: 'high',
      );
    }
    if (isApex) {
      return PackageInfo(name: label, category: AppCategory.system, safety: SafetyClass.protected, note: 'Detected as an Android APEX/Mainline package on this device.', deGoogleTier: isGoogleRelated(packageName) ? DeGoogleTier.core : DeGoogleTier.none, confidence: 'high');
    }
    if (isOverlay) {
      return PackageInfo(name: label, category: AppCategory.system, safety: SafetyClass.protected, note: 'Detected as a runtime resource overlay used by the current ROM.', deGoogleTier: isGoogleRelated(packageName) ? DeGoogleTier.core : DeGoogleTier.none, confidence: 'high');
    }
    if (isCriticalRole) {
      return PackageInfo(name: label, category: category, safety: SafetyClass.protected, note: 'This package currently provides a critical role on this phone. Choose a replacement first.', deGoogleTier: rule?.deGoogleTier ?? (isGoogleRelated(packageName) ? DeGoogleTier.manual : DeGoogleTier.none), confidence: 'high');
    }
    if (isCurrentWebView) {
      return PackageInfo(name: label, category: category, safety: SafetyClass.protected, note: 'Current Android WebView provider. Select another working WebView provider first.', deGoogleTier: rule?.deGoogleTier ?? DeGoogleTier.core, confidence: 'high');
    }
    if (packageName == 'com.google.android.setupwizard' && !setupComplete) {
      return PackageInfo(name: label, category: AppCategory.googleApp, safety: SafetyClass.protected, note: 'Device setup is not complete. Setup Wizard is temporarily protected.', deGoogleTier: DeGoogleTier.core, confidence: 'high');
    }

    if (rule != null) {
      return PackageInfo(
        name: label,
        category: rule.category ?? category,
        safety: rule.safety,
        note: rule.note,
        deGoogleTier: rule.deGoogleTier,
        autoSelect: rule.autoSelect,
        dataWarning: rule.dataWarning,
        confidence: 'high',
      );
    }

    if (!metadata.isSystem) {
      final isDataSensitive = metadata.hasAutofillService ||
          packageName.toLowerCase().contains('authenticator') ||
          label.toLowerCase().contains('authenticator') ||
          label.toLowerCase().contains('password') ||
          label.toLowerCase().contains('wallet');
      return PackageInfo(
        name: label,
        category: isGoogleRelated(packageName) ? AppCategory.googleApp : AppCategory.userApp,
        safety: SafetyClass.removable,
        note: 'Detected dynamically as a normal user-installed app with no protected phone role.',
        deGoogleTier: isGoogleRelated(packageName)
            ? (isDataSensitive ? DeGoogleTier.manual : DeGoogleTier.recommended)
            : DeGoogleTier.none,
        autoSelect: isGoogleRelated(packageName) && !isDataSensitive,
        dataWarning: isDataSensitive ? 'Back up or migrate important local account/data information before removal.' : null,
        confidence: 'high',
      );
    }

    if (isGoogleRelated(packageName)) {
      if (metadata.hasLauncher && !_deepSystemSignal(metadata)) {
        return PackageInfo(name: label, category: AppCategory.googleApp, safety: SafetyClass.removable, note: 'Detected dynamically as a user-facing Google app. No critical Android role was detected.', deGoogleTier: DeGoogleTier.recommended, autoSelect: true, confidence: 'medium-high');
      }
      return PackageInfo(name: label, category: AppCategory.googleApp, safety: SafetyClass.review, note: 'Google system/background package with an unverified purpose. Review before removing.', deGoogleTier: DeGoogleTier.manual, confidence: 'medium');
    }

    if (isOemPackage(packageName, device)) {
      if (metadata.hasLauncher && !_deepSystemSignal(metadata)) {
        return PackageInfo(name: label, category: AppCategory.oemApp, safety: SafetyClass.caution, note: 'Detected as a user-facing preinstalled ${device.manufacturer} app. Android core should remain available, but an OEM feature may be removed.', confidence: 'medium');
      }
      return PackageInfo(name: label, category: AppCategory.oemApp, safety: SafetyClass.review, note: 'Detected as an OEM system/background package. Its dependency is not verified, so Droid Purifier will not bulk-select it.', confidence: 'medium');
    }

    if (packageName.startsWith('com.android.') ||
        packageName.startsWith('android.') ||
        metadata.privileged ||
        _deepSystemSignal(metadata)) {
      return PackageInfo(name: label, category: AppCategory.system, safety: SafetyClass.review, note: 'Unverified Android/system component. It is intentionally left for manual review.', confidence: 'medium');
    }

    return PackageInfo(name: label, category: AppCategory.unknownVendor, safety: SafetyClass.review, note: 'Preinstalled package with insufficient evidence for safe bulk removal.', confidence: 'low');
  }

  static bool recommendedCandidate(PackageInfo info) =>
      info.deGoogleTier == DeGoogleTier.recommended &&
      info.safety == SafetyClass.removable &&
      info.autoSelect;

  static bool fullCandidate(PackageInfo info) =>
      (info.deGoogleTier == DeGoogleTier.recommended || info.deGoogleTier == DeGoogleTier.full) &&
      !info.protected &&
      info.safety != SafetyClass.review &&
      info.autoSelect;

  static bool removableCandidate(PackageInfo info) => info.safety == SafetyClass.removable;
}
