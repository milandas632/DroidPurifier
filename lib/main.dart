import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

void main() => runApp(const DroidPurifierApp());

class DroidPurifierApp extends StatelessWidget {
  const DroidPurifierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Droid Purifier',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xffb7f34a),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xff090c10),
      ),
      home: const HomePage(),
    );
  }
}

class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.status,
    required this.model,
    required this.manufacturer,
    required this.androidVersion,
    required this.battery,
  });

  final String id;
  final String status;
  final String model;
  final String manufacturer;
  final String androidVersion;
  final String battery;

  bool get ready => status == 'device';
}

enum RiskLevel { low, medium, high, critical, protected }

class RiskInfo {
  const RiskInfo(this.name, this.level, this.note);
  final String name;
  final RiskLevel level;
  final String note;
}

class RiskDatabase {
  static const Map<String, RiskInfo> exact = {
    'com.android.systemui': RiskInfo('Android System UI', RiskLevel.protected, 'Required for the Android interface.'),
    'com.android.settings': RiskInfo('Android Settings', RiskLevel.protected, 'Required to manage the device.'),
    'com.android.phone': RiskInfo('Phone Services', RiskLevel.protected, 'Core telephony service.'),
    'com.android.providers.settings': RiskInfo('Settings Provider', RiskLevel.protected, 'Core Android settings storage.'),
    'com.android.packageinstaller': RiskInfo('Package Installer', RiskLevel.protected, 'Required to install and manage apps.'),
    'com.google.android.packageinstaller': RiskInfo('Google Package Installer', RiskLevel.protected, 'Required to install and manage apps.'),
    'com.google.android.gms': RiskInfo('Google Play services', RiskLevel.critical, 'Many apps depend on Play services and Google APIs.'),
    'com.google.android.gsf': RiskInfo('Google Services Framework', RiskLevel.critical, 'Core Google framework used by many apps.'),
    'com.android.vending': RiskInfo('Google Play Store', RiskLevel.high, 'Play Store installs and updates will stop.'),
    'com.google.android.googlequicksearchbox': RiskInfo('Google app / Assistant', RiskLevel.medium, 'Search, Discover and Assistant integrations may stop.'),
    'com.google.android.inputmethod.latin': RiskInfo('Gboard', RiskLevel.high, 'Install another keyboard before removing it.'),
    'com.google.android.dialer': RiskInfo('Google Phone', RiskLevel.high, 'Install another dialer before removing it.'),
    'com.google.android.apps.messaging': RiskInfo('Google Messages', RiskLevel.medium, 'Google Messages and RCS features will be removed.'),
    'com.android.chrome': RiskInfo('Google Chrome', RiskLevel.low, 'Safe if another browser is installed.'),
    'com.google.android.gm': RiskInfo('Gmail', RiskLevel.low, 'Gmail app.'),
    'com.google.android.apps.maps': RiskInfo('Google Maps', RiskLevel.low, 'Google Maps app.'),
    'com.google.android.apps.photos': RiskInfo('Google Photos', RiskLevel.low, 'Google Photos app.'),
    'com.google.android.apps.docs': RiskInfo('Google Drive', RiskLevel.low, 'Google Drive app.'),
    'com.google.android.apps.nbu.files': RiskInfo('Files by Google', RiskLevel.low, 'Files by Google app.'),
    'com.google.android.calendar': RiskInfo('Google Calendar', RiskLevel.low, 'Google Calendar app.'),
    'com.google.android.contacts': RiskInfo('Google Contacts', RiskLevel.medium, 'Install another contacts app if required.'),
    'com.google.android.youtube': RiskInfo('YouTube', RiskLevel.low, 'YouTube app.'),
    'com.google.android.apps.youtube.music': RiskInfo('YouTube Music', RiskLevel.low, 'YouTube Music app.'),
    'com.google.android.apps.tachyon': RiskInfo('Google Meet', RiskLevel.low, 'Google Meet app.'),
    'com.google.android.keep': RiskInfo('Google Keep', RiskLevel.low, 'Google Keep app.'),
    'com.google.android.apps.wellbeing': RiskInfo('Digital Wellbeing', RiskLevel.medium, 'Digital Wellbeing features will stop.'),
    'com.google.android.feedback': RiskInfo('Google Feedback', RiskLevel.low, 'Google feedback component.'),
    'com.google.android.videos': RiskInfo('Google TV', RiskLevel.low, 'Google TV app.'),
    'com.google.android.apps.magazines': RiskInfo('Google News', RiskLevel.low, 'Google News app.'),
    'com.google.android.apps.walletnfcrel': RiskInfo('Google Wallet', RiskLevel.medium, 'Wallet/contactless features will stop.'),
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

  static RiskInfo get(String packageName) {
    final known = exact[packageName];
    if (known != null) return known;
    if (packageName.startsWith('com.android.')) {
      return const RiskInfo('Android system component', RiskLevel.high, 'Review carefully before removal.');
    }
    if (packageName.startsWith('com.google.')) {
      return const RiskInfo('Google component', RiskLevel.medium, 'Review Google dependencies before removal.');
    }
    const prefixes = <String>[
      'com.samsung.', 'com.sec.', 'com.miui.', 'com.xiaomi.', 'com.oneplus.',
      'com.oplus.', 'com.coloros.', 'com.oppo.', 'com.heytap.', 'com.realme.',
      'com.vivo.', 'com.iqoo.',
    ];
    if (prefixes.any(packageName.startsWith)) {
      return RiskInfo(prettyName(packageName), RiskLevel.medium, 'OEM package not in the curated database.');
    }
    return RiskInfo(prettyName(packageName), RiskLevel.low, 'Third-party or uncategorized package.');
  }

  static String prettyName(String packageName) {
    final value = packageName.split('.').last.replaceAll('_', ' ');
    if (value.isEmpty) return packageName;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  static bool isProtected(String packageName) => get(packageName).level == RiskLevel.protected;
}

class PresetDatabase {
  static const Set<String> googleConsumer = {
    'com.android.chrome',
    'com.google.android.googlequicksearchbox',
    'com.google.android.apps.messaging',
    'com.google.android.gm',
    'com.google.android.apps.maps',
    'com.google.android.apps.photos',
    'com.google.android.apps.docs',
    'com.google.android.apps.nbu.files',
    'com.google.android.calendar',
    'com.google.android.contacts',
    'com.google.android.youtube',
    'com.google.android.apps.youtube.music',
    'com.google.android.apps.tachyon',
    'com.google.android.keep',
    'com.google.android.apps.wellbeing',
    'com.google.android.feedback',
    'com.google.android.videos',
    'com.google.android.apps.magazines',
    'com.google.android.apps.walletnfcrel',
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

  static const Set<String> recommendedSafe = {
    'com.android.chrome',
    'com.google.android.gm',
    'com.google.android.apps.maps',
    'com.google.android.apps.photos',
    'com.google.android.apps.docs',
    'com.google.android.apps.nbu.files',
    'com.google.android.calendar',
    'com.google.android.youtube',
    'com.google.android.apps.youtube.music',
    'com.google.android.apps.tachyon',
    'com.google.android.keep',
    'com.google.android.feedback',
    'com.google.android.videos',
    'com.google.android.apps.magazines',
    'com.samsung.android.app.spage',
    'com.samsung.android.app.tips',
    'com.samsung.android.game.gamehome',
    'com.samsung.android.game.gametools',
    'com.samsung.android.aremoji',
    'com.samsung.android.arzone',
    'com.samsung.android.kidsinstaller',
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
        value = value.endsWith(Platform.pathSeparator)
            ? '$value$part'
            : '$value${Platform.pathSeparator}$part';
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
      candidates.addAll([
        join(exeDir, ['platform-tools', 'adb.exe']),
        join(cwd, ['tools', 'platform-tools', 'adb.exe']),
        join(cwd, ['platform-tools', 'adb.exe']),
      ]);
    } else {
      candidates.addAll([
        join(exeDir, ['..', 'Resources', 'platform-tools', 'adb']),
        join(cwd, ['tools', 'platform-tools', 'adb']),
        '/opt/homebrew/bin/adb',
        '/usr/local/bin/adb',
      ]);
    }
    for (final candidate in candidates) {
      if (await File(candidate).exists()) {
        _cachedExecutable = candidate;
        return candidate;
      }
    }
    return 'adb';
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
      if (status != 'device') {
        output.add(DeviceInfo(id: id, status: status, model: 'Unknown', manufacturer: 'Unknown', androidVersion: 'Unknown', battery: 'Unknown'));
        continue;
      }
      output.add(await _details(id));
    }
    return output;
  }

  Future<DeviceInfo> _details(String id) async {
    Future<String> shell(List<String> command) async {
      final result = await run(['-s', id, 'shell', ...command]);
      return result.stdout.toString().trim();
    }
    final model = await shell(['getprop', 'ro.product.model']);
    final manufacturer = await shell(['getprop', 'ro.product.manufacturer']);
    final version = await shell(['getprop', 'ro.build.version.release']);
    final batteryDump = await shell(['dumpsys', 'battery']);
    final level = RegExp(r'level:\s*(\d+)').firstMatch(batteryDump)?.group(1);
    return DeviceInfo(
      id: id,
      status: 'device',
      model: model.isEmpty ? 'Android device' : model,
      manufacturer: manufacturer.isEmpty ? 'Unknown' : manufacturer,
      androidVersion: version.isEmpty ? 'Unknown' : version,
      battery: level == null ? 'Unknown' : '$level%',
    );
  }

  Future<List<String>> packages(String deviceId) async {
    final result = await run(['-s', deviceId, 'shell', 'pm', 'list', 'packages']);
    if (result.exitCode != 0) throw AdbException(result.stderr.toString().trim());
    final packages = result.stdout
        .toString()
        .split(RegExp(r'\r?\n'))
        .where((line) => line.startsWith('package:'))
        .map((line) => line.substring(8).trim())
        .where((value) => value.isNotEmpty)
        .toList()
      ..sort();
    return packages;
  }

  Future<void> backup(String deviceId, String packageName, Directory output) async {
    final pathResult = await run(['-s', deviceId, 'shell', 'pm', 'path', packageName]);
    if (pathResult.exitCode != 0) throw AdbException('Could not locate APK files for $packageName.');
    final paths = pathResult.stdout
        .toString()
        .split(RegExp(r'\r?\n'))
        .where((line) => line.startsWith('package:'))
        .map((line) => line.substring(8).trim())
        .where((value) => value.isNotEmpty)
        .toList();
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
    await File(join(output.path, ['metadata.json'])).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'package': packageName,
        'deviceId': deviceId,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<String?> uninstall(String deviceId, String packageName) async {
    final result = await run(['-s', deviceId, 'shell', 'pm', 'uninstall', '-k', '--user', '0', packageName]);
    final text = '${result.stdout}\n${result.stderr}'.trim();
    if (result.exitCode == 0 && text.toLowerCase().contains('success')) return null;
    return text.isEmpty ? 'Unknown uninstall failure.' : text;
  }

  Future<String?> restore(String deviceId, String packageName, Directory backupDir) async {
    final existing = await run(['-s', deviceId, 'shell', 'cmd', 'package', 'install-existing', '--user', '0', packageName]);
    final existingText = '${existing.stdout}\n${existing.stderr}'.toLowerCase();
    if (existing.exitCode == 0 && existingText.contains('installed')) return null;
    if (!await backupDir.exists()) return 'No APK backup is available.';
    final apks = await backupDir
        .list()
        .where((entry) => entry is File && entry.path.toLowerCase().endsWith('.apk'))
        .cast<File>()
        .map((file) => file.path)
        .toList();
    if (apks.isEmpty) return 'No APK backup is available.';
    final result = await run(['-s', deviceId, 'install-multiple', '-r', '-d', ...apks], timeout: const Duration(minutes: 5));
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
    final values = await directory
        .list()
        .where((entry) => entry is Directory)
        .cast<Directory>()
        .map((entry) => entry.path.split(Platform.pathSeparator).last)
        .toList();
    values.sort();
    return values;
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AdbService _adb = AdbService();
  final BackupStore _backups = BackupStore();
  final Set<String> _selected = <String>{};
  List<DeviceInfo> _devices = <DeviceInfo>[];
  DeviceInfo? _device;
  List<String> _packages = <String>[];
  List<String> _backupPackages = <String>[];
  String _search = '';
  String _filter = 'All';
  int _tab = 0;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshDevices());
  }

  List<String> get _visiblePackages {
    final query = _search.trim().toLowerCase();
    return _packages.where((packageName) {
      final risk = RiskDatabase.get(packageName);
      if (query.isNotEmpty && !packageName.toLowerCase().contains(query) && !risk.name.toLowerCase().contains(query)) return false;
      if (_filter == 'Google') return packageName.startsWith('com.google.') || packageName == 'com.android.chrome' || packageName == 'com.android.vending';
      if (_filter == 'Low risk') return risk.level == RiskLevel.low;
      if (_filter == 'Review') return risk.level == RiskLevel.medium || risk.level == RiskLevel.high || risk.level == RiskLevel.critical;
      return true;
    }).toList();
  }

  Future<void> _refreshDevices() async {
    setState(() { _loading = true; _error = null; });
    try {
      final devices = await _adb.devices();
      DeviceInfo? selected;
      if (_device != null) {
        for (final item in devices) {
          if (item.id == _device!.id && item.ready) selected = item;
        }
      }
      if (selected == null) {
        for (final item in devices) {
          if (item.ready) { selected = item; break; }
        }
      }
      if (!mounted) return;
      setState(() { _devices = devices; _device = selected; });
      if (selected != null) await _loadPackages();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPackages() async {
    final device = _device;
    if (device == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final packages = await _adb.packages(device.id);
      final backups = await _backups.packages(device);
      if (!mounted || _device?.id != device.id) return;
      setState(() {
        _packages = packages;
        _backupPackages = backups;
        _selected.removeWhere((packageName) => !packages.contains(packageName));
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseDevice(String? id) async {
    if (id == null) return;
    DeviceInfo? next;
    for (final item in _devices) {
      if (item.id == id) next = item;
    }
    if (next == null || !next.ready) return;
    setState(() { _device = next; _selected.clear(); _packages = <String>[]; });
    await _loadPackages();
  }

  void _applyPreset(Set<String> preset, String label, {String? filter}) {
    var added = 0;
    setState(() {
      for (final packageName in _packages) {
        if (preset.contains(packageName) && !RiskDatabase.isProtected(packageName) && _selected.add(packageName)) added++;
      }
      if (filter != null) _filter = filter;
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label: $added package(s) added. Review before removal.')));
  }

  int _presetCount(Set<String> preset) => _packages.where((packageName) => preset.contains(packageName) && !RiskDatabase.isProtected(packageName)).length;

  void _selectVisible() {
    setState(() {
      for (final packageName in _visiblePackages) {
        if (!RiskDatabase.isProtected(packageName)) _selected.add(packageName);
      }
    });
  }

  Future<void> _reviewAndRemove() async {
    final device = _device;
    if (device == null || _selected.isEmpty) return;
    final packages = _selected.toList()..sort();
    final dangerous = packages.where((packageName) {
      final level = RiskDatabase.get(packageName).level;
      return level == RiskLevel.high || level == RiskLevel.critical;
    }).toList();
    var backup = true;
    final controller = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final enabled = dangerous.isEmpty || controller.text.trim() == 'CONFIRM';
          return AlertDialog(
            title: Text('Remove ${packages.length} selected app(s)?'),
            content: SizedBox(
              width: 680,
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Packages are removed only for Android user 0. Presets never bypass this review screen.'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Back up APK files first'),
                    subtitle: const Text('If backup fails, that package will not be removed.'),
                    value: backup,
                    onChanged: (value) => setLocalState(() => backup = value),
                  ),
                  if (dangerous.isNotEmpty) ...[
                    Text('${dangerous.length} High/Critical package(s) selected. Type CONFIRM:', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextField(controller: controller, onChanged: (_) => setLocalState(() {}), decoration: const InputDecoration(hintText: 'CONFIRM')),
                    const SizedBox(height: 12),
                  ],
                  const Text('Selected packages', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: packages.length,
                      itemBuilder: (context, index) {
                        final packageName = packages[index];
                        final risk = RiskDatabase.get(packageName);
                        return ListTile(dense: true, title: Text(risk.name), subtitle: Text(packageName), trailing: _riskBadge(risk.level));
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
              FilledButton(onPressed: enabled ? () => Navigator.pop(dialogContext, true) : null, child: Text(backup ? 'Backup & remove' : 'Remove')),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (approved == true) await _removeBatch(device, packages, backup);
  }

  Future<void> _removeBatch(DeviceInfo device, List<String> packages, bool backup) async {
    setState(() => _busy = true);
    var succeeded = 0;
    final failures = <String, String>{};
    final progress = ValueNotifier<String>('Starting…');
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Removing selected apps'),
          content: SizedBox(width: 520, child: ValueListenableBuilder<String>(valueListenable: progress, builder: (context, value, child) => Column(mainAxisSize: MainAxisSize.min, children: [const LinearProgressIndicator(), const SizedBox(height: 18), Text(value)]))),
        ),
      ),
    ));
    for (var index = 0; index < packages.length; index++) {
      final packageName = packages[index];
      try {
        if (backup) {
          progress.value = '${index + 1}/${packages.length}: backing up $packageName';
          await _adb.backup(device.id, packageName, _backups.packageDir(device, packageName));
        }
        progress.value = '${index + 1}/${packages.length}: removing $packageName';
        final error = await _adb.uninstall(device.id, packageName);
        if (error == null) {
          succeeded++;
        } else {
          failures[packageName] = error;
        }
      } catch (error) {
        failures[packageName] = error.toString();
      }
    }
    progress.dispose();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() { _busy = false; _selected.clear(); });
    await _loadPackages();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk removal results'),
        content: SizedBox(
          width: 620,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$succeeded removed. ${failures.length} failed.'),
              if (failures.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(shrinkWrap: true, children: failures.entries.map((entry) => ListTile(title: Text(entry.key), subtitle: Text(entry.value))).toList()),
                ),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
      ),
    );
  }

  Future<void> _restore(String packageName) async {
    final device = _device;
    if (device == null) return;
    setState(() => _busy = true);
    String? error;
    try {
      error = await _adb.restore(device.id, packageName, _backups.packageDir(device, packageName));
    } catch (caught) {
      error = caught.toString();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$packageName restored.')));
      await _loadPackages();
    } else {
      showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Restore failed'), content: Text(error!), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.cleaning_services_rounded), SizedBox(width: 10), Text('Droid Purifier')]),
        actions: [
          if (_device != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: DropdownButton<String>(
                value: _device!.id,
                items: _devices.where((item) => item.ready).map((item) => DropdownMenuItem(value: item.id, child: Text('${item.manufacturer} ${item.model}'))).toList(),
                onChanged: _busy ? null : _chooseDevice,
              ),
            ),
          IconButton(onPressed: _busy ? null : _refreshDevices, tooltip: 'Refresh devices', icon: const Icon(Icons.refresh)),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              leading: const Icon(Icons.error_outline, color: Colors.redAccent),
              actions: [TextButton(onPressed: () => setState(() => _error = null), child: const Text('DISMISS'))],
            ),
          Expanded(child: _device == null ? _emptyState() : _workspace()),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android, size: 72),
            const SizedBox(height: 18),
            const Text('Connect an Android device', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Enable USB debugging, connect the phone, and approve the RSA prompt. ADB is bundled with release builds.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _loading ? null : _refreshDevices, icon: const Icon(Icons.refresh), label: const Text('Detect devices')),
            if (_devices.any((item) => !item.ready)) ...[
              const SizedBox(height: 16),
              ..._devices.where((item) => !item.ready).map((item) => Text('${item.id}: ${item.status}', style: const TextStyle(color: Colors.orangeAccent))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _workspace() {
    final device = _device!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
          child: Row(
            children: [
              Text('${device.manufacturer} ${device.model}'),
              const SizedBox(width: 18),
              Text('Android ${device.androidVersion}'),
              const SizedBox(width: 18),
              Text('Battery ${device.battery}'),
              const Spacer(),
              SegmentedButton<int>(
                segments: const [ButtonSegment(value: 0, icon: Icon(Icons.apps), label: Text('Debloat')), ButtonSegment(value: 1, icon: Icon(Icons.restore), label: Text('Restore'))],
                selected: {_tab},
                onSelectionChanged: _busy ? null : (value) => setState(() => _tab = value.first),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _tab == 0 ? _debloatView() : _restoreView()),
      ],
    );
  }

  Widget _debloatView() {
    final visible = _visiblePackages;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Installed apps', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), Text('Select several packages directly, or use a preset and review it before removal.')])),
              if (_selected.isNotEmpty) FilledButton.icon(onPressed: _busy ? null : _reviewAndRemove, icon: const Icon(Icons.delete_sweep), label: Text('Review & remove (${_selected.length})')),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _presetButton('Recommended Safe Debloat', '${_presetCount(PresetDatabase.recommendedSafe)} matches', Icons.verified_user_outlined, () => _applyPreset(PresetDatabase.recommendedSafe, 'Recommended Safe Debloat')),
              _presetButton('Remove Google Apps', '${_presetCount(PresetDatabase.googleConsumer)} matches • excludes Play Services / GSF / Play Store', Icons.g_mobiledata, () => _applyPreset(PresetDatabase.googleConsumer, 'Google apps', filter: 'Google')),
              _presetButton('Manufacturer Bloatware', '${_presetCount(PresetDatabase.manufacturerBloat)} matches • Samsung / Xiaomi / OPPO / realme', Icons.factory_outlined, () => _applyPreset(PresetDatabase.manufacturerBloat, 'Manufacturer Bloatware')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: TextField(onChanged: (value) => setState(() => _search = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search package or app name', border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _filter,
                items: const ['All', 'Google', 'Low risk', 'Review'].map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                onChanged: _busy ? null : (value) => setState(() => _filter = value ?? 'All'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(onPressed: _busy ? null : _selectVisible, child: Text('Select visible (${visible.where((item) => !RiskDatabase.isProtected(item)).length})')),
              TextButton(onPressed: _busy || _selected.isEmpty ? null : () => setState(() => _selected.clear()), child: const Text('Clear')),
            ],
          ),
          const SizedBox(height: 8),
          Text('${visible.length} shown • ${_packages.length} installed • ${_selected.length} selected'),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final packageName = visible[index];
                        final risk = RiskDatabase.get(packageName);
                        final protected = risk.level == RiskLevel.protected;
                        return CheckboxListTile(
                          value: _selected.contains(packageName),
                          onChanged: protected || _busy ? null : (_) => setState(() => _selected.contains(packageName) ? _selected.remove(packageName) : _selected.add(packageName)),
                          title: Text(risk.name),
                          subtitle: Text('$packageName\n${risk.note}'),
                          secondary: _riskBadge(risk.level),
                          isThreeLine: true,
                          controlAffinity: ListTileControlAffinity.leading,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _presetButton(String title, String subtitle, IconData icon, VoidCallback onPressed) {
    return SizedBox(
      width: 360,
      child: OutlinedButton(
        onPressed: _busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [Icon(icon), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), Text(subtitle, style: const TextStyle(fontSize: 12))]))]),
        ),
      ),
    );
  }

  Widget _restoreView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Restore', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Restore packages using install-existing first, with local APK backups as fallback.'),
          const SizedBox(height: 16),
          Expanded(
            child: _backupPackages.isEmpty
                ? const Center(child: Text('No local package backups found for this device.'))
                : Card(
                    child: ListView.separated(
                      itemCount: _backupPackages.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final packageName = _backupPackages[index];
                        return ListTile(
                          title: Text(RiskDatabase.get(packageName).name),
                          subtitle: Text(packageName),
                          trailing: FilledButton.tonal(onPressed: _busy ? null : () => _restore(packageName), child: const Text('Restore')),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _riskBadge(RiskLevel level) {
    final label = switch (level) {
      RiskLevel.low => 'LOW',
      RiskLevel.medium => 'MEDIUM',
      RiskLevel.high => 'HIGH',
      RiskLevel.critical => 'CRITICAL',
      RiskLevel.protected => 'PROTECTED',
    };
    final color = switch (level) {
      RiskLevel.low => Colors.greenAccent,
      RiskLevel.medium => Colors.amberAccent,
      RiskLevel.high => Colors.orangeAccent,
      RiskLevel.critical => Colors.redAccent,
      RiskLevel.protected => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
