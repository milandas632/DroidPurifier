import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DeviceInfo {
  const DeviceInfo({required this.id, required this.status, required this.model, required this.manufacturer, required this.brand, required this.deviceCodename, required this.androidVersion, required this.sdkInt, required this.battery, required this.setupComplete, required this.buildFingerprint, required this.securityPatch, required this.romName});
  final String id;
  final String status;
  final String model;
  final String manufacturer;
  final String brand;
  final String deviceCodename;
  final String androidVersion;
  final int? sdkInt;
  final String battery;
  final bool setupComplete;
  final String buildFingerprint;
  final String securityPatch;
  final String romName;
  bool get ready => status == 'device';
}

class PackageMetadata {
  const PackageMetadata({required this.packageName, required this.label, required this.versionName, required this.versionCode, required this.sourceDir, required this.installer, required this.uid, required this.isSystem, required this.isUpdatedSystem, required this.enabled, required this.hasLauncher, required this.privileged, required this.deviceAdmin, required this.requestedPermissions, required this.servicePermissions});
  final String packageName;
  final String label;
  final String versionName;
  final int versionCode;
  final String sourceDir;
  final String installer;
  final int uid;
  final bool isSystem;
  final bool isUpdatedSystem;
  final bool enabled;
  final bool hasLauncher;
  final bool privileged;
  final bool deviceAdmin;
  final Set<String> requestedPermissions;
  final Set<String> servicePermissions;
  bool get dataAreaInstall => sourceDir.startsWith('/data/');
  bool get hasVpnService => servicePermissions.contains('android.permission.BIND_VPN_SERVICE');
  bool get hasInputMethodService => servicePermissions.contains('android.permission.BIND_INPUT_METHOD');
  bool get hasAccessibilityService => servicePermissions.contains('android.permission.BIND_ACCESSIBILITY_SERVICE');
  bool get hasNotificationListener => servicePermissions.contains('android.permission.BIND_NOTIFICATION_LISTENER_SERVICE');
  bool get hasAutofillService => servicePermissions.contains('android.permission.BIND_AUTOFILL_SERVICE');
}

class PackageInventory {
  const PackageInventory({required this.packages, required this.systemPackages, required this.apexPackages, required this.metadata, required this.enhancedScan});
  final List<String> packages;
  final Set<String> systemPackages;
  final Set<String> apexPackages;
  final Map<String, PackageMetadata> metadata;
  final bool enhancedScan;
}

class SafetySnapshot {
  const SafetySnapshot({required this.overlayPackages, required this.criticalRolePackages, required this.enabledAccessibilityPackages, required this.currentLauncher, required this.currentIme, required this.currentDialer, required this.currentSms, required this.currentBrowser, required this.currentWebView});
  final Set<String> overlayPackages;
  final Set<String> criticalRolePackages;
  final Set<String> enabledAccessibilityPackages;
  final String? currentLauncher;
  final String? currentIme;
  final String? currentDialer;
  final String? currentSms;
  final String? currentBrowser;
  final String? currentWebView;
}

class HealthCheckItem {
  const HealthCheckItem(this.label, this.ok, this.detail);
  final String label;
  final bool ok;
  final String detail;
}

class HealthReport {
  const HealthReport(this.items);
  final List<HealthCheckItem> items;
  bool get passed => items.every((item) => item.ok);
}

class AdbException implements Exception {
  const AdbException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AdbService {
  String? _cachedExecutable;

  static String join(String root, List<String> parts) {
    var value = root;
    for (final part in parts) {
      if (part == '..') {
        value = Directory(value).parent.path;
      } else {
        value = value.endsWith(Platform.pathSeparator) ? '$value$part' : '$value${Platform.pathSeparator}$part';
      }
    }
    return value;
  }

  Future<String> get executable async {
    if (_cachedExecutable != null) return _cachedExecutable!;
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final cwd = Directory.current.path;
    final candidates = <String>[];
    if (Platform.isWindows) {
      candidates.addAll([join(exeDir, ['platform-tools', 'adb.exe']), join(cwd, ['tools', 'platform-tools', 'adb.exe']), join(cwd, ['platform-tools', 'adb.exe'])]);
    } else {
      candidates.addAll([join(exeDir, ['..', 'Resources', 'platform-tools', 'adb']), join(cwd, ['tools', 'platform-tools', 'adb']), '/opt/homebrew/bin/adb', '/usr/local/bin/adb']);
    }
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        _cachedExecutable = candidate;
        return candidate;
      }
    }
    return 'adb';
  }

  Future<String?> get helperApk async {
    final exeDir = File(Platform.resolvedExecutable).parent.path;
    final cwd = Directory.current.path;
    final candidates = <String>[join(exeDir, ['helper', 'droid_purifier_helper.apk']), join(cwd, ['helper', 'droid_purifier_helper.apk'])];
    if (Platform.isMacOS) candidates.insert(0, join(exeDir, ['..', 'Resources', 'helper', 'droid_purifier_helper.apk']));
    for (final candidate in candidates) {
      if (await File(candidate).exists()) return candidate;
    }
    return null;
  }

  Future<ProcessResult> run(List<String> args, {Duration timeout = const Duration(seconds: 60)}) async {
    try {
      return await Process.run(await executable, args).timeout(timeout);
    } on TimeoutException {
      throw AdbException('ADB command timed out: adb ${args.join(' ')}');
    } on ProcessException catch (error) {
      throw AdbException('ADB could not be started. ${error.message}');
    }
  }

  Future<ProcessResult> _shell(String deviceId, List<String> command, {Duration timeout = const Duration(seconds: 60)}) => run(['-s', deviceId, 'shell', ...command], timeout: timeout);

  Future<String> _shellText(String deviceId, List<String> command) async {
    try {
      final result = await _shell(deviceId, command);
      if (result.exitCode != 0) return '';
      return result.stdout.toString().trim();
    } catch (_) {
      return '';
    }
  }

  Future<List<DeviceInfo>> devices() async {
    final result = await run(['devices']);
    if (result.exitCode != 0) throw AdbException(result.stderr.toString().trim());
    final output = <DeviceInfo>[];
    final lines = result.stdout.toString().split(RegExp(r'\r?\n'));
    for (final line in lines.skip(1)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2 || parts.first.isEmpty) continue;
      final id = parts[0];
      final status = parts[1];
      if (status == 'device') {
        output.add(await _details(id));
      } else {
        output.add(DeviceInfo(id: id, status: status, model: 'Unknown', manufacturer: 'Unknown', brand: 'Unknown', deviceCodename: 'Unknown', androidVersion: 'Unknown', sdkInt: null, battery: 'Unknown', setupComplete: false, buildFingerprint: '', securityPatch: '', romName: 'Unknown Android'));
      }
    }
    return output;
  }

  String _romName(Map<String, String> props) {
    String v(String key) => (props[key] ?? '').toLowerCase();
    if (v('ro.build.version.oxygen').isNotEmpty || v('ro.oxygen.version').isNotEmpty) return 'OxygenOS';
    if (v('ro.build.version.oplusrom').isNotEmpty || v('ro.build.version.opporom').isNotEmpty) return 'ColorOS / OPlus';
    if (v('ro.miui.ui.version.name').isNotEmpty) return 'MIUI / HyperOS';
    if (v('ro.build.version.oneui').isNotEmpty || v('ro.build.version.sep').isNotEmpty) return 'Samsung One UI';
    if (v('ro.vivo.os.version').isNotEmpty) return 'vivo / iQOO OS';
    if (v('ro.build.version.realmeui').isNotEmpty) return 'realme UI';
    final display = v('ro.build.display.id');
    if (display.contains('nothing')) return 'Nothing OS';
    if (display.contains('lineage')) return 'LineageOS';
    return 'Android';
  }

  Future<DeviceInfo> _details(String id) async {
    const keys = ['ro.product.model', 'ro.product.manufacturer', 'ro.product.brand', 'ro.product.device', 'ro.build.version.release', 'ro.build.version.sdk', 'ro.build.fingerprint', 'ro.build.version.security_patch', 'ro.build.display.id', 'ro.build.version.oxygen', 'ro.oxygen.version', 'ro.build.version.oplusrom', 'ro.build.version.opporom', 'ro.miui.ui.version.name', 'ro.build.version.oneui', 'ro.build.version.sep', 'ro.vivo.os.version', 'ro.build.version.realmeui'];
    final props = <String, String>{};
    for (final key in keys) {
      props[key] = await _shellText(id, ['getprop', key]);
    }
    final batteryDump = await _shellText(id, ['dumpsys', 'battery']);
    final level = RegExp(r'level:\s*(\d+)').firstMatch(batteryDump)?.group(1);
    final userSetup = await _shellText(id, ['settings', 'get', 'secure', 'user_setup_complete']);
    final provisioned = await _shellText(id, ['settings', 'get', 'global', 'device_provisioned']);
    final explicitlyIncomplete = userSetup == '0' || provisioned == '0';
    final explicitlyComplete = userSetup == '1' || provisioned == '1';
    return DeviceInfo(
      id: id,
      status: 'device',
      model: props['ro.product.model']!.isEmpty ? 'Android device' : props['ro.product.model']!,
      manufacturer: props['ro.product.manufacturer']!.isEmpty ? 'Unknown' : props['ro.product.manufacturer']!,
      brand: props['ro.product.brand']!.isEmpty ? 'Unknown' : props['ro.product.brand']!,
      deviceCodename: props['ro.product.device']!.isEmpty ? 'Unknown' : props['ro.product.device']!,
      androidVersion: props['ro.build.version.release']!.isEmpty ? 'Unknown' : props['ro.build.version.release']!,
      sdkInt: int.tryParse(props['ro.build.version.sdk'] ?? ''),
      battery: level == null ? 'Unknown' : '$level%',
      setupComplete: explicitlyComplete || !explicitlyIncomplete,
      buildFingerprint: props['ro.build.fingerprint'] ?? '',
      securityPatch: props['ro.build.version.security_patch'] ?? '',
      romName: _romName(props),
    );
  }

  List<String> _parsePackageList(String output) {
    final values = output.split(RegExp(r'\r?\n')).where((line) => line.startsWith('package:')).map((line) {
      final value = line.substring(8).trim();
      final equals = value.lastIndexOf('=');
      return equals >= 0 ? value.substring(equals + 1).trim() : value;
    }).where((value) => value.isNotEmpty).toSet().toList()..sort();
    return values;
  }

  Future<Map<String, PackageMetadata>> _fallbackMetadata(String deviceId, List<String> packages, Set<String> systemPackages) async {
    final result = await _shellText(deviceId, ['pm', 'list', 'packages', '-f', '-i', '-U']);
    final metadata = <String, PackageMetadata>{};
    final packageRegex = RegExp(r'package:(\S+?)=(\S+)');
    final installerRegex = RegExp(r'installer=(\S+)');
    final uidRegex = RegExp(r'uid:(\d+)');
    for (final line in result.split(RegExp(r'\r?\n'))) {
      final match = packageRegex.firstMatch(line);
      if (match == null) continue;
      final source = match.group(1) ?? '';
      final packageName = match.group(2) ?? '';
      final installer = installerRegex.firstMatch(line)?.group(1) ?? '';
      final uid = int.tryParse(uidRegex.firstMatch(line)?.group(1) ?? '') ?? -1;
      metadata[packageName] = PackageMetadata(packageName: packageName, label: packageName, versionName: '', versionCode: 0, sourceDir: source, installer: installer == 'null' ? '' : installer, uid: uid, isSystem: systemPackages.contains(packageName), isUpdatedSystem: false, enabled: true, hasLauncher: false, privileged: source.contains('/priv-app/'), deviceAdmin: false, requestedPermissions: const <String>{}, servicePermissions: const <String>{});
    }
    for (final packageName in packages) {
      metadata.putIfAbsent(packageName, () => PackageMetadata(packageName: packageName, label: packageName, versionName: '', versionCode: 0, sourceDir: '', installer: '', uid: -1, isSystem: systemPackages.contains(packageName), isUpdatedSystem: false, enabled: true, hasLauncher: false, privileged: false, deviceAdmin: false, requestedPermissions: const <String>{}, servicePermissions: const <String>{}));
    }
    return metadata;
  }

  PackageMetadata _metadataFromJson(Map<String, dynamic> json) {
    Set<String> strings(Object? value) => (value as List<dynamic>? ?? const []).map((item) => item.toString()).where((item) => item.isNotEmpty).toSet();
    return PackageMetadata(
      packageName: json['packageName']?.toString() ?? '',
      label: json['label']?.toString() ?? json['packageName']?.toString() ?? '',
      versionName: json['versionName']?.toString() ?? '',
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      sourceDir: json['sourceDir']?.toString() ?? '',
      installer: json['installer']?.toString() ?? '',
      uid: (json['uid'] as num?)?.toInt() ?? -1,
      isSystem: json['system'] == true,
      isUpdatedSystem: json['updatedSystem'] == true,
      enabled: json['enabled'] != false,
      hasLauncher: json['hasLauncher'] == true,
      privileged: json['privileged'] == true,
      deviceAdmin: json['deviceAdmin'] == true,
      requestedPermissions: strings(json['requestedPermissions']),
      servicePermissions: strings(json['servicePermissions']),
    );
  }

  Future<Map<String, PackageMetadata>?> _helperMetadata(String deviceId) async {
    final apk = await helperApk;
    if (apk == null) return null;
    const helperPackage = 'com.techydruid.droidpurifierhelper';
    const remoteFile = '/sdcard/Android/data/com.techydruid.droidpurifierhelper/files/droid_purifier_scan.json';
    try {
      final install = await run(['-s', deviceId, 'install', '-r', apk], timeout: const Duration(minutes: 2));
      final installText = '${install.stdout}\n${install.stderr}'.toLowerCase();
      if (install.exitCode != 0 || !installText.contains('success')) return null;
      await _shell(deviceId, ['am', 'start', '-n', '$helperPackage/.ScanActivity', '--activity-clear-top']);
      String jsonText = '';
      for (var attempt = 0; attempt < 60; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
        jsonText = await _shellText(deviceId, ['cat', remoteFile]);
        if (jsonText.startsWith('{') && jsonText.endsWith('}')) break;
      }
      if (jsonText.isEmpty) return null;
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return null;
      final items = decoded['packages'];
      if (items is! List<dynamic>) return null;
      final metadata = <String, PackageMetadata>{};
      for (final item in items) {
        if (item is! Map) continue;
        final meta = _metadataFromJson(Map<String, dynamic>.from(item));
        if (meta.packageName.isNotEmpty) metadata[meta.packageName] = meta;
      }
      return metadata.isEmpty ? null : metadata;
    } catch (_) {
      return null;
    } finally {
      try {
        await run(['-s', deviceId, 'uninstall', helperPackage]);
      } catch (_) {}
    }
  }

  Future<PackageInventory> packageInventory(String deviceId, {int? sdkInt, bool enhanced = true}) async {
    final all = await _shell(deviceId, ['pm', 'list', 'packages']);
    if (all.exitCode != 0) throw AdbException(all.stderr.toString().trim());
    final packages = _parsePackageList(all.stdout.toString());
    final systemPackages = <String>{};
    systemPackages.addAll(_parsePackageList(await _shellText(deviceId, ['pm', 'list', 'packages', '-s'])));
    final apexPackages = <String>{};
    if (sdkInt == null || sdkInt >= 29) apexPackages.addAll(_parsePackageList(await _shellText(deviceId, ['pm', 'list', 'packages', '--apex-only'])));
    Map<String, PackageMetadata>? metadata;
    if (enhanced) metadata = await _helperMetadata(deviceId);
    final helperUsed = metadata != null;
    metadata ??= await _fallbackMetadata(deviceId, packages, systemPackages);
    for (final packageName in systemPackages) {
      final old = metadata[packageName];
      if (old != null && !old.isSystem) {
        metadata[packageName] = PackageMetadata(packageName: old.packageName, label: old.label, versionName: old.versionName, versionCode: old.versionCode, sourceDir: old.sourceDir, installer: old.installer, uid: old.uid, isSystem: true, isUpdatedSystem: old.isUpdatedSystem, enabled: old.enabled, hasLauncher: old.hasLauncher, privileged: old.privileged, deviceAdmin: old.deviceAdmin, requestedPermissions: old.requestedPermissions, servicePermissions: old.servicePermissions);
      }
    }
    return PackageInventory(packages: packages, systemPackages: systemPackages, apexPackages: apexPackages, metadata: metadata, enhancedScan: helperUsed);
  }

  String? _componentPackage(String text, Set<String> installed) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed == 'null') return null;
    for (final line in trimmed.split(RegExp(r'\r?\n')).reversed) {
      final value = line.trim();
      if (value.isEmpty) continue;
      final slash = value.indexOf('/');
      if (slash > 0) {
        final packageName = value.substring(0, slash).trim();
        if (installed.contains(packageName)) return packageName;
      }
      if (installed.contains(value)) return value;
    }
    return null;
  }

  Future<String?> _resolveActivityPackage(String deviceId, Set<String> installed, List<String> args) async {
    var text = await _shellText(deviceId, ['cmd', 'package', 'resolve-activity', '--brief', ...args]);
    var found = _componentPackage(text, installed);
    if (found != null) return found;
    text = await _shellText(deviceId, ['pm', 'resolve-activity', '--brief', ...args]);
    return _componentPackage(text, installed);
  }

  Set<String> _packagesFromText(String text, Set<String> installed) {
    final result = <String>{};
    final regex = RegExp(r'[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)+');
    for (final match in regex.allMatches(text)) {
      final value = match.group(0);
      if (value != null && installed.contains(value)) result.add(value);
    }
    return result;
  }

  Future<SafetySnapshot> safetySnapshot(DeviceInfo device, PackageInventory inventory) async {
    final installed = inventory.packages.toSet();
    final overlayPackages = <String>{};
    final overlayText = await _shellText(device.id, ['cmd', 'overlay', 'list']);
    if (overlayText.isNotEmpty) overlayPackages.addAll(_packagesFromText(overlayText, installed));
    final currentLauncher = await _resolveActivityPackage(device.id, installed, ['-a', 'android.intent.action.MAIN', '-c', 'android.intent.category.HOME']);
    final currentIme = _componentPackage(await _shellText(device.id, ['settings', 'get', 'secure', 'default_input_method']), installed);
    String? currentDialer;
    if ((device.sdkInt ?? 0) >= 29) currentDialer = _componentPackage(await _shellText(device.id, ['cmd', 'role', 'get-role-holders', 'android.app.role.DIALER']), installed);
    currentDialer ??= _componentPackage(await _shellText(device.id, ['telecom', 'get-default-dialer']), installed);
    String? currentSms;
    if ((device.sdkInt ?? 0) >= 29) currentSms = _componentPackage(await _shellText(device.id, ['cmd', 'role', 'get-role-holders', 'android.app.role.SMS']), installed);
    currentSms ??= _componentPackage(await _shellText(device.id, ['settings', 'get', 'secure', 'sms_default_application']), installed);
    final currentBrowser = await _resolveActivityPackage(device.id, installed, ['-a', 'android.intent.action.VIEW', '-d', 'https://example.com']);
    String? currentWebView;
    final webviewDump = await _shellText(device.id, ['dumpsys', 'webviewupdate']);
    if (webviewDump.isNotEmpty) {
      final candidates = _packagesFromText(webviewDump, installed);
      for (final packageName in candidates) {
        if (packageName.toLowerCase().contains('webview')) {
          currentWebView = packageName;
          break;
        }
      }
    }
    final enabledAccessibilityPackages = <String>{};
    final accessibility = await _shellText(device.id, ['settings', 'get', 'secure', 'enabled_accessibility_services']);
    if (accessibility.isNotEmpty && accessibility != 'null') enabledAccessibilityPackages.addAll(_packagesFromText(accessibility, installed));
    final criticalRolePackages = <String>{if (currentLauncher != null) currentLauncher, if (currentIme != null) currentIme, if (currentDialer != null) currentDialer, if (currentSms != null) currentSms, ...enabledAccessibilityPackages};
    for (final meta in inventory.metadata.values) {
      if (meta.deviceAdmin) criticalRolePackages.add(meta.packageName);
    }
    return SafetySnapshot(overlayPackages: overlayPackages, criticalRolePackages: criticalRolePackages, enabledAccessibilityPackages: enabledAccessibilityPackages, currentLauncher: currentLauncher, currentIme: currentIme, currentDialer: currentDialer, currentSms: currentSms, currentBrowser: currentBrowser, currentWebView: currentWebView);
  }

  Future<HealthReport> healthCheck(DeviceInfo device) async {
    final items = <HealthCheckItem>[];
    try {
      final echo = await _shell(device.id, ['echo', 'DROID_PURIFIER_OK']);
      items.add(HealthCheckItem('ADB connection', echo.exitCode == 0 && echo.stdout.toString().contains('DROID_PURIFIER_OK'), 'Device responds to ADB.'));
    } catch (_) {
      items.add(const HealthCheckItem('ADB connection', false, 'Device did not respond to ADB.'));
      return HealthReport(items);
    }
    final inventory = await packageInventory(device.id, sdkInt: device.sdkInt, enhanced: false);
    final installed = inventory.packages.toSet();
    for (final entry in const {'Android System UI': 'com.android.systemui', 'Android Settings': 'com.android.settings'}.entries) {
      items.add(HealthCheckItem(entry.key, installed.contains(entry.value), installed.contains(entry.value) ? 'Present.' : 'Package missing for user 0.'));
    }
    final snapshot = await safetySnapshot(device, inventory);
    items.add(HealthCheckItem('Launcher', snapshot.currentLauncher != null, snapshot.currentLauncher ?? 'No default launcher resolved.'));
    items.add(HealthCheckItem('Keyboard', snapshot.currentIme != null, snapshot.currentIme ?? 'No default keyboard resolved.'));
    items.add(HealthCheckItem('WebView provider', snapshot.currentWebView != null || (device.sdkInt ?? 0) < 21, snapshot.currentWebView ?? 'No active WebView provider resolved.'));
    return HealthReport(items);
  }

  Future<void> backup(String deviceId, String packageName, Directory output, {int? sdkInt}) async {
    final pathResult = await _shell(deviceId, ['pm', 'path', packageName]);
    if (pathResult.exitCode != 0) throw AdbException('Could not locate APK files for $packageName.');
    final paths = pathResult.stdout.toString().split(RegExp(r'\r?\n')).where((line) => line.startsWith('package:')).map((line) => line.substring(8).trim()).where((value) => value.isNotEmpty).toList();
    if (paths.isEmpty) throw AdbException('No APK path was returned for $packageName.');
    if (await output.exists()) await output.delete(recursive: true);
    await output.create(recursive: true);
    for (final remote in paths) {
      final fileName = remote.split('/').last;
      final local = join(output.path, [fileName.isEmpty ? 'base.apk' : fileName]);
      final pull = await run(['-s', deviceId, 'pull', remote, local], timeout: const Duration(minutes: 5));
      if (pull.exitCode != 0) {
        await output.delete(recursive: true);
        throw AdbException('Backup failed for $packageName: ${pull.stderr.toString().trim()}');
      }
    }
    await File(join(output.path, ['metadata.json'])).writeAsString(const JsonEncoder.withIndent('  ').convert({'package': packageName, 'deviceId': deviceId, 'androidSdk': sdkInt, 'createdAt': DateTime.now().toIso8601String()}));
  }

  Future<String?> uninstall(String deviceId, String packageName) async {
    final result = await _shell(deviceId, ['pm', 'uninstall', '-k', '--user', '0', packageName]);
    final text = '${result.stdout}\n${result.stderr}'.trim();
    if (result.exitCode == 0 && text.toLowerCase().contains('success')) return null;
    return text.isEmpty ? 'Unknown uninstall failure.' : text;
  }

  Future<String?> restore(String deviceId, String packageName, Directory backupDir) async {
    try {
      final existing = await _shell(deviceId, ['cmd', 'package', 'install-existing', '--user', '0', packageName]);
      final text = '${existing.stdout}\n${existing.stderr}'.toLowerCase();
      if (existing.exitCode == 0 && (text.contains('installed') || text.contains('success'))) return null;
    } catch (_) {}
    try {
      final legacy = await _shell(deviceId, ['pm', 'install-existing', '--user', '0', packageName]);
      final text = '${legacy.stdout}\n${legacy.stderr}'.toLowerCase();
      if (legacy.exitCode == 0 && (text.contains('installed') || text.contains('success'))) return null;
    } catch (_) {}
    if (!await backupDir.exists()) return 'No APK backup is available.';
    final apks = await backupDir.list().where((entry) => entry is File && entry.path.toLowerCase().endsWith('.apk')).cast<File>().map((file) => file.path).toList();
    if (apks.isEmpty) return 'No APK backup is available.';
    final args = apks.length == 1 ? ['-s', deviceId, 'install', '-r', '-d', apks.first] : ['-s', deviceId, 'install-multiple', '-r', '-d', ...apks];
    final result = await run(args, timeout: const Duration(minutes: 5));
    final text = '${result.stdout}\n${result.stderr}'.trim();
    if (result.exitCode == 0 && text.toLowerCase().contains('success')) return null;
    return text.isEmpty ? 'Restore failed.' : text;
  }
}

class BackupStore {
  Directory root(DeviceInfo device) {
    final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? Directory.current.path;
    final safeId = device.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return Directory(AdbService.join(home, ['DroidPurifier', 'Backups', safeId]));
  }
  Directory packageDir(DeviceInfo device, String packageName) => Directory(AdbService.join(root(device).path, [packageName]));
  Future<List<String>> packages(DeviceInfo device) async {
    final directory = root(device);
    if (!await directory.exists()) return [];
    final values = await directory.list().where((entry) => entry is Directory).cast<Directory>().map((entry) => entry.path.split(Platform.pathSeparator).last).toList();
    values.sort();
    return values;
  }
}
