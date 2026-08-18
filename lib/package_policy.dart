enum SafetyClass { knownRemovable, featureDependent, unknown, protected }

enum DeGoogleTier { none, recommended, full, manual, core }

class PackageInfo {
  const PackageInfo(
    this.name,
    this.safety,
    this.note, {
    this.deGoogleTier = DeGoogleTier.none,
    this.autoSelect = false,
  });

  final String name;
  final SafetyClass safety;
  final String note;
  final DeGoogleTier deGoogleTier;
  final bool autoSelect;

  bool get protected => safety == SafetyClass.protected;
  bool get googleRemovalCandidate =>
      deGoogleTier == DeGoogleTier.recommended ||
      deGoogleTier == DeGoogleTier.full ||
      deGoogleTier == DeGoogleTier.manual;
}

/// Package policy deliberately fails safe.
///
/// A package is NEVER called "Known removable" merely because Droid Purifier
/// does not recognise it. Dynamic device facts (APEX, overlay, current role,
/// WebView provider, etc.) override this curated list and can protect a package
/// on one phone even when it is removable on another.
class PackagePolicy {
  static const Map<String, PackageInfo> exact = {
    // Android framework / platform essentials.
    'android': PackageInfo(
      'Android Framework',
      SafetyClass.protected,
      'Core Android framework resources. Never remove.',
    ),
    'com.android.systemui': PackageInfo(
      'Android System UI',
      SafetyClass.protected,
      'Required for the status bar, navigation and system interface.',
    ),
    'com.android.settings': PackageInfo(
      'Android Settings',
      SafetyClass.protected,
      'Required to manage the device.',
    ),
    'com.android.phone': PackageInfo(
      'Android Phone Services',
      SafetyClass.protected,
      'Core telephony service.',
    ),
    'com.android.providers.settings': PackageInfo(
      'Settings Provider',
      SafetyClass.protected,
      'Core Android settings storage.',
    ),
    'com.android.packageinstaller': PackageInfo(
      'Android Package Installer',
      SafetyClass.protected,
      'Required to install and manage applications.',
    ),
    'com.google.android.packageinstaller': PackageInfo(
      'Android Package Installer (Google build)',
      SafetyClass.protected,
      'Android package-management component, not Google bloatware.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.permissioncontroller': PackageInfo(
      'Android Permission Controller',
      SafetyClass.protected,
      'Manages Android runtime permissions and roles.',
    ),
    'com.google.android.permissioncontroller': PackageInfo(
      'Android Permission Controller (Google build)',
      SafetyClass.protected,
      'Android permission infrastructure. Keep it when De-Googling.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.permission': PackageInfo(
      'Android Permission Mainline module',
      SafetyClass.protected,
      'Modern Android permission framework module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.documentsui': PackageInfo(
      'Android DocumentsUI',
      SafetyClass.protected,
      'Android system file/document picker.',
    ),
    'com.google.android.documentsui': PackageInfo(
      'Android DocumentsUI (Google build)',
      SafetyClass.protected,
      'Android system file/document picker, not a Google consumer app.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.ext.services': PackageInfo(
      'Android ExtServices',
      SafetyClass.protected,
      'Android framework extension services.',
    ),
    'com.google.android.ext.services': PackageInfo(
      'Android ExtServices (Google build)',
      SafetyClass.protected,
      'Android framework/Mainline service.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.ext.shared': PackageInfo(
      'Android ExtShared',
      SafetyClass.protected,
      'Shared Android framework extension library.',
    ),
    'com.google.android.ext.shared': PackageInfo(
      'Android ExtShared (Google build)',
      SafetyClass.protected,
      'Shared Android framework library.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.modulemetadata': PackageInfo(
      'Android Module Metadata',
      SafetyClass.protected,
      'Tracks Android modular-system metadata.',
    ),
    'com.google.android.modulemetadata': PackageInfo(
      'Android Module Metadata (Google build)',
      SafetyClass.protected,
      'Android modular-system metadata component.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.networkstack': PackageInfo(
      'Android Network Stack',
      SafetyClass.protected,
      'Core Android networking component.',
    ),
    'com.google.android.networkstack': PackageInfo(
      'Android Network Stack (Google build)',
      SafetyClass.protected,
      'Core Android networking/Mainline component.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.networkstack.permissionconfig': PackageInfo(
      'Network Stack Permission Configuration',
      SafetyClass.protected,
      'Permission configuration for Android networking.',
    ),
    'com.google.android.networkstack.permissionconfig': PackageInfo(
      'Network Stack Permission Configuration (Google build)',
      SafetyClass.protected,
      'Android networking permission configuration.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.captiveportallogin': PackageInfo(
      'Captive Portal Login',
      SafetyClass.protected,
      'Used to sign into Wi-Fi captive portals.',
    ),
    'com.google.android.captiveportallogin': PackageInfo(
      'Captive Portal Login (Google build)',
      SafetyClass.protected,
      'Android networking component for Wi-Fi sign-in pages.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.webview': PackageInfo(
      'Android System WebView (Google provider)',
      SafetyClass.protected,
      'Many apps need a working WebView provider. Replace it first.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.webview': PackageInfo(
      'Android System WebView',
      SafetyClass.protected,
      'Many apps need a working WebView provider.',
    ),

    // Modern Android Mainline aliases. Dynamic APEX detection adds another
    // layer, so future modules remain protected even if absent from this list.
    'com.google.android.conscrypt': PackageInfo('Android Conscrypt module', SafetyClass.protected, 'Core TLS/cryptography module.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.resolv': PackageInfo('Android DNS Resolver module', SafetyClass.protected, 'Core DNS/networking module.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.cellbroadcast': PackageInfo('Android Cell Broadcast module', SafetyClass.protected, 'Emergency/system cell broadcast module.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.tzdata2': PackageInfo('Android Time Zone Data module', SafetyClass.protected, 'System time-zone data module.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.media': PackageInfo('Android Media module', SafetyClass.protected, 'Core Android media framework module.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.media.swcodec': PackageInfo('Android Media Codec module', SafetyClass.protected, 'Core Android software codecs.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.mediaprovider': PackageInfo('Android MediaProvider module', SafetyClass.protected, 'Core Android media provider.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.sdkext': PackageInfo('Android SDK Extensions module', SafetyClass.protected, 'Android SDK extension module.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.os.statsd': PackageInfo('Android statsd module', SafetyClass.protected, 'Android platform statistics infrastructure.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.tethering': PackageInfo('Android Tethering module', SafetyClass.protected, 'Hotspot/tethering implementation.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.wifi': PackageInfo('Android Wi-Fi module', SafetyClass.protected, 'Core Android Wi-Fi implementation.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.ipsec': PackageInfo('Android IPsec module', SafetyClass.protected, 'Core IPsec/IKE implementation.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.neuralnetworks': PackageInfo('Android NNAPI module', SafetyClass.protected, 'Android neural-networks runtime.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.art': PackageInfo('Android Runtime module', SafetyClass.protected, 'Android Runtime (ART). Never remove.', deGoogleTier: DeGoogleTier.core),
    'com.google.android.adbd': PackageInfo('Android ADB module', SafetyClass.protected, 'Android debugging daemon module.', deGoogleTier: DeGoogleTier.core),

    // Google consumer apps: explicitly curated and appropriate for the
    // Recommended De-Google preset when they are not a critical current role.
    'com.google.android.youtube': PackageInfo('YouTube', SafetyClass.knownRemovable, 'Google YouTube app.', deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.gm': PackageInfo('Gmail', SafetyClass.knownRemovable, 'Google Gmail app.', deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.docs': PackageInfo('Google Drive', SafetyClass.knownRemovable, 'Google Drive app.', deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.photos': PackageInfo('Google Photos', SafetyClass.knownRemovable, 'Google Photos app.', deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.videos': PackageInfo('Google TV / Play Movies', SafetyClass.knownRemovable, 'Google video/TV app.', deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.music': PackageInfo('Google Play Music', SafetyClass.knownRemovable, 'Legacy Google music app.', deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.ar.lens': PackageInfo('Google Lens', SafetyClass.knownRemovable, 'Google Lens app.', deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.feedback': PackageInfo('Google Feedback', SafetyClass.knownRemovable, 'Google feedback/reporting component.', deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.tachyon': PackageInfo('Google Meet / Duo', SafetyClass.knownRemovable, 'Google video calling app.', deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.podcasts': PackageInfo('Google Podcasts', SafetyClass.knownRemovable, 'Legacy Google Podcasts app.', deGoogleTier: DeGoogleTier.recommended, autoSelect: true),
    'com.google.android.apps.maps': PackageInfo('Google Maps', SafetyClass.featureDependent, 'Navigation/location features are removed. Install an alternative if needed.', deGoogleTier: DeGoogleTier.full, autoSelect: true),

    // Google framework/services. Full De-Google may select these, but the UI
    // must explain the feature impact and third-party compatibility impact.
    'com.google.android.gms': PackageInfo('Google Play Services', SafetyClass.featureDependent, 'Removing it can break apps that use Google APIs, FCM or Play Integrity.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.gsf': PackageInfo('Google Services Framework', SafetyClass.featureDependent, 'Core Google account/service framework. Android can run without it, but Google-dependent apps may fail.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.gsf.login': PackageInfo('Google Account Manager (legacy)', SafetyClass.featureDependent, 'Legacy Google account sign-in component.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.android.vending': PackageInfo('Google Play Store', SafetyClass.featureDependent, 'Google app store. Install another app source before removing if desired.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.googlequicksearchbox': PackageInfo('Google App / Assistant', SafetyClass.featureDependent, 'Google Search and Assistant integration.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.apps.restore': PackageInfo('Google Restore', SafetyClass.featureDependent, 'Google device restore functionality.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.backuptransport': PackageInfo('Google Backup Transport', SafetyClass.featureDependent, 'Legacy Google cloud backup transport.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.apps.turbo': PackageInfo('Device Health Services', SafetyClass.featureDependent, 'Google battery/device-health prediction features.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.partnersetup': PackageInfo('Google Partner Setup', SafetyClass.featureDependent, 'Google partner/setup integration.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.onetimeinitializer': PackageInfo('Google One-Time Initializer', SafetyClass.featureDependent, 'Google first-run initialization component.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.syncadapters.calendar': PackageInfo('Google Calendar Sync', SafetyClass.featureDependent, 'Google calendar account sync.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.syncadapters.contacts': PackageInfo('Google Contacts Sync', SafetyClass.featureDependent, 'Google contacts account sync.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.gms.location.history': PackageInfo('Google Location History', SafetyClass.featureDependent, 'Google location-history service.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.projection.gearhead': PackageInfo('Android Auto', SafetyClass.featureDependent, 'Android Auto will stop working.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.printservice.recommendation': PackageInfo('Google Print Recommendation', SafetyClass.featureDependent, 'Printer recommendation service.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.apps.wellbeing': PackageInfo('Digital Wellbeing', SafetyClass.featureDependent, 'Digital Wellbeing features will be removed.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.tts': PackageInfo('Google Text-to-Speech', SafetyClass.featureDependent, 'Install another TTS engine first if speech output is needed.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.configupdater': PackageInfo('Google Config Updater', SafetyClass.featureDependent, 'Google-delivered system configuration updates will stop.', deGoogleTier: DeGoogleTier.full, autoSelect: true),
    'com.google.android.setupwizard': PackageInfo('Google Setup Wizard', SafetyClass.featureDependent, 'Only remove after initial device setup has completed.', deGoogleTier: DeGoogleTier.full, autoSelect: true),

    // Role-sensitive Google apps. Never auto-select: the dynamic scanner may
    // protect them if currently used as launcher/IME/dialer/SMS/WebView.
    'com.google.android.inputmethod.latin': PackageInfo('Gboard', SafetyClass.featureDependent, 'Keyboard. Install/select another keyboard before removing.', deGoogleTier: DeGoogleTier.manual),
    'com.google.android.dialer': PackageInfo('Google Phone', SafetyClass.featureDependent, 'Dialer. Select another dialer before removing.', deGoogleTier: DeGoogleTier.manual),
    'com.google.android.apps.messaging': PackageInfo('Google Messages', SafetyClass.featureDependent, 'SMS/RCS app. Select another SMS app before removing.', deGoogleTier: DeGoogleTier.manual),
    'com.google.android.GoogleCamera': PackageInfo('Google Camera', SafetyClass.featureDependent, 'Camera app. Keep another camera app available.', deGoogleTier: DeGoogleTier.manual),
    'com.google.android.apps.nexuslauncher': PackageInfo('Pixel Launcher', SafetyClass.featureDependent, 'Launcher. Install/select another launcher before removing.', deGoogleTier: DeGoogleTier.manual),
    'com.google.android.marvin.talkback': PackageInfo('TalkBack', SafetyClass.featureDependent, 'Accessibility screen reader. Do not remove if you rely on it.', deGoogleTier: DeGoogleTier.manual),
    'com.google.android.apps.authenticator2': PackageInfo('Google Authenticator', SafetyClass.featureDependent, 'May contain access to 2FA codes; migrate first.', deGoogleTier: DeGoogleTier.manual),
    'com.google.android.ims': PackageInfo('Carrier Services', SafetyClass.featureDependent, 'Can affect carrier messaging/RCS features.', deGoogleTier: DeGoogleTier.manual),
    'com.android.chrome': PackageInfo('Google Chrome', SafetyClass.featureDependent, 'Browser. Install another browser first if this is your only browser.', deGoogleTier: DeGoogleTier.manual),

    // Common explicitly-known OEM/social bloat. This is intentionally small;
    // unknown OEM packages stay Unknown instead of being guessed safe.
    'com.facebook.katana': PackageInfo('Facebook', SafetyClass.knownRemovable, 'Facebook consumer app.', autoSelect: true),
    'com.facebook.appmanager': PackageInfo('Meta App Manager', SafetyClass.knownRemovable, 'Meta/Facebook preload manager.', autoSelect: true),
    'com.facebook.services': PackageInfo('Meta Services', SafetyClass.knownRemovable, 'Meta/Facebook preload service.', autoSelect: true),
    'com.facebook.system': PackageInfo('Meta App Installer', SafetyClass.knownRemovable, 'Meta/Facebook preload installer.', autoSelect: true),
    'com.miui.analytics': PackageInfo('MIUI Analytics', SafetyClass.knownRemovable, 'Xiaomi analytics component.', autoSelect: true),
    'com.miui.msa.global': PackageInfo('MIUI System Ads', SafetyClass.knownRemovable, 'Xiaomi advertising service.', autoSelect: true),
  };

  static bool isGoogleRelated(String packageName) =>
      packageName.startsWith('com.google.') ||
      packageName == 'com.android.vending' ||
      packageName == 'com.android.chrome';

  static PackageInfo classify(
    String packageName, {
    required bool isSystem,
    required bool isApex,
    required bool isOverlay,
    required bool isCriticalRole,
    required bool isCurrentWebView,
    required bool setupComplete,
  }) {
    final base = exact[packageName];

    if (packageName == 'android') return exact['android']!;
    if (isApex) {
      return PackageInfo(
        base?.name ?? packageName,
        SafetyClass.protected,
        'Detected as an Android APEX/Mainline package on this device.',
        deGoogleTier: isGoogleRelated(packageName) ? DeGoogleTier.core : DeGoogleTier.none,
      );
    }
    if (isOverlay) {
      return PackageInfo(
        base?.name ?? packageName,
        SafetyClass.protected,
        'Detected as an Android runtime resource overlay on this device.',
        deGoogleTier: isGoogleRelated(packageName) ? DeGoogleTier.core : DeGoogleTier.none,
      );
    }
    if (isCriticalRole) {
      return PackageInfo(
        base?.name ?? packageName,
        SafetyClass.protected,
        'Currently provides a critical device role (launcher, keyboard, dialer, SMS or accessibility). Choose a replacement first.',
        deGoogleTier: base?.deGoogleTier ?? DeGoogleTier.none,
      );
    }
    if (isCurrentWebView) {
      return PackageInfo(
        base?.name ?? packageName,
        SafetyClass.protected,
        'Current WebView provider. Select another working WebView provider before removal.',
        deGoogleTier: base?.deGoogleTier ?? DeGoogleTier.core,
      );
    }
    if (packageName == 'com.google.android.setupwizard' && !setupComplete) {
      return const PackageInfo(
        'Google Setup Wizard',
        SafetyClass.protected,
        'Device setup is not complete. Setup Wizard is temporarily protected.',
        deGoogleTier: DeGoogleTier.core,
      );
    }
    if (base != null) return base;

    // Generic namespaces are NEVER trusted as removable.
    if (packageName.startsWith('android.') ||
        packageName.startsWith('com.android.') ||
        packageName.startsWith('com.google.android.overlay.') ||
        packageName.contains('.overlay.') ||
        packageName.endsWith('.overlay')) {
      return PackageInfo(
        packageName,
        SafetyClass.unknown,
        'Unverified Android/OEM system package. Droid Purifier will not bulk-select it.',
      );
    }

    if (isGoogleRelated(packageName)) {
      return PackageInfo(
        packageName,
        SafetyClass.unknown,
        'Unverified Google-namespaced package. Not automatically selected.',
        deGoogleTier: DeGoogleTier.manual,
      );
    }

    if (isSystem) {
      return PackageInfo(
        packageName,
        SafetyClass.unknown,
        'Unverified system/OEM package. Not automatically selected.',
      );
    }

    return PackageInfo(
      packageName,
      SafetyClass.featureDependent,
      'User-installed app. Android should remain functional, but the app and its features will be unavailable.',
    );
  }

  static bool recommendedCandidate(PackageInfo info) =>
      info.deGoogleTier == DeGoogleTier.recommended &&
      info.safety == SafetyClass.knownRemovable &&
      info.autoSelect;

  static bool fullCandidate(PackageInfo info) =>
      (info.deGoogleTier == DeGoogleTier.recommended ||
          info.deGoogleTier == DeGoogleTier.full) &&
      !info.protected &&
      info.safety != SafetyClass.unknown &&
      info.autoSelect;

  static bool knownRemovableCandidate(PackageInfo info) =>
      info.safety == SafetyClass.knownRemovable && info.autoSelect;
}
