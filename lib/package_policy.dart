enum RiskLevel { low, medium, high, critical, protected }

enum DeGoogleTier {
  none,
  recommended,
  full,
  manual,
  core,
}

class RiskInfo {
  const RiskInfo(
    this.name,
    this.level,
    this.note, {
    this.deGoogleTier = DeGoogleTier.none,
    this.autoSelect = false,
  });

  final String name;
  final RiskLevel level;
  final String note;
  final DeGoogleTier deGoogleTier;
  final bool autoSelect;

  bool get protected => level == RiskLevel.protected;
  bool get googleRemovalCandidate =>
      deGoogleTier == DeGoogleTier.recommended ||
      deGoogleTier == DeGoogleTier.full ||
      deGoogleTier == DeGoogleTier.manual;
}

/// Conservative package policy for stock Android builds from legacy Android
/// versions through modern Mainline/APEX based releases.
///
/// Design rule: if a Google-namespaced package is unknown, Droid Purifier does
/// not auto-select it. This makes new Android releases fail safe instead of
/// assuming every future com.google.* package is bloatware.
class RiskDatabase {
  static const Map<String, RiskInfo> exact = {
    // Core Android packages.
    'com.android.systemui': RiskInfo(
      'Android System UI',
      RiskLevel.protected,
      'Required for the Android interface.',
    ),
    'com.android.settings': RiskInfo(
      'Android Settings',
      RiskLevel.protected,
      'Required to manage the device.',
    ),
    'com.android.phone': RiskInfo(
      'Phone Services',
      RiskLevel.protected,
      'Core telephony service.',
    ),
    'com.android.providers.settings': RiskInfo(
      'Settings Provider',
      RiskLevel.protected,
      'Core Android settings storage.',
    ),
    'com.android.packageinstaller': RiskInfo(
      'Android Package Installer',
      RiskLevel.protected,
      'Required to install and manage apps on older Android versions.',
    ),
    'com.google.android.packageinstaller': RiskInfo(
      'Android Package Installer (Google build)',
      RiskLevel.protected,
      'Android system package installer; keep it even when De-Googling.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.permissioncontroller': RiskInfo(
      'Android Permission Controller',
      RiskLevel.protected,
      'Manages runtime permissions and Android roles.',
    ),
    'com.google.android.permissioncontroller': RiskInfo(
      'Android Permission Controller (Google build)',
      RiskLevel.protected,
      'Android 10 permission system. This is Android core, not a removable Google app.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.permission': RiskInfo(
      'Android Permission Mainline module',
      RiskLevel.protected,
      'Modern Android permission framework/Mainline module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.documentsui': RiskInfo(
      'Android DocumentsUI',
      RiskLevel.protected,
      'Provides Android system file/document picker functionality.',
    ),
    'com.google.android.documentsui': RiskInfo(
      'Android DocumentsUI (Google build)',
      RiskLevel.protected,
      'Android system file/document picker. Keep it when De-Googling.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.ext.services': RiskInfo(
      'Android ExtServices',
      RiskLevel.protected,
      'Android framework extension services.',
    ),
    'com.google.android.ext.services': RiskInfo(
      'Android ExtServices (Google build)',
      RiskLevel.protected,
      'Android Mainline/framework service, not a normal Google app.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.ext.shared': RiskInfo(
      'Android ExtShared',
      RiskLevel.protected,
      'Shared Android framework extension library.',
    ),
    'com.google.android.ext.shared': RiskInfo(
      'Android ExtShared (Google build)',
      RiskLevel.protected,
      'Shared Android framework library. Keep it when De-Googling.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.modulemetadata': RiskInfo(
      'Android Module Metadata',
      RiskLevel.protected,
      'Tracks Android Mainline module metadata/security state.',
    ),
    'com.google.android.modulemetadata': RiskInfo(
      'Android Module Metadata (Google build)',
      RiskLevel.protected,
      'Android Mainline metadata component, not a removable Google app.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.networkstack': RiskInfo(
      'Android Network Stack',
      RiskLevel.protected,
      'Core Android networking component.',
    ),
    'com.google.android.networkstack': RiskInfo(
      'Android Network Stack (Google build)',
      RiskLevel.protected,
      'Core Android networking/Mainline component.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.networkstack.permissionconfig': RiskInfo(
      'Network Stack Permission Configuration',
      RiskLevel.protected,
      'Permission configuration for Android networking.',
    ),
    'com.google.android.networkstack.permissionconfig': RiskInfo(
      'Network Stack Permission Configuration (Google build)',
      RiskLevel.protected,
      'Android networking permission configuration.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.captiveportallogin': RiskInfo(
      'Captive Portal Login',
      RiskLevel.protected,
      'Used to sign into Wi-Fi captive portals.',
    ),
    'com.google.android.captiveportallogin': RiskInfo(
      'Captive Portal Login (Google build)',
      RiskLevel.protected,
      'Android networking component used for Wi-Fi sign-in pages.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.webview': RiskInfo(
      'Android System WebView (Google provider)',
      RiskLevel.protected,
      'Many apps require a working WebView provider. Replace the provider before attempting to remove it.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.android.webview': RiskInfo(
      'Android System WebView',
      RiskLevel.protected,
      'Many apps require a working WebView provider.',
    ),
    'com.google.android.conscrypt': RiskInfo(
      'Android Conscrypt Mainline module',
      RiskLevel.protected,
      'Core TLS/cryptography provider used by Android.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.resolv': RiskInfo(
      'Android DNS Resolver Mainline module',
      RiskLevel.protected,
      'Core Android DNS/networking module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.cellbroadcast': RiskInfo(
      'Android Cell Broadcast Mainline module',
      RiskLevel.protected,
      'System/emergency cell broadcast functionality.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.tzdata2': RiskInfo(
      'Android Time Zone Data module',
      RiskLevel.protected,
      'System time-zone data/Mainline module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.media': RiskInfo(
      'Android Media Mainline module',
      RiskLevel.protected,
      'Core Android media framework module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.media.swcodec': RiskInfo(
      'Android Media Codec Mainline module',
      RiskLevel.protected,
      'Core Android software media codecs.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.mediaprovider': RiskInfo(
      'Android MediaProvider Mainline module',
      RiskLevel.protected,
      'Core Android media storage/provider functionality.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.sdkext': RiskInfo(
      'Android SDK Extensions Mainline module',
      RiskLevel.protected,
      'Android platform SDK extension module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.os.statsd': RiskInfo(
      'Android statsd Mainline module',
      RiskLevel.protected,
      'Android platform statistics infrastructure.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.tethering': RiskInfo(
      'Android Tethering Mainline module',
      RiskLevel.protected,
      'Core hotspot/tethering implementation.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.wifi': RiskInfo(
      'Android Wi-Fi Mainline module',
      RiskLevel.protected,
      'Core Android Wi-Fi implementation.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.ipsec': RiskInfo(
      'Android IPsec Mainline module',
      RiskLevel.protected,
      'Core IPsec/IKE networking implementation.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.neuralnetworks': RiskInfo(
      'Android NNAPI Mainline module',
      RiskLevel.protected,
      'Android neural-networks runtime module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.art': RiskInfo(
      'Android Runtime Mainline module',
      RiskLevel.protected,
      'Android Runtime (ART) module. Never remove.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.runtime': RiskInfo(
      'Android Runtime module',
      RiskLevel.protected,
      'Core Android runtime libraries.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.i18n': RiskInfo(
      'Android i18n Mainline module',
      RiskLevel.protected,
      'Core Android internationalization libraries.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.adbd': RiskInfo(
      'Android ADB Mainline module',
      RiskLevel.protected,
      'Android debugging daemon module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.rkpd': RiskInfo(
      'Android Remote Key Provisioning module',
      RiskLevel.protected,
      'Security/key-provisioning system module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.uwb': RiskInfo(
      'Android UWB Mainline module',
      RiskLevel.protected,
      'Android ultra-wideband platform module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.btservices': RiskInfo(
      'Android Bluetooth Mainline module',
      RiskLevel.protected,
      'Core Android Bluetooth services.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.appsearch': RiskInfo(
      'Android AppSearch Mainline module',
      RiskLevel.protected,
      'Android platform search/indexing module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.configinfrastructure': RiskInfo(
      'Android Config Infrastructure module',
      RiskLevel.protected,
      'Android platform configuration Mainline module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.crashrecovery': RiskInfo(
      'Android Crash Recovery module',
      RiskLevel.protected,
      'Android system crash-recovery infrastructure.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.profiling': RiskInfo(
      'Android Profiling module',
      RiskLevel.protected,
      'Android platform profiling Mainline module.',
      deGoogleTier: DeGoogleTier.core,
    ),
    'com.google.android.euicc': RiskInfo(
      'Android eSIM Manager (Google build)',
      RiskLevel.protected,
      'System eSIM management component. Removing it can break eSIM functionality.',
      deGoogleTier: DeGoogleTier.core,
    ),

    // Full De-Google infrastructure. Basic Android can run without these, but
    // Google-dependent third-party apps/features may stop working.
    'com.google.android.gms': RiskInfo(
      'Google Play services',
      RiskLevel.critical,
      'Full De-Google target. Apps using Google APIs, FCM, location or Play Integrity may stop working.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.google.android.gsf': RiskInfo(
      'Google Services Framework',
      RiskLevel.critical,
      'Full De-Google target. Google account/device registration and Google framework features will stop.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.google.android.gsf.login': RiskInfo(
      'Google Account Manager (legacy)',
      RiskLevel.high,
      'Legacy Google account sign-in component found on older Android versions.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.android.vending': RiskInfo(
      'Google Play Store',
      RiskLevel.high,
      'Full De-Google target. Install/update apps using another source after removal.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.google.android.googlequicksearchbox': RiskInfo(
      'Google app / Assistant',
      RiskLevel.medium,
      'Google Search, Discover and Assistant integrations will stop.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.google.android.gms.location.history': RiskInfo(
      'Google Location History',
      RiskLevel.low,
      'Google location-history component.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.backuptransport': RiskInfo(
      'Google Backup Transport (legacy)',
      RiskLevel.medium,
      'Legacy Google cloud backup transport.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.restore': RiskInfo(
      'Google Restore',
      RiskLevel.medium,
      'Google cloud/device restore component.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.pixelmigrate': RiskInfo(
      'Google Data Transfer / Pixel Migrate',
      RiskLevel.medium,
      'Google device migration component.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.turbo': RiskInfo(
      'Device Health Services',
      RiskLevel.medium,
      'Google battery/device health predictions and related intelligence.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.google.android.partnersetup': RiskInfo(
      'Google Partner Setup',
      RiskLevel.medium,
      'Google partner/OEM integration setup service.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.onetimeinitializer': RiskInfo(
      'Google One-Time Initializer',
      RiskLevel.low,
      'Legacy Google one-time provisioning component.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.syncadapters.contacts': RiskInfo(
      'Google Contacts Sync',
      RiskLevel.medium,
      'Google-account contact synchronization will stop.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.google.android.syncadapters.calendar': RiskInfo(
      'Google Calendar Sync',
      RiskLevel.medium,
      'Google-account calendar synchronization will stop.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.google.android.projection.gearhead': RiskInfo(
      'Android Auto',
      RiskLevel.medium,
      'Android Auto will stop working.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.google.android.printservice.recommendation': RiskInfo(
      'Google Print Service Recommendation',
      RiskLevel.low,
      'Printer discovery/recommendation integration will be removed.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.google.android.apps.wellbeing': RiskInfo(
      'Digital Wellbeing',
      RiskLevel.medium,
      'Digital Wellbeing, app timers and related features will stop.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.google.android.feedback': RiskInfo(
      'Google Feedback',
      RiskLevel.low,
      'Google feedback/reporting component.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.tts': RiskInfo(
      'Speech Services by Google',
      RiskLevel.high,
      'Google text-to-speech will stop. Install another TTS engine first if you rely on spoken output.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),
    'com.google.android.marvin.talkback': RiskInfo(
      'Android Accessibility Suite / TalkBack',
      RiskLevel.high,
      'TalkBack/accessibility services will stop. Do not remove if you depend on them.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: false,
    ),
    'com.google.android.setupwizard': RiskInfo(
      'Google Setup Wizard',
      RiskLevel.high,
      'Remove only after Android initial setup has completed.',
      deGoogleTier: DeGoogleTier.full,
      autoSelect: true,
    ),

    // Google applications that are generally safe to remove if their feature
    // is not needed.
    'com.android.chrome': RiskInfo(
      'Google Chrome',
      RiskLevel.low,
      'Install another browser if needed.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.gm': RiskInfo(
      'Gmail',
      RiskLevel.low,
      'Gmail app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.maps': RiskInfo(
      'Google Maps',
      RiskLevel.low,
      'Google Maps app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.mapslite': RiskInfo(
      'Google Maps Go',
      RiskLevel.low,
      'Google Maps Go app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.photos': RiskInfo(
      'Google Photos',
      RiskLevel.low,
      'Google Photos app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.photosgo': RiskInfo(
      'Gallery Go / Google Photos Go',
      RiskLevel.low,
      'Google gallery app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.docs': RiskInfo(
      'Google Drive',
      RiskLevel.low,
      'Google Drive app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.nbu.files': RiskInfo(
      'Files by Google',
      RiskLevel.low,
      'Files by Google app. Android DocumentsUI is protected separately.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.calendar': RiskInfo(
      'Google Calendar',
      RiskLevel.low,
      'Google Calendar app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.contacts': RiskInfo(
      'Google Contacts',
      RiskLevel.medium,
      'Install another contacts app if needed.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.youtube': RiskInfo(
      'YouTube',
      RiskLevel.low,
      'YouTube app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.youtube.music': RiskInfo(
      'YouTube Music',
      RiskLevel.low,
      'YouTube Music app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.youtube.kids': RiskInfo(
      'YouTube Kids',
      RiskLevel.low,
      'YouTube Kids app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.tachyon': RiskInfo(
      'Google Meet',
      RiskLevel.low,
      'Google Meet app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.keep': RiskInfo(
      'Google Keep',
      RiskLevel.low,
      'Google Keep app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.videos': RiskInfo(
      'Google TV',
      RiskLevel.low,
      'Google TV app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.magazines': RiskInfo(
      'Google News',
      RiskLevel.low,
      'Google News app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.walletnfcrel': RiskInfo(
      'Google Wallet',
      RiskLevel.medium,
      'Google Wallet/contactless payment features will stop.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.subscriptions.red': RiskInfo(
      'Google One',
      RiskLevel.low,
      'Google One app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.podcasts': RiskInfo(
      'Google Podcasts',
      RiskLevel.low,
      'Legacy Google Podcasts app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.translate': RiskInfo(
      'Google Translate',
      RiskLevel.low,
      'Google Translate app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.authenticator2': RiskInfo(
      'Google Authenticator',
      RiskLevel.medium,
      'Export/migrate 2FA accounts before removing this app.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),
    'com.google.android.apps.chromecast.app': RiskInfo(
      'Google Home',
      RiskLevel.low,
      'Google Home / Cast device management app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.books': RiskInfo(
      'Google Play Books',
      RiskLevel.low,
      'Google Play Books app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.music': RiskInfo(
      'Google Play Music (legacy)',
      RiskLevel.low,
      'Legacy Google Play Music app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.plus': RiskInfo(
      'Google+ (legacy)',
      RiskLevel.low,
      'Legacy Google+ app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.genie.geniewidget': RiskInfo(
      'Google News & Weather (legacy)',
      RiskLevel.low,
      'Legacy Google News/Weather app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.ears': RiskInfo(
      'Google Sound Search (legacy)',
      RiskLevel.low,
      'Legacy Google Sound Search component.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.ar.lens': RiskInfo(
      'Google Lens',
      RiskLevel.low,
      'Google Lens app/service.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),

    // Packages that can be removed, but Droid Purifier will never select them
    // automatically because doing so can remove an essential user-facing role.
    'com.google.android.inputmethod.latin': RiskInfo(
      'Gboard',
      RiskLevel.high,
      'Install and enable another keyboard before removing Gboard.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),
    'com.google.android.dialer': RiskInfo(
      'Google Phone',
      RiskLevel.high,
      'Install and set another dialer before removing Google Phone.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),
    'com.google.android.apps.messaging': RiskInfo(
      'Google Messages',
      RiskLevel.high,
      'Install and set another SMS app before removing Google Messages.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),
    'com.google.android.GoogleCamera': RiskInfo(
      'Google Camera',
      RiskLevel.high,
      'Install another camera app before removing the stock camera.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),
    'com.google.android.GoogleCameraEng': RiskInfo(
      'Google Camera',
      RiskLevel.high,
      'Install another camera app before removing the stock camera.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),
    'com.google.android.apps.nexuslauncher': RiskInfo(
      'Pixel Launcher',
      RiskLevel.high,
      'Install and set another launcher before removing Pixel Launcher.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),
    'com.google.android.deskclock': RiskInfo(
      'Google Clock',
      RiskLevel.medium,
      'Alarms/timers in Google Clock will be removed.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.calculator': RiskInfo(
      'Google Calculator',
      RiskLevel.low,
      'Google Calculator app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.wallpaper': RiskInfo(
      'Google Wallpapers',
      RiskLevel.low,
      'Google wallpaper picker/content.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.recorder': RiskInfo(
      'Google Recorder',
      RiskLevel.low,
      'Google Recorder app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),
    'com.google.android.apps.tips': RiskInfo(
      'Pixel Tips',
      RiskLevel.low,
      'Google/Pixel tips app.',
      deGoogleTier: DeGoogleTier.recommended,
      autoSelect: true,
    ),

    // Advanced/uncertain integrations. They are intentionally manual because
    // their impact varies by Android release, carrier, or device.
    'com.google.android.configupdater': RiskInfo(
      'Google Config Updater',
      RiskLevel.high,
      'Updates security/configuration data on some stock Android releases. Advanced removal only.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),
    'com.google.android.ims': RiskInfo(
      'Google Carrier Services',
      RiskLevel.high,
      'Carrier/RCS/IMS behavior varies by device. Do not auto-remove.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),
    'com.google.android.carriersetup': RiskInfo(
      'Google Carrier Setup',
      RiskLevel.high,
      'Carrier provisioning behavior varies by device and network.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),
    'com.google.android.apps.enterprise.dmagent': RiskInfo(
      'Google Enterprise Device Management',
      RiskLevel.high,
      'May be required on managed/work devices.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),
    'com.google.android.apps.work.clouddpc': RiskInfo(
      'Android Device Policy',
      RiskLevel.high,
      'May be required for work profiles or enterprise management.',
      deGoogleTier: DeGoogleTier.manual,
      autoSelect: false,
    ),

    // Manufacturer bloatware retained from the existing app.
    'com.samsung.android.app.spage': RiskInfo('Samsung Free', RiskLevel.low, 'Samsung Free / Discover feed.'),
    'com.samsung.android.app.tips': RiskInfo('Samsung Tips', RiskLevel.low, 'Samsung tips and onboarding content.'),
    'com.samsung.android.game.gamehome': RiskInfo('Samsung Gaming Hub', RiskLevel.low, 'Samsung gaming launcher.'),
    'com.samsung.android.game.gametools': RiskInfo('Samsung Game Tools', RiskLevel.low, 'Samsung gaming overlay tools.'),
    'com.samsung.android.aremoji': RiskInfo('Samsung AR Emoji', RiskLevel.low, 'AR Emoji features.'),
    'com.samsung.android.arzone': RiskInfo('Samsung AR Zone', RiskLevel.low, 'AR Zone features.'),
    'com.samsung.android.kidsinstaller': RiskInfo('Samsung Kids Installer', RiskLevel.low, 'Samsung Kids bootstrap component.'),
    'com.samsung.android.bixby.agent': RiskInfo('Bixby Voice', RiskLevel.medium, 'Bixby voice features may stop.'),
    'com.samsung.android.bixby.wakeup': RiskInfo('Bixby Wakeup', RiskLevel.low, 'Bixby wake-word component.'),
    'com.miui.analytics': RiskInfo('MIUI Analytics', RiskLevel.low, 'Xiaomi analytics component.'),
    'com.miui.msa.global': RiskInfo('MIUI System Ads', RiskLevel.low, 'MIUI advertising service.'),
    'com.xiaomi.mipicks': RiskInfo('GetApps', RiskLevel.low, 'Xiaomi GetApps store.'),
    'com.miui.hybrid': RiskInfo('MIUI Quick Apps', RiskLevel.low, 'MIUI Quick Apps framework.'),
    'com.miui.hybrid.accessory': RiskInfo('Quick Apps Accessory', RiskLevel.low, 'MIUI Quick Apps accessory component.'),
    'com.miui.yellowpage': RiskInfo('MIUI Yellow Pages', RiskLevel.low, 'Business/caller information component.'),
    'com.miui.player': RiskInfo('Mi Music', RiskLevel.low, 'Xiaomi music app.'),
    'com.miui.videoplayer': RiskInfo('Mi Video', RiskLevel.low, 'Xiaomi video app.'),
    'com.heytap.browser': RiskInfo('HeyTap Browser', RiskLevel.low, 'OEM browser.'),
    'com.heytap.market': RiskInfo('HeyTap App Market', RiskLevel.low, 'OEM app market.'),
    'com.oppo.market': RiskInfo('OPPO App Market', RiskLevel.low, 'OPPO app market.'),
    'com.coloros.video': RiskInfo('ColorOS Video', RiskLevel.low, 'ColorOS video app.'),
    'com.coloros.gamespace': RiskInfo('ColorOS Game Space', RiskLevel.low, 'ColorOS gaming hub.'),
    'com.facebook.appmanager': RiskInfo('Meta App Manager', RiskLevel.low, 'Meta preload updater.'),
    'com.facebook.services': RiskInfo('Meta Services', RiskLevel.low, 'Background Meta preload services.'),
    'com.facebook.system': RiskInfo('Meta App Installer', RiskLevel.low, 'Meta preload installer.'),
  };

  static const Set<String> manufacturerBloat = {
    'com.samsung.android.app.spage',
    'com.samsung.android.app.tips',
    'com.samsung.android.game.gamehome',
    'com.samsung.android.game.gametools',
    'com.samsung.android.aremoji',
    'com.samsung.android.arzone',
    'com.samsung.android.kidsinstaller',
    'com.samsung.android.bixby.agent',
    'com.samsung.android.bixby.wakeup',
    'com.miui.analytics',
    'com.miui.msa.global',
    'com.xiaomi.mipicks',
    'com.miui.hybrid',
    'com.miui.hybrid.accessory',
    'com.miui.yellowpage',
    'com.miui.player',
    'com.miui.videoplayer',
    'com.heytap.browser',
    'com.heytap.market',
    'com.oppo.market',
    'com.coloros.video',
    'com.coloros.gamespace',
    'com.facebook.appmanager',
    'com.facebook.services',
    'com.facebook.system',
  };

  static const List<String> _googleCorePrefixes = [
    'com.google.android.overlay.',
    'com.google.android.overlay.modules.',
    'com.google.android.networkstack.',
    'com.google.android.permission.',
  ];

  static bool isGoogleRelated(String packageName) =>
      packageName.startsWith('com.google.') ||
      packageName == 'com.android.chrome' ||
      packageName == 'com.android.vending';

  static RiskInfo get(
    String packageName, {
    int? sdkInt,
    bool isApex = false,
    bool setupComplete = true,
  }) {
    // APEX packages are Android platform modules. New Android versions can add
    // modules that this app has never seen; protecting them dynamically is the
    // compatibility safety net for future releases.
    if (isApex) {
      return RiskInfo(
        prettyName(packageName),
        RiskLevel.protected,
        'Detected as an Android APEX/Mainline system module. Droid Purifier never auto-removes APEX modules.',
        deGoogleTier: isGoogleRelated(packageName) ? DeGoogleTier.core : DeGoogleTier.none,
      );
    }

    if (packageName == 'com.google.android.setupwizard' && !setupComplete) {
      return const RiskInfo(
        'Google Setup Wizard',
        RiskLevel.protected,
        'Initial Android setup is not complete. Keep Setup Wizard until provisioning finishes.',
        deGoogleTier: DeGoogleTier.core,
      );
    }

    final known = exact[packageName];
    if (known != null) return known;

    if (_googleCorePrefixes.any(packageName.startsWith)) {
      return RiskInfo(
        'Android system overlay/module',
        RiskLevel.protected,
        'Google-namespaced Android platform resource/module. Keep it for system compatibility.',
        deGoogleTier: DeGoogleTier.core,
      );
    }

    if (packageName.contains('.overlay.') && packageName.startsWith('com.google.')) {
      return const RiskInfo(
        'Android system resource overlay',
        RiskLevel.protected,
        'Runtime resource overlay for an Android system component; no privacy benefit from removing it.',
        deGoogleTier: DeGoogleTier.core,
      );
    }

    if (packageName.startsWith('com.android.')) {
      return const RiskInfo(
        'Android system component',
        RiskLevel.high,
        'Unknown Android system package. Review carefully; it is never auto-selected.',
      );
    }

    if (packageName.startsWith('com.google.')) {
      return const RiskInfo(
        'Unclassified Google package',
        RiskLevel.high,
        'Not recognized by the current safety database. It is never auto-selected; verify its role before removal.',
        deGoogleTier: DeGoogleTier.manual,
        autoSelect: false,
      );
    }

    const prefixes = <String>[
      'com.samsung.',
      'com.sec.',
      'com.miui.',
      'com.xiaomi.',
      'com.oneplus.',
      'com.oplus.',
      'com.coloros.',
      'com.oppo.',
      'com.heytap.',
      'com.realme.',
      'com.vivo.',
      'com.iqoo.',
    ];
    if (prefixes.any(packageName.startsWith)) {
      return RiskInfo(
        prettyName(packageName),
        RiskLevel.medium,
        'OEM package not in the curated database. It is not selected automatically.',
      );
    }

    return RiskInfo(
      prettyName(packageName),
      RiskLevel.low,
      'Third-party or uncategorized package. It is not selected automatically.',
    );
  }

  static bool isProtected(
    String packageName, {
    int? sdkInt,
    bool isApex = false,
    bool setupComplete = true,
  }) =>
      get(
        packageName,
        sdkInt: sdkInt,
        isApex: isApex,
        setupComplete: setupComplete,
      ).protected;

  static bool isRecommendedDeGoogle(
    String packageName, {
    int? sdkInt,
    bool isApex = false,
    bool setupComplete = true,
  }) {
    final info = get(
      packageName,
      sdkInt: sdkInt,
      isApex: isApex,
      setupComplete: setupComplete,
    );
    return info.deGoogleTier == DeGoogleTier.recommended && info.autoSelect && !info.protected;
  }

  static bool isFullDeGoogle(
    String packageName, {
    int? sdkInt,
    bool isApex = false,
    bool setupComplete = true,
  }) {
    final info = get(
      packageName,
      sdkInt: sdkInt,
      isApex: isApex,
      setupComplete: setupComplete,
    );
    final tier = info.deGoogleTier;
    return (tier == DeGoogleTier.recommended || tier == DeGoogleTier.full) &&
        info.autoSelect &&
        !info.protected;
  }

  static bool isCuratedSafeSelection(
    String packageName, {
    int? sdkInt,
    bool isApex = false,
    bool setupComplete = true,
  }) {
    final info = get(
      packageName,
      sdkInt: sdkInt,
      isApex: isApex,
      setupComplete: setupComplete,
    );
    if (info.protected || !info.autoSelect) return false;
    return info.level == RiskLevel.low || info.level == RiskLevel.medium;
  }

  static String prettyName(String packageName) {
    final value = packageName.split('.').last.replaceAll('_', ' ');
    if (value.isEmpty) return packageName;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
