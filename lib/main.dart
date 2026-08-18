import 'dart:async';

import 'package:flutter/material.dart';

import 'adb_service.dart';
import 'package_policy.dart';
import 'session_store.dart';

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
        visualDensity: VisualDensity.compact,
      ),
      home: const HomePage(),
    );
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
  final SessionStore _sessionStore = SessionStore();
  final Set<String> _selected = <String>{};

  List<DeviceInfo> _devices = <DeviceInfo>[];
  DeviceInfo? _device;
  PackageInventory? _inventory;
  SafetySnapshot? _snapshot;
  List<RemovalSession> _history = <RemovalSession>[];
  List<String> _backupPackages = <String>[];

  int _section = 0;
  String _search = '';
  String _filter = 'All';
  String? _activePreset;
  bool _expertMode = false;
  bool _loading = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refreshDevices());
  }

  List<String> get _packages => _inventory?.packages ?? const <String>[];

  PackageInfo _info(String packageName) {
    final inventory = _inventory;
    final snapshot = _snapshot;
    final device = _device;
    if (inventory == null || snapshot == null || device == null) {
      return PackageInfo(
        packageName,
        SafetyClass.unknown,
        'Package has not been analysed yet.',
      );
    }

    return PackagePolicy.classify(
      packageName,
      isSystem: inventory.systemPackages.contains(packageName),
      isApex: inventory.apexPackages.contains(packageName),
      isOverlay: snapshot.overlayPackages.contains(packageName),
      isCriticalRole: snapshot.criticalRolePackages.contains(packageName),
      isCurrentWebView: snapshot.currentWebView == packageName,
      setupComplete: device.setupComplete,
    );
  }

  bool _canNormallySelect(String packageName) => !_info(packageName).protected;

  List<String> get _sectionPackages {
    if (_section == 0) {
      return _packages.where(PackagePolicy.isGoogleRelated).toList();
    }
    return _packages;
  }

  List<String> get _visiblePackages {
    final query = _search.trim().toLowerCase();
    return _sectionPackages.where((packageName) {
      final info = _info(packageName);
      if (query.isNotEmpty &&
          !packageName.toLowerCase().contains(query) &&
          !info.name.toLowerCase().contains(query) &&
          !info.note.toLowerCase().contains(query)) {
        return false;
      }

      switch (_filter) {
        case 'Known removable':
          return info.safety == SafetyClass.knownRemovable;
        case 'Feature dependent':
          return info.safety == SafetyClass.featureDependent;
        case 'Unknown':
          return info.safety == SafetyClass.unknown;
        case 'Protected':
          return info.safety == SafetyClass.protected;
        case 'System':
          return _inventory?.systemPackages.contains(packageName) ?? false;
        case 'User apps':
          return !(_inventory?.systemPackages.contains(packageName) ?? false);
        default:
          return true;
      }
    }).toList();
  }

  int _countClass(SafetyClass safety, {bool googleOnly = false}) {
    final source = googleOnly ? _sectionPackages : _packages;
    return source.where((packageName) => _info(packageName).safety == safety).length;
  }

  int get _recommendedCount => _packages.where((packageName) {
        return PackagePolicy.recommendedCandidate(_info(packageName));
      }).length;

  int get _fullCount => _packages.where((packageName) {
        return PackagePolicy.fullCandidate(_info(packageName));
      }).length;

  int get _manualGoogleCount => _packages.where((packageName) {
        final info = _info(packageName);
        return PackagePolicy.isGoogleRelated(packageName) &&
            info.deGoogleTier == DeGoogleTier.manual &&
            !info.protected;
      }).length;

  Future<void> _refreshDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final devices = await _adb.devices();
      DeviceInfo? selected;
      if (_device != null) {
        for (final item in devices) {
          if (item.id == _device!.id && item.ready) selected = item;
        }
      }
      selected ??= devices.where((item) => item.ready).firstOrNull;

      if (!mounted) return;
      setState(() {
        _devices = devices;
        _device = selected;
      });
      if (selected != null) await _analyseDevice(silent: true);
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

    setState(() {
      _device = next;
      _inventory = null;
      _snapshot = null;
      _selected.clear();
      _activePreset = null;
      _expertMode = false;
    });
    await _analyseDevice(silent: true);
  }

  Future<void> _analyseDevice({bool silent = false}) async {
    final device = _device;
    if (device == null) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final inventory = await _adb.packageInventory(
        device.id,
        sdkInt: device.sdkInt,
      );
      final snapshot = await _adb.safetySnapshot(device, inventory);
      final history = await _sessionStore.list(device);
      final backups = await _backups.packages(device);

      if (!mounted || _device?.id != device.id) return;
      setState(() {
        _inventory = inventory;
        _snapshot = snapshot;
        _history = history;
        _backupPackages = backups;
        _selected.removeWhere((packageName) {
          if (!inventory.packages.contains(packageName)) return true;
          return !_expertMode && _info(packageName).protected;
        });
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  void _replaceSelection(
    Iterable<String> packages, {
    required String preset,
  }) {
    setState(() {
      _selected
        ..clear()
        ..addAll(packages.where(_canNormallySelect));
      _activePreset = preset;
    });
  }

  void _applyRecommended() {
    _replaceSelection(
      _packages.where((packageName) {
        return PackagePolicy.recommendedCandidate(_info(packageName));
      }),
      preset: 'Recommended De-Google',
    );
  }

  void _applyFull() {
    _replaceSelection(
      _packages.where((packageName) {
        return PackagePolicy.fullCandidate(_info(packageName));
      }),
      preset: 'Full De-Google',
    );
  }

  void _selectKnownVisible() {
    setState(() {
      _selected.addAll(
        _visiblePackages.where((packageName) {
          final info = _info(packageName);
          return PackagePolicy.knownRemovableCandidate(info) &&
              _canNormallySelect(packageName);
        }),
      );
      _activePreset = null;
    });
  }

  Future<void> _togglePackage(String packageName) async {
    final info = _info(packageName);
    if (info.protected && !_expertMode) {
      await _showProtectedExplanation(packageName);
      return;
    }

    setState(() {
      if (_selected.contains(packageName)) {
        _selected.remove(packageName);
      } else {
        _selected.add(packageName);
      }
      _activePreset = null;
    });
  }

  void _clearSelection() {
    setState(() {
      _selected.clear();
      _activePreset = null;
    });
  }

  Future<void> _showProtectedExplanation(String packageName) async {
    final info = _info(packageName);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Protected on this device'),
        content: Text('${info.name}\n\n${info.note}\n\nNormal mode will not remove this package.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _setExpertMode(bool value) async {
    if (!value) {
      setState(() {
        _expertMode = false;
        _selected.removeWhere((packageName) => _info(packageName).protected);
      });
      return;
    }

    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final enabled = controller.text.trim() == 'EXPERT';
          return AlertDialog(
            title: const Text('Enable Expert Mode?'),
            content: SizedBox(
              width: 560,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expert Mode allows manual selection of packages Droid Purifier protects. Removing the wrong package can make Android unusable or prevent it from booting normally.',
                  ),
                  const SizedBox(height: 14),
                  const Text('Type EXPERT to continue.'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    onChanged: (_) => setLocalState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'EXPERT',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: enabled
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: const Text('Enable'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (accepted == true && mounted) setState(() => _expertMode = true);
  }

  Map<SafetyClass, int> _selectionCounts() {
    final result = <SafetyClass, int>{
      SafetyClass.knownRemovable: 0,
      SafetyClass.featureDependent: 0,
      SafetyClass.unknown: 0,
      SafetyClass.protected: 0,
    };
    for (final packageName in _selected) {
      final safety = _info(packageName).safety;
      result[safety] = (result[safety] ?? 0) + 1;
    }
    return result;
  }

  List<String> _readinessWarnings() {
    final snapshot = _snapshot;
    if (snapshot == null) return const [];
    final warnings = <String>[];

    if (snapshot.currentBrowser != null &&
        _selected.contains(snapshot.currentBrowser)) {
      warnings.add('Your current browser is selected. Install another browser first.');
    }
    if (_selected.contains('com.android.vending')) {
      warnings.add('Google Play Store is selected. Keep another trusted app-installation source available.');
    }
    if (_selected.contains('com.google.android.gms') ||
        _selected.contains('com.google.android.gsf')) {
      warnings.add('Apps that depend on Play Services, FCM, Google APIs or Play Integrity may stop working.');
    }
    if (_selected.contains('com.google.android.tts')) {
      warnings.add('Google Text-to-Speech is selected. Install another TTS engine if you need speech output.');
    }
    if (_selected.contains('com.google.android.apps.maps')) {
      warnings.add('Google Maps is selected. Keep another maps/navigation app if you need navigation.');
    }
    if (_selected.contains('com.google.android.projection.gearhead')) {
      warnings.add('Android Auto is selected and will no longer work.');
    }
    return warnings;
  }

  Future<void> _showAnalysis() async {
    if (_inventory == null || _snapshot == null || _device == null) return;
    await _analyseDevice(silent: false);
    if (!mounted) return;

    final googleKnown = _countClass(SafetyClass.knownRemovable, googleOnly: true);
    final googleFeature = _countClass(SafetyClass.featureDependent, googleOnly: true);
    final googleUnknown = _countClass(SafetyClass.unknown, googleOnly: true);
    final googleProtected = _countClass(SafetyClass.protected, googleOnly: true);

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone analysis'),
        content: SizedBox(
          width: 660,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${_device!.manufacturer} ${_device!.model} • Android ${_device!.androidVersion}${_device!.sdkInt == null ? '' : ' • API ${_device!.sdkInt}'}'),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _summaryChip('$googleKnown', 'Known removable', Colors.greenAccent),
                  _summaryChip('$googleFeature', 'Feature dependent', Colors.amberAccent),
                  _summaryChip('$googleUnknown', 'Unknown', Colors.orangeAccent),
                  _summaryChip('$googleProtected', 'Protected', Colors.lightBlueAccent),
                ],
              ),
              const SizedBox(height: 14),
              Text('${_inventory!.apexPackages.length} APEX/Mainline package(s) detected'),
              Text('${_snapshot!.overlayPackages.length} runtime overlay package(s) detected'),
              Text('${_snapshot!.criticalRolePackages.length} current critical-role package(s) protected'),
              const SizedBox(height: 12),
              const Text(
                'Droid Purifier never treats an unknown system package as safe. Unknown packages are left for manual review.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              unawaited(_exportReport());
            },
            icon: const Icon(Icons.file_download_outlined),
            label: const Text('Export report'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportReport() async {
    final device = _device;
    final inventory = _inventory;
    final snapshot = _snapshot;
    if (device == null || inventory == null || snapshot == null) return;

    final packages = <Map<String, Object?>>[];
    for (final packageName in inventory.packages) {
      final info = _info(packageName);
      packages.add({
        'package': packageName,
        'name': info.name,
        'classification': info.safety.name,
        'description': info.note,
        'system': inventory.systemPackages.contains(packageName),
        'apex': inventory.apexPackages.contains(packageName),
        'overlay': snapshot.overlayPackages.contains(packageName),
        'criticalRole': snapshot.criticalRolePackages.contains(packageName),
        'currentWebView': snapshot.currentWebView == packageName,
      });
    }

    final file = await _sessionStore.exportReport(device, {
      'generatedAt': DateTime.now().toIso8601String(),
      'device': {
        'id': device.id,
        'manufacturer': device.manufacturer,
        'model': device.model,
        'androidVersion': device.androidVersion,
        'sdkInt': device.sdkInt,
      },
      'roles': {
        'launcher': snapshot.currentLauncher,
        'keyboard': snapshot.currentIme,
        'dialer': snapshot.currentDialer,
        'sms': snapshot.currentSms,
        'browser': snapshot.currentBrowser,
        'webView': snapshot.currentWebView,
      },
      'packages': packages,
    });

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Analysis exported'),
        content: SelectableText(file.path),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _reviewAndRemove() async {
    final device = _device;
    if (device == null || _selected.isEmpty) return;

    // Re-scan immediately before removal. A role/provider could have changed
    // after the initial analysis.
    setState(() => _busy = true);
    await _analyseDevice(silent: true);
    if (!mounted) return;
    setState(() => _busy = false);

    if (!_expertMode) {
      final newlyProtected = _selected.where((packageName) => _info(packageName).protected).toList();
      if (newlyProtected.isNotEmpty) {
        setState(() => _selected.removeAll(newlyProtected));
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Selection updated for safety'),
            content: Text('${newlyProtected.length} package(s) became protected after the latest device scan and were removed from the selection.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    }

    if (_selected.isEmpty) return;
    final packages = _selected.toList()..sort();
    final counts = _selectionCounts();
    final warnings = _readinessWarnings();
    final protectedCount = counts[SafetyClass.protected] ?? 0;
    final unknownCount = counts[SafetyClass.unknown] ?? 0;
    final includesGoogleFramework = packages.any((packageName) =>
        packageName == 'com.google.android.gms' ||
        packageName == 'com.google.android.gsf' ||
        packageName == 'com.android.vending');

    String requiredPhrase = '';
    if (protectedCount > 0) {
      requiredPhrase = 'FORCE';
    } else if (unknownCount > 0) {
      requiredPhrase = 'REVIEW';
    } else if (includesGoogleFramework) {
      requiredPhrase = 'DEGOOGLE';
    }

    var backup = true;
    final controller = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final enabled = requiredPhrase.isEmpty ||
              controller.text.trim() == requiredPhrase;
          return AlertDialog(
            title: Text('Review ${packages.length} package(s)'),
            content: SizedBox(
              width: 760,
              height: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _summaryChip('${counts[SafetyClass.knownRemovable]}', 'Known removable', Colors.greenAccent),
                      _summaryChip('${counts[SafetyClass.featureDependent]}', 'Feature dependent', Colors.amberAccent),
                      _summaryChip('$unknownCount', 'Unknown', Colors.orangeAccent),
                      _summaryChip('$protectedCount', 'Protected / Expert', Colors.lightBlueAccent),
                    ],
                  ),
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Before you continue', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          ...warnings.map((warning) => Text('• $warning')),
                        ],
                      ),
                    ),
                  ],
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Back up APK files first'),
                    subtitle: const Text('Backups help recovery but cannot guarantee recovery from a non-booting phone.'),
                    value: backup,
                    onChanged: (value) => setLocalState(() => backup = value),
                  ),
                  if (requiredPhrase.isNotEmpty) ...[
                    Text(
                      'Type $requiredPhrase to continue:',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      onChanged: (_) => setLocalState(() {}),
                      decoration: InputDecoration(
                        hintText: requiredPhrase,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const Divider(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: packages.length,
                      itemBuilder: (context, index) {
                        final packageName = packages[index];
                        final info = _info(packageName);
                        return ListTile(
                          dense: true,
                          title: Text(info.name),
                          subtitle: Text(packageName),
                          trailing: _classBadge(info.safety),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: enabled
                    ? () => Navigator.pop(dialogContext, true)
                    : null,
                child: Text(backup ? 'Backup & remove' : 'Remove'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (approved == true) {
      await _removeBatch(device, packages, backup);
    }
  }

  Future<void> _removeBatch(
    DeviceInfo device,
    List<String> packages,
    bool backup,
  ) async {
    setState(() => _busy = true);
    final removed = <String>[];
    final failures = <String, String>{};
    final progress = ValueNotifier<String>('Starting…');

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Removing selected packages'),
            content: SizedBox(
              width: 520,
              child: ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (context, value, child) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(value),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    for (var index = 0; index < packages.length; index++) {
      final packageName = packages[index];
      try {
        if (!_expertMode && _info(packageName).protected) {
          failures[packageName] = 'Blocked by the latest safety scan.';
          continue;
        }
        if (backup) {
          progress.value = '${index + 1}/${packages.length}: backing up $packageName';
          await _adb.backup(
            device.id,
            packageName,
            _backups.packageDir(device, packageName),
            sdkInt: device.sdkInt,
          );
        }
        progress.value = '${index + 1}/${packages.length}: removing $packageName';
        final error = await _adb.uninstall(device.id, packageName);
        if (error == null) {
          removed.add(packageName);
        } else {
          failures[packageName] = error;
        }
      } catch (error) {
        failures[packageName] = error.toString();
      }
    }

    HealthReport health;
    progress.value = 'Running post-removal health check…';
    try {
      health = await _adb.healthCheck(device);
    } catch (error) {
      health = HealthReport([
        HealthCheckItem('Health check', false, error.toString()),
      ]);
    }

    final now = DateTime.now();
    final session = RemovalSession(
      id: 'session-${now.millisecondsSinceEpoch}',
      createdAt: now,
      preset: _activePreset ?? 'Manual selection',
      requestedPackages: List<String>.from(packages),
      removedPackages: removed,
      failures: failures,
      backupEnabled: backup,
      healthPassed: health.passed,
    );
    await _sessionStore.save(device, session);

    progress.dispose();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() {
      _busy = false;
      _selected.clear();
      _activePreset = null;
    });
    await _analyseDevice(silent: true);
    if (!mounted) return;

    await _showRemovalResult(removed, failures, health);
  }

  Future<void> _showRemovalResult(
    List<String> removed,
    Map<String, String> failures,
    HealthReport health,
  ) async {
    final protectedGoogle = _sectionPackages.where((packageName) {
      return _info(packageName).protected;
    }).length;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(health.passed ? 'Removal complete' : 'Removal complete — check device'),
        content: SizedBox(
          width: 680,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${removed.length} removed • ${failures.length} failed/skipped • $protectedGoogle Google-namespaced Android-core package(s) intentionally retained'),
              const SizedBox(height: 12),
              const Text('Post-removal health check', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...health.items.map(
                (item) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.ok ? Icons.check_circle_outline : Icons.error_outline,
                    color: item.ok ? Colors.greenAccent : Colors.redAccent,
                  ),
                  title: Text(item.label),
                  subtitle: Text(item.detail),
                ),
              ),
              if (failures.isNotEmpty) ...[
                const Divider(),
                Text('${failures.length} package(s) were not removed. They remain available on the device.'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
          FilledButton.tonal(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _section = 2);
            },
            child: const Text('Open Restore'),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreSession(RemovalSession session) async {
    final device = _device;
    if (device == null || session.removedPackages.isEmpty) return;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore this removal session?'),
        content: Text('Droid Purifier will attempt to restore ${session.removedPackages.length} package(s).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore')),
        ],
      ),
    );
    if (approved != true) return;

    setState(() => _busy = true);
    final progress = ValueNotifier<String>('Starting…');
    final failures = <String, String>{};
    var restored = 0;

    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Restoring session'),
            content: SizedBox(
              width: 520,
              child: ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (context, value, child) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const LinearProgressIndicator(),
                    const SizedBox(height: 14),
                    Text(value),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < session.removedPackages.length; i++) {
      final packageName = session.removedPackages[i];
      progress.value = '${i + 1}/${session.removedPackages.length}: restoring $packageName';
      try {
        final error = await _adb.restore(
          device.id,
          packageName,
          _backups.packageDir(device, packageName),
        );
        if (error == null) {
          restored++;
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
    setState(() => _busy = false);
    await _analyseDevice(silent: true);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore complete'),
        content: Text('$restored restored • ${failures.length} failed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  Future<void> _restoreSingle(String packageName) async {
    final device = _device;
    if (device == null) return;
    setState(() => _busy = true);
    String? error;
    try {
      error = await _adb.restore(
        device.id,
        packageName,
        _backups.packageDir(device, packageName),
      );
    } catch (caught) {
      error = caught.toString();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) {
      await _analyseDevice(silent: true);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error == null ? '$packageName restored.' : error)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 54,
        title: const Row(
          children: [
            Icon(Icons.shield_outlined),
            SizedBox(width: 9),
            Text('Droid Purifier'),
            SizedBox(width: 10),
            _OfflineBadge(),
          ],
        ),
        actions: [
          if (_device != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: DropdownButton<String>(
                value: _device!.id,
                items: _devices
                    .where((item) => item.ready)
                    .map(
                      (item) => DropdownMenuItem(
                        value: item.id,
                        child: Text('${item.manufacturer} ${item.model}'),
                      ),
                    )
                    .toList(),
                onChanged: _busy ? null : _chooseDevice,
              ),
            ),
          IconButton(
            onPressed: _busy ? null : _refreshDevices,
            tooltip: 'Refresh device',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              leading: const Icon(Icons.error_outline, color: Colors.redAccent),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('DISMISS'),
                ),
              ],
            ),
          Expanded(
            child: _device == null ? _emptyState() : _workspace(),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android, size: 68),
            const SizedBox(height: 16),
            const Text(
              'Connect an Android device',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enable USB debugging and approve the RSA prompt. Droid Purifier works locally through bundled ADB.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _refreshDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Detect device'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _workspace() {
    final device = _device!;
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              Text(
                '${device.manufacturer} ${device.model}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 14),
              Text('Android ${device.androidVersion}${device.sdkInt == null ? '' : ' • API ${device.sdkInt}'}'),
              const SizedBox(width: 14),
              Text('${device.battery} battery'),
              const Spacer(),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('De-Google')),
                  ButtonSegment(value: 1, label: Text('Apps')),
                  ButtonSegment(value: 2, label: Text('Restore')),
                ],
                selected: {_section},
                onSelectionChanged: _busy
                    ? null
                    : (value) => setState(() {
                          _section = value.first;
                          _filter = 'All';
                          _search = '';
                        }),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (_section) {
            0 => _deGoogleView(),
            1 => _appsView(),
            _ => _restoreView(),
          },
        ),
      ],
    );
  }

  Widget _deGoogleView() {
    return _packageWorkspace(
      title: 'De-Google',
      subtitle: 'Google apps and services only. Android core stays protected.',
      topControls: Row(
        children: [
          Expanded(
            child: _presetButton(
              active: _activePreset == 'Recommended De-Google',
              icon: Icons.verified_user_outlined,
              title: 'Recommended',
              count: _recommendedCount,
              tooltip: 'Known removable Google apps only. Keeps Play Services, GSF and Play Store.',
              onPressed: _applyRecommended,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _presetButton(
              active: _activePreset == 'Full De-Google',
              icon: Icons.gpp_good_outlined,
              title: 'Full De-Google',
              count: _fullCount,
              tooltip: 'Adds Play Services, GSF, Play Store and other feature-dependent Google services. Critical Android roles remain protected.',
              onPressed: _applyFull,
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _loading ? null : _showAnalysis,
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: const Text('Analyze'),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: _showWhyGoogleRemains,
            child: const Text('Why Google packages remain?'),
          ),
        ],
      ),
      statusLine: '${_countClass(SafetyClass.knownRemovable, googleOnly: true)} known removable • ${_countClass(SafetyClass.featureDependent, googleOnly: true)} feature dependent • ${_countClass(SafetyClass.unknown, googleOnly: true)} unknown • ${_countClass(SafetyClass.protected, googleOnly: true)} protected • $_manualGoogleCount manual-review',
      showExpert: false,
    );
  }

  Widget _appsView() {
    return _packageWorkspace(
      title: 'All Apps',
      subtitle: 'Manual package manager. Unknown packages are never called safe.',
      topControls: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _loading ? null : _showAnalysis,
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: const Text('Analyze phone'),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _visiblePackages.any((packageName) =>
                    PackagePolicy.knownRemovableCandidate(_info(packageName)))
                ? _selectKnownVisible
                : null,
            icon: const Icon(Icons.checklist, size: 18),
            label: const Text('Select known removable'),
          ),
          const Spacer(),
          const Text('Expert Mode'),
          const SizedBox(width: 6),
          Switch(
            value: _expertMode,
            onChanged: _busy ? null : _setExpertMode,
          ),
        ],
      ),
      statusLine: '${_countClass(SafetyClass.knownRemovable)} known removable • ${_countClass(SafetyClass.featureDependent)} feature dependent • ${_countClass(SafetyClass.unknown)} unknown • ${_countClass(SafetyClass.protected)} protected',
      showExpert: true,
    );
  }

  Widget _packageWorkspace({
    required String title,
    required String subtitle,
    required Widget topControls,
    required String statusLine,
    required bool showExpert,
  }) {
    final visible = _visiblePackages;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ),
              if (_selected.isNotEmpty)
                FilledButton.icon(
                  onPressed: _busy ? null : _reviewAndRemove,
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: Text('Review & remove (${_selected.length})'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          topControls,
          const SizedBox(height: 7),
          Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  statusLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Tooltip(
                message: 'Live safety scan: APEX/Mainline, runtime overlays, launcher, keyboard, dialer, SMS, accessibility and WebView can be protected dynamically.',
                child: const Icon(Icons.info_outline, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 19),
                      hintText: 'Search app or package',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: DropdownButton<String>(
                  value: _filter,
                  items: [
                    'All',
                    'Known removable',
                    'Feature dependent',
                    'Unknown',
                    'Protected',
                    if (_section == 1) 'System',
                    if (_section == 1) 'User apps',
                  ]
                      .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _filter = value ?? 'All'),
                ),
              ),
              const SizedBox(width: 6),
              TextButton(
                onPressed: _selected.isEmpty ? null : _clearSelection,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text('${visible.length} shown • ${_selected.length} selected', style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 5),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final packageName = visible[index];
                        final info = _info(packageName);
                        final protected = info.protected;
                        final selectable = !protected || _expertMode;
                        return ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                          minVerticalPadding: 3,
                          leading: Checkbox(
                            value: _selected.contains(packageName),
                            onChanged: selectable && !_busy
                                ? (_) => _togglePackage(packageName)
                                : null,
                          ),
                          title: Text(info.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            packageName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: _busy ? null : () => _togglePackage(packageName),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _classBadge(info.safety),
                              const SizedBox(width: 2),
                              Tooltip(
                                message: info.note,
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(Icons.info_outline, size: 17),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _restoreView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Restore', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              Text('${_history.length} removal session(s)', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _analyseDevice(silent: false),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Restore a complete removal session, or restore an individual package from a local APK backup.'),
          const SizedBox(height: 10),
          Expanded(
            child: _history.isEmpty && _backupPackages.isEmpty
                ? const Center(child: Text('No removal history or local backups for this device.'))
                : ListView(
                    children: [
                      ..._history.map(_sessionCard),
                      if (_backupPackages.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(2, 16, 2, 6),
                          child: Text('Individual backups', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        Card(
                          child: Column(
                            children: _backupPackages.map((packageName) {
                              return ListTile(
                                dense: true,
                                title: Text(_info(packageName).name),
                                subtitle: Text(packageName),
                                trailing: FilledButton.tonal(
                                  onPressed: _busy ? null : () => _restoreSingle(packageName),
                                  child: const Text('Restore'),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(RemovalSession session) {
    final localTime = session.createdAt.toLocal();
    final stamp = '${localTime.year}-${localTime.month.toString().padLeft(2, '0')}-${localTime.day.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    return Card(
      child: ExpansionTile(
        title: Text(session.preset),
        subtitle: Text('$stamp • ${session.removedPackages.length} removed • ${session.failures.length} failed • health ${session.healthPassed ? 'passed' : 'check needed'}'),
        trailing: FilledButton.tonal(
          onPressed: _busy || session.removedPackages.isEmpty
              ? null
              : () => _restoreSession(session),
          child: const Text('Restore session'),
        ),
        children: session.requestedPackages
            .map(
              (packageName) => ListTile(
                dense: true,
                title: Text(packageName),
                trailing: session.removedPackages.contains(packageName)
                    ? const Text('REMOVED')
                    : const Text('SKIPPED'),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _showWhyGoogleRemains() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Why can Google package names remain?'),
        content: const SizedBox(
          width: 620,
          child: Text(
            'A package name beginning with com.google does not always mean a Google consumer service. Some Google-certified Android builds use Google-namespaced implementations of Android system components such as Permission Controller, networking modules, DocumentsUI or Mainline modules.\n\nDroid Purifier keeps those packages when the live safety scan identifies them as Android core. This prevents “De-Google” from becoming “break Android.”',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
        ],
      ),
    );
  }

  Widget _presetButton({
    required bool active,
    required IconData icon,
    required String title,
    required int count,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final child = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19),
          const SizedBox(width: 7),
          Flexible(child: Text('$title ($count)', overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
    return Tooltip(
      message: tooltip,
      child: active
          ? FilledButton.tonal(onPressed: _busy ? null : onPressed, child: child)
          : OutlinedButton(onPressed: _busy ? null : onPressed, child: child),
    );
  }

  Widget _summaryChip(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text('$value  $label'),
    );
  }

  Widget _classBadge(SafetyClass safety) {
    final (label, color) = switch (safety) {
      SafetyClass.knownRemovable => ('KNOWN REMOVABLE', Colors.greenAccent),
      SafetyClass.featureDependent => ('FEATURE', Colors.amberAccent),
      SafetyClass.unknown => ('UNKNOWN', Colors.orangeAccent),
      SafetyClass.protected => ('PROTECTED', Colors.lightBlueAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'OFFLINE',
        style: TextStyle(fontSize: 9, color: Colors.greenAccent, fontWeight: FontWeight.bold),
      ),
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    for (final value in this) {
      return value;
    }
    return null;
  }
}
