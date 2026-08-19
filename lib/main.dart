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

  PackageMetadata _metadata(String packageName) {
    final inventory = _inventory;
    return inventory?.metadata[packageName] ?? PackageMetadata(
      packageName: packageName,
      label: packageName,
      versionName: '',
      versionCode: 0,
      sourceDir: '',
      installer: '',
      uid: -1,
      isSystem: inventory?.systemPackages.contains(packageName) ?? true,
      isUpdatedSystem: false,
      enabled: true,
      hasLauncher: false,
      privileged: false,
      deviceAdmin: false,
      requestedPermissions: const <String>{},
      servicePermissions: const <String>{},
    );
  }

  PackageInfo _info(String packageName) {
    final inventory = _inventory;
    final snapshot = _snapshot;
    final device = _device;
    if (inventory == null || snapshot == null || device == null) {
      return PackageInfo(name: packageName, category: AppCategory.unknownVendor, safety: SafetyClass.review, note: 'Package has not been analysed yet.');
    }
    return PackagePolicy.classify(
      packageName,
      device: device,
      metadata: _metadata(packageName),
      isApex: inventory.apexPackages.contains(packageName),
      isOverlay: snapshot.overlayPackages.contains(packageName),
      isCriticalRole: snapshot.criticalRolePackages.contains(packageName),
      isCurrentWebView: snapshot.currentWebView == packageName,
      setupComplete: device.setupComplete,
    );
  }

  bool _canNormallySelect(String packageName) => !_info(packageName).protected || _expertMode;

  List<String> get _sectionPackages => _section == 0 ? _packages.where(PackagePolicy.isGoogleRelated).toList() : _packages;

  List<String> get _visiblePackages {
    final query = _search.trim().toLowerCase();
    final values = _sectionPackages.where((packageName) {
      final info = _info(packageName);
      final meta = _metadata(packageName);
      if (query.isNotEmpty && !packageName.toLowerCase().contains(query) && !info.name.toLowerCase().contains(query) && !info.note.toLowerCase().contains(query) && !meta.installer.toLowerCase().contains(query)) return false;
      switch (_filter) {
        case 'User apps': return info.category == AppCategory.userApp;
        case 'Google': return info.category == AppCategory.googleApp;
        case 'OEM': return info.category == AppCategory.oemApp;
        case 'System': return info.category == AppCategory.system || info.category == AppCategory.unknownVendor || info.category == AppCategory.carrierApp;
        case 'Removable': return info.safety == SafetyClass.removable;
        case 'Caution': return info.safety == SafetyClass.caution;
        case 'Review': return info.safety == SafetyClass.review;
        case 'Protected': return info.safety == SafetyClass.protected;
        default: return true;
      }
    }).toList();
    values.sort((a, b) => _info(a).name.toLowerCase().compareTo(_info(b).name.toLowerCase()));
    return values;
  }

  int _count(SafetyClass safety, {bool googleOnly = false}) {
    final source = googleOnly ? _sectionPackages : _packages;
    return source.where((packageName) => _info(packageName).safety == safety).length;
  }

  int get _recommendedCount => _packages.where((p) => PackagePolicy.recommendedCandidate(_info(p))).length;
  int get _fullCount => _packages.where((p) => PackagePolicy.fullCandidate(_info(p))).length;

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
      selected ??= devices.where((item) => item.ready).firstOrNull;
      if (!mounted) return;
      setState(() { _devices = devices; _device = selected; });
      if (selected != null) await _analyseDevice(silent: true, enhanced: true);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseDevice(String? id) async {
    if (id == null) return;
    final next = _devices.where((item) => item.id == id && item.ready).firstOrNull;
    if (next == null) return;
    setState(() {
      _device = next;
      _inventory = null;
      _snapshot = null;
      _selected.clear();
      _activePreset = null;
      _expertMode = false;
    });
    await _analyseDevice(silent: true, enhanced: true);
  }

  Future<void> _analyseDevice({bool silent = false, bool enhanced = true}) async {
    final device = _device;
    if (device == null) return;
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final inventory = await _adb.packageInventory(device.id, sdkInt: device.sdkInt, enhanced: enhanced);
      final snapshot = await _adb.safetySnapshot(device, inventory);
      final history = await _sessionStore.list(device);
      final backups = await _backups.packages(device);
      if (!mounted || _device?.id != device.id) return;
      setState(() {
        _inventory = inventory;
        _snapshot = snapshot;
        _history = history;
        _backupPackages = backups;
        _selected.removeWhere((packageName) => !inventory.packages.contains(packageName) || (!_expertMode && _info(packageName).protected));
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (!silent && mounted) setState(() => _loading = false);
    }
  }

  void _replaceSelection(Iterable<String> packages, {required String preset}) {
    setState(() {
      _selected..clear()..addAll(packages.where(_canNormallySelect));
      _activePreset = preset;
    });
  }

  void _applyRecommended() => _replaceSelection(_packages.where((p) => PackagePolicy.recommendedCandidate(_info(p))), preset: 'Recommended De-Google');
  void _applyFull() => _replaceSelection(_packages.where((p) => PackagePolicy.fullCandidate(_info(p))), preset: 'Full De-Google');

  void _selectRemovableVisible() {
    setState(() {
      _selected.addAll(_visiblePackages.where((p) => _info(p).safety == SafetyClass.removable && _canNormallySelect(p)));
      _activePreset = null;
    });
  }

  Future<void> _togglePackage(String packageName) async {
    final info = _info(packageName);
    if (info.protected && !_expertMode) {
      await _showPackageDetails(packageName);
      return;
    }
    setState(() {
      _selected.contains(packageName) ? _selected.remove(packageName) : _selected.add(packageName);
      _activePreset = null;
    });
  }

  void _clearSelection() => setState(() { _selected.clear(); _activePreset = null; });

  Future<void> _setExpertMode(bool value) async {
    if (!value) {
      setState(() { _expertMode = false; _selected.removeWhere((p) => _info(p).protected); });
      return;
    }
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('Enable Expert Mode?'),
          content: SizedBox(width: 560, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Expert Mode allows protected packages to be selected manually. Removing the wrong package can make Android unusable.'),
            const SizedBox(height: 12),
            const Text('Type EXPERT to continue.'),
            const SizedBox(height: 8),
            TextField(controller: controller, onChanged: (_) => setLocalState(() {}), decoration: const InputDecoration(hintText: 'EXPERT', isDense: true)),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: controller.text.trim() == 'EXPERT' ? () => Navigator.pop(dialogContext, true) : null, child: const Text('Enable')),
          ],
        ),
      ),
    );
    controller.dispose();
    if (accepted == true && mounted) setState(() => _expertMode = true);
  }

  Future<void> _showPackageDetails(String packageName) async {
    final info = _info(packageName);
    final meta = _metadata(packageName);
    final snapshot = _snapshot;
    final reasons = <String>[
      'Type: ${_categoryLabel(info.category)}',
      'Status: ${_safetyLabel(info.safety)}',
      'Confidence: ${info.confidence}',
      if (meta.installer.isNotEmpty) 'Installer: ${meta.installer}',
      if (meta.sourceDir.isNotEmpty) 'APK: ${meta.sourceDir}',
      if (meta.versionName.isNotEmpty) 'Version: ${meta.versionName}',
      if (meta.hasLauncher) 'Has launcher activity',
      if (meta.privileged) 'Privileged system app',
      if (meta.deviceAdmin) 'Active device administrator',
      if (snapshot?.criticalRolePackages.contains(packageName) == true) 'Provides a current critical phone role',
      if (snapshot?.currentWebView == packageName) 'Current WebView provider',
      if (_inventory?.apexPackages.contains(packageName) == true) 'APEX/Mainline module',
      if (snapshot?.overlayPackages.contains(packageName) == true) 'Runtime resource overlay',
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(info.name),
        content: SizedBox(width: 650, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          SelectableText(packageName, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Text(info.note),
          if (info.dataWarning != null) ...[
            const SizedBox(height: 10),
            Text('Data warning: ${info.dataWarning}', style: const TextStyle(color: Colors.amberAccent)),
          ],
          const Divider(height: 24),
          ...reasons.map((text) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $text'))),
        ])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _showAnalysis() async {
    if (_device == null) return;
    await _analyseDevice(silent: false, enhanced: true);
    if (!mounted || _inventory == null || _snapshot == null) return;
    final inventory = _inventory!;
    final typeCounts = <AppCategory, int>{};
    for (final p in _packages) {
      final category = _info(p).category;
      typeCounts[category] = (typeCounts[category] ?? 0) + 1;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone analysis'),
        content: SizedBox(width: 700, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_device!.manufacturer} ${_device!.model} • ${_device!.romName} • Android ${_device!.androidVersion}${_device!.sdkInt == null ? '' : ' • API ${_device!.sdkInt}'}'),
          const SizedBox(height: 8),
          Text(inventory.enhancedScan ? 'Enhanced local metadata scan completed.' : 'ADB-only fallback scan completed. Some app names/metadata may be limited.'),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _summaryChip('${_count(SafetyClass.removable)}', 'Removable', Colors.greenAccent),
            _summaryChip('${_count(SafetyClass.caution)}', 'Caution', Colors.amberAccent),
            _summaryChip('${_count(SafetyClass.review)}', 'Review', Colors.orangeAccent),
            _summaryChip('${_count(SafetyClass.protected)}', 'Protected', Colors.lightBlueAccent),
          ]),
          const SizedBox(height: 14),
          Text('${typeCounts[AppCategory.userApp] ?? 0} user app(s) • ${typeCounts[AppCategory.googleApp] ?? 0} Google app/package(s) • ${typeCounts[AppCategory.oemApp] ?? 0} OEM app/package(s)'),
          Text('${inventory.apexPackages.length} APEX/Mainline • ${_snapshot!.overlayPackages.length} runtime overlays • ${_snapshot!.criticalRolePackages.length} live critical roles protected'),
          const SizedBox(height: 12),
          const Text('No changes were made to your phone. Unknown system/OEM packages are never guessed removable.'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          FilledButton.icon(onPressed: () { Navigator.pop(context); unawaited(_exportReport()); }, icon: const Icon(Icons.file_download_outlined), label: const Text('Export report')),
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
      final meta = _metadata(packageName);
      packages.add({
        'package': packageName,
        'name': info.name,
        'category': info.category.name,
        'status': info.safety.name,
        'confidence': info.confidence,
        'description': info.note,
        'dataWarning': info.dataWarning,
        'system': meta.isSystem,
        'updatedSystem': meta.isUpdatedSystem,
        'installer': meta.installer,
        'sourceDir': meta.sourceDir,
        'versionName': meta.versionName,
        'versionCode': meta.versionCode,
        'uid': meta.uid,
        'launcher': meta.hasLauncher,
        'privileged': meta.privileged,
        'deviceAdmin': meta.deviceAdmin,
        'apex': inventory.apexPackages.contains(packageName),
        'overlay': snapshot.overlayPackages.contains(packageName),
        'criticalRole': snapshot.criticalRolePackages.contains(packageName),
        'currentWebView': snapshot.currentWebView == packageName,
      });
    }
    final file = await _sessionStore.exportReport(device, {
      'generatedAt': DateTime.now().toIso8601String(),
      'enhancedScan': inventory.enhancedScan,
      'device': {
        'id': device.id,
        'manufacturer': device.manufacturer,
        'brand': device.brand,
        'model': device.model,
        'codename': device.deviceCodename,
        'rom': device.romName,
        'androidVersion': device.androidVersion,
        'sdkInt': device.sdkInt,
        'securityPatch': device.securityPatch,
        'buildFingerprint': device.buildFingerprint,
      },
      'roles': {'launcher': snapshot.currentLauncher, 'keyboard': snapshot.currentIme, 'dialer': snapshot.currentDialer, 'sms': snapshot.currentSms, 'browser': snapshot.currentBrowser, 'webView': snapshot.currentWebView},
      'packages': packages,
    });
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Analysis exported'), content: SelectableText(file.path), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
  }

  Map<SafetyClass, int> _selectionCounts() {
    final result = <SafetyClass, int>{for (final value in SafetyClass.values) value: 0};
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
    if (snapshot.currentBrowser != null && _selected.contains(snapshot.currentBrowser)) warnings.add('Your current browser is selected. Make sure another browser is installed.');
    if (_selected.contains('com.android.vending')) warnings.add('Google Play Store is selected. Keep another trusted app-installation source available.');
    if (_selected.contains('com.google.android.gms') || _selected.contains('com.google.android.gsf')) warnings.add('Apps that depend on Play Services, FCM, Google APIs or Play Integrity may stop working.');
    for (final packageName in _selected) {
      final warning = _info(packageName).dataWarning;
      if (warning != null) warnings.add('${_info(packageName).name}: $warning');
    }
    return warnings.toSet().toList();
  }

  Future<void> _reviewAndRemove() async {
    final device = _device;
    if (device == null || _selected.isEmpty) return;
    setState(() => _busy = true);
    await _analyseDevice(silent: true, enhanced: true);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!_expertMode) {
      final newlyProtected = _selected.where((p) => _info(p).protected).toList();
      if (newlyProtected.isNotEmpty) {
        setState(() => _selected.removeAll(newlyProtected));
        if (!mounted) return;
        await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Selection updated for safety'), content: Text('${newlyProtected.length} package(s) became protected during the latest live scan and were removed from the selection.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
      }
    }
    if (_selected.isEmpty) return;
    final packages = _selected.toList()..sort((a, b) => _info(a).name.compareTo(_info(b).name));
    final counts = _selectionCounts();
    final warnings = _readinessWarnings();
    final protectedCount = counts[SafetyClass.protected] ?? 0;
    final reviewCount = counts[SafetyClass.review] ?? 0;
    final includesFramework = packages.any((p) => p == 'com.google.android.gms' || p == 'com.google.android.gsf' || p == 'com.android.vending');
    final hasDataWarning = packages.any((p) => _info(p).dataWarning != null);
    String requiredPhrase = '';
    if (protectedCount > 0) requiredPhrase = 'FORCE';
    else if (reviewCount > 0) requiredPhrase = 'REVIEW';
    else if (includesFramework) requiredPhrase = 'DEGOOGLE';
    else if (hasDataWarning) requiredPhrase = 'BACKUP';
    var backup = true;
    final controller = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final enabled = requiredPhrase.isEmpty || controller.text.trim() == requiredPhrase;
          return AlertDialog(
            title: Text('Review ${packages.length} app(s)'),
            content: SizedBox(width: 780, height: 570, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                _summaryChip('${counts[SafetyClass.removable]}', 'Removable', Colors.greenAccent),
                _summaryChip('${counts[SafetyClass.caution]}', 'Caution', Colors.amberAccent),
                _summaryChip('$reviewCount', 'Review', Colors.orangeAccent),
                _summaryChip('$protectedCount', 'Protected / Expert', Colors.lightBlueAccent),
              ]),
              if (warnings.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(width: double.infinity, padding: const EdgeInsets.all(10), decoration: BoxDecoration(border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Before you continue', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...warnings.take(6).map((warning) => Text('• $warning')),
                ])),
              ],
              SwitchListTile(dense: true, contentPadding: EdgeInsets.zero, title: const Text('Back up APK files first'), subtitle: const Text('Recommended. Backups help recovery but cannot guarantee recovery from a non-booting phone.'), value: backup, onChanged: (value) => setLocalState(() => backup = value)),
              if (requiredPhrase.isNotEmpty) ...[
                Text('Type $requiredPhrase to continue:', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                TextField(controller: controller, onChanged: (_) => setLocalState(() {}), decoration: InputDecoration(hintText: requiredPhrase, isDense: true)),
                const SizedBox(height: 8),
              ],
              const Divider(),
              Expanded(child: ListView.builder(itemCount: packages.length, itemBuilder: (context, index) {
                final p = packages[index];
                final info = _info(p);
                return ListTile(dense: true, title: Text(info.name), subtitle: Text(p), trailing: _classBadge(info.safety));
              })),
            ])),
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
    final removed = <String>[];
    final failures = <String, String>{};
    final progress = ValueNotifier<String>('Starting…');
    var stoppedForHealth = false;
    unawaited(showDialog<void>(context: context, barrierDismissible: false, builder: (dialogContext) => PopScope(canPop: false, child: AlertDialog(title: const Text('Removing selected apps'), content: SizedBox(width: 540, child: ValueListenableBuilder<String>(valueListenable: progress, builder: (context, value, child) => Column(mainAxisSize: MainAxisSize.min, children: [const LinearProgressIndicator(), const SizedBox(height: 14), Text(value)]))))));

    for (var index = 0; index < packages.length; index++) {
      final packageName = packages[index];
      try {
        if (!_expertMode && _info(packageName).protected) {
          failures[packageName] = 'Blocked by the latest safety scan.';
          continue;
        }
        if (backup) {
          progress.value = '${index + 1}/${packages.length}: backing up ${_info(packageName).name}';
          await _adb.backup(device.id, packageName, _backups.packageDir(device, packageName), sdkInt: device.sdkInt);
        }
        progress.value = '${index + 1}/${packages.length}: removing ${_info(packageName).name}';
        final error = await _adb.uninstall(device.id, packageName);
        if (error == null) removed.add(packageName); else failures[packageName] = error;
      } catch (error) {
        failures[packageName] = error.toString();
      }
      if (removed.isNotEmpty && (removed.length % 5 == 0 || index == packages.length - 1)) {
        progress.value = 'Safety checkpoint…';
        try {
          final checkpoint = await _adb.healthCheck(device);
          if (!checkpoint.passed) {
            stoppedForHealth = true;
            for (final remaining in packages.skip(index + 1)) failures[remaining] = 'Skipped because a health checkpoint failed.';
            break;
          }
        } catch (_) {}
      }
    }

    progress.value = 'Running final health check…';
    HealthReport health;
    try {
      health = await _adb.healthCheck(device);
    } catch (error) {
      health = HealthReport([HealthCheckItem('Health check', false, error.toString())]);
    }
    final now = DateTime.now();
    await _sessionStore.save(device, RemovalSession(id: 'session-${now.millisecondsSinceEpoch}', createdAt: now, preset: _activePreset ?? 'Manual selection', requestedPackages: List<String>.from(packages), removedPackages: removed, failures: failures, backupEnabled: backup, healthPassed: health.passed));
    progress.dispose();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    setState(() { _busy = false; _selected.clear(); _activePreset = null; });
    await _analyseDevice(silent: true, enhanced: true);
    if (!mounted) return;
    await _showRemovalResult(removed, failures, health, stoppedForHealth);
  }

  Future<void> _showRemovalResult(List<String> removed, Map<String, String> failures, HealthReport health, bool stoppedForHealth) async {
    await showDialog<void>(context: context, builder: (context) => AlertDialog(
      title: Text(health.passed && !stoppedForHealth ? 'Removal complete' : 'Removal stopped — check device'),
      content: SizedBox(width: 700, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${removed.length} removed • ${failures.length} failed/skipped'),
        if (stoppedForHealth) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Droid Purifier stopped the remaining batch because a safety checkpoint did not pass.', style: TextStyle(color: Colors.amberAccent))),
        const SizedBox(height: 12),
        const Text('Health check', style: TextStyle(fontWeight: FontWeight.bold)),
        ...health.items.map((item) => ListTile(dense: true, contentPadding: EdgeInsets.zero, leading: Icon(item.ok ? Icons.check_circle_outline : Icons.error_outline, color: item.ok ? Colors.greenAccent : Colors.redAccent), title: Text(item.label), subtitle: Text(item.detail))),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        FilledButton.tonal(onPressed: () { Navigator.pop(context); setState(() => _section = 2); }, child: const Text('Open Restore')),
      ],
    ));
  }

  Future<void> _restoreSession(RemovalSession session) async {
    final device = _device;
    if (device == null || session.removedPackages.isEmpty) return;
    final approved = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Restore this removal session?'), content: Text('Droid Purifier will attempt to restore ${session.removedPackages.length} app(s).'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Restore'))]));
    if (approved != true) return;
    setState(() => _busy = true);
    var restored = 0;
    final failures = <String, String>{};
    for (final packageName in session.removedPackages) {
      try {
        final error = await _adb.restore(device.id, packageName, _backups.packageDir(device, packageName));
        if (error == null) restored++; else failures[packageName] = error;
      } catch (error) {
        failures[packageName] = error.toString();
      }
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await _analyseDevice(silent: true, enhanced: true);
    if (!mounted) return;
    await showDialog<void>(context: context, builder: (context) => AlertDialog(title: const Text('Restore complete'), content: Text('$restored restored • ${failures.length} failed.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))]));
  }

  Future<void> _restoreSingle(String packageName) async {
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
    if (error == null) await _analyseDevice(silent: true, enhanced: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error == null ? '$packageName restored.' : error)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 54,
        title: const Row(children: [Icon(Icons.shield_outlined), SizedBox(width: 9), Text('Droid Purifier'), SizedBox(width: 10), _OfflineBadge()]),
        actions: [
          if (_device != null) Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: DropdownButton<String>(value: _device!.id, items: _devices.where((item) => item.ready).map((item) => DropdownMenuItem(value: item.id, child: Text('${item.manufacturer} ${item.model}'))).toList(), onChanged: _busy ? null : _chooseDevice)),
          IconButton(onPressed: _busy ? null : _refreshDevices, tooltip: 'Refresh device', icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(children: [
        if (_error != null) MaterialBanner(content: Text(_error!), leading: const Icon(Icons.error_outline), actions: [TextButton(onPressed: () => setState(() => _error = null), child: const Text('Dismiss'))]),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_device == null) Expanded(child: _noDevice()) else ...[
          _deviceBar(),
          const Divider(height: 1),
          Expanded(child: switch (_section) { 0 => _packagePage(deGoogle: true), 1 => _packagePage(deGoogle: false), _ => _restorePage() }),
        ],
      ]),
    );
  }

  Widget _noDevice() => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.phone_android, size: 56),
    const SizedBox(height: 14),
    const Text('Connect an Android phone and allow USB debugging.', style: TextStyle(fontSize: 18)),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: _refreshDevices, icon: const Icon(Icons.refresh), label: const Text('Refresh')),
  ]));

  Widget _deviceBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
    child: Row(children: [
      Expanded(child: Text('${_device!.manufacturer} ${_device!.model}   ${_device!.romName} • Android ${_device!.androidVersion}${_device!.sdkInt == null ? '' : ' • API ${_device!.sdkInt}'}   ${_device!.battery} battery', maxLines: 1, overflow: TextOverflow.ellipsis)),
      SegmentedButton<int>(
        segments: const [ButtonSegment(value: 0, label: Text('De-Google')), ButtonSegment(value: 1, label: Text('Apps')), ButtonSegment(value: 2, label: Text('Restore'))],
        selected: {_section},
        onSelectionChanged: _busy ? null : (values) => setState(() { _section = values.first; _filter = 'All'; _search = ''; }),
        showSelectedIcon: false,
      ),
    ]),
  );

  Widget _packagePage({required bool deGoogle}) {
    final visible = _visiblePackages;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(deGoogle ? 'De-Google' : 'All Apps', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(deGoogle ? 'Google apps and services only. Android core stays protected.' : 'Simple app manager. Droid Purifier analyses safety in the background.', style: const TextStyle(color: Colors.white54)),
          ])),
          FilledButton.icon(onPressed: _busy || _selected.isEmpty ? null : _reviewAndRemove, icon: const Icon(Icons.delete_sweep_outlined), label: Text('Review & remove (${_selected.length})')),
        ]),
        const SizedBox(height: 12),
        if (deGoogle)
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _applyRecommended, icon: const Icon(Icons.shield_outlined), label: Text('Recommended ($_recommendedCount)'))),
            const SizedBox(width: 10),
            Expanded(child: FilledButton.tonalIcon(onPressed: _busy ? null : _applyFull, icon: const Icon(Icons.verified_user_outlined), label: Text('Full De-Google ($_fullCount)'))),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: _busy ? null : _showAnalysis, icon: const Icon(Icons.analytics_outlined), label: const Text('Analyze')),
          ])
        else
          Row(children: [
            OutlinedButton.icon(onPressed: _busy ? null : _showAnalysis, icon: const Icon(Icons.analytics_outlined), label: const Text('Analyze phone')),
            const SizedBox(width: 10),
            OutlinedButton.icon(onPressed: _busy ? null : _selectRemovableVisible, icon: const Icon(Icons.playlist_add_check), label: const Text('Select removable')),
            const Spacer(),
            const Text('Expert Mode'),
            const SizedBox(width: 6),
            Switch(value: _expertMode, onChanged: _busy ? null : _setExpertMode),
          ]),
        const SizedBox(height: 9),
        Row(children: [
          _statusDot('${_count(SafetyClass.removable, googleOnly: deGoogle)} removable', Colors.greenAccent),
          _statusDot('${_count(SafetyClass.caution, googleOnly: deGoogle)} caution', Colors.amberAccent),
          _statusDot('${_count(SafetyClass.review, googleOnly: deGoogle)} review', Colors.orangeAccent),
          _statusDot('${_count(SafetyClass.protected, googleOnly: deGoogle)} protected', Colors.lightBlueAccent),
          const Spacer(),
          if (_inventory != null) Text(_inventory!.enhancedScan ? 'Enhanced scan' : 'ADB fallback', style: const TextStyle(color: Colors.white38)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: TextField(onChanged: (value) => setState(() => _search = value), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search app or package', border: OutlineInputBorder(), isDense: true))),
          const SizedBox(width: 10),
          SizedBox(width: 180, child: DropdownButtonFormField<String>(value: _filter, isDense: true, decoration: const InputDecoration(border: OutlineInputBorder()), items: (deGoogle ? const ['All', 'Removable', 'Caution', 'Review', 'Protected'] : const ['All', 'User apps', 'Google', 'OEM', 'System', 'Removable', 'Caution', 'Review', 'Protected']).map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(), onChanged: (value) => setState(() => _filter = value ?? 'All'))),
          TextButton(onPressed: _clearSelection, child: const Text('Clear')),
        ]),
        const SizedBox(height: 7),
        Text('${visible.length} shown • ${_selected.length} selected', style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 7),
        Expanded(child: Container(decoration: BoxDecoration(color: const Color(0xff10150f), borderRadius: BorderRadius.circular(14)), child: ListView.separated(itemCount: visible.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (context, index) => _packageRow(visible[index])))),
      ]),
    );
  }

  Widget _packageRow(String packageName) {
    final info = _info(packageName);
    final meta = _metadata(packageName);
    final canSelect = _canNormallySelect(packageName);
    return ListTile(
      minVerticalPadding: 7,
      leading: Checkbox(value: _selected.contains(packageName), onChanged: canSelect ? (_) => _togglePackage(packageName) : null),
      title: Text(info.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(children: [
        Flexible(child: Text(packageName, maxLines: 1, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 10),
        Text(_categoryLabel(info.category).toUpperCase(), style: const TextStyle(fontSize: 11, color: Colors.white38)),
        if (info.dataWarning != null) ...[const SizedBox(width: 8), const Icon(Icons.warning_amber_rounded, size: 15, color: Colors.amberAccent), const Text(' DATA', style: TextStyle(fontSize: 11, color: Colors.amberAccent))],
        if (!meta.enabled) ...[const SizedBox(width: 8), const Text('DISABLED', style: TextStyle(fontSize: 11, color: Colors.white38))],
      ]),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _classBadge(info.safety),
        IconButton(onPressed: () => _showPackageDetails(packageName), tooltip: 'Why this status?', icon: const Icon(Icons.info_outline, size: 19)),
      ]),
      onTap: canSelect ? () => _togglePackage(packageName) : () => _showPackageDetails(packageName),
    );
  }

  Widget _restorePage() => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Restore', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
      const Text('Undo previous Droid Purifier removals.', style: TextStyle(color: Colors.white54)),
      const SizedBox(height: 14),
      Expanded(child: ListView(children: [
        if (_history.isEmpty && _backupPackages.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('No Droid Purifier removal sessions or APK backups were found.')),
        ..._history.map((session) => Card(child: ListTile(leading: Icon(session.healthPassed ? Icons.history : Icons.warning_amber_rounded), title: Text(session.preset), subtitle: Text('${session.createdAt.toLocal()} • ${session.removedPackages.length} removed • backup ${session.backupEnabled ? 'on' : 'off'}'), trailing: FilledButton.tonal(onPressed: _busy ? null : () => _restoreSession(session), child: const Text('Restore session'))))),
        if (_backupPackages.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Individual backups', style: TextStyle(fontWeight: FontWeight.bold)),
          ..._backupPackages.map((packageName) => ListTile(title: Text(_inventory?.metadata[packageName]?.label ?? packageName), subtitle: Text(packageName), trailing: TextButton(onPressed: _busy ? null : () => _restoreSingle(packageName), child: const Text('Restore')))),
        ],
      ])),
    ]),
  );

  Widget _summaryChip(String count, String label, Color color) => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(border: Border.all(color: color.withValues(alpha: 0.75)), borderRadius: BorderRadius.circular(10)), child: Text('$count  $label'));
  Widget _statusDot(String text, Color color) => Padding(padding: const EdgeInsets.only(right: 14), child: Row(children: [Icon(Icons.circle, size: 7, color: color), const SizedBox(width: 5), Text(text, style: const TextStyle(color: Colors.white60))]));

  Widget _classBadge(SafetyClass safety) {
    final color = switch (safety) { SafetyClass.removable => Colors.greenAccent, SafetyClass.caution => Colors.amberAccent, SafetyClass.review => Colors.orangeAccent, SafetyClass.protected => Colors.lightBlueAccent };
    return Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(border: Border.all(color: color), borderRadius: BorderRadius.circular(20)), child: Text(_safetyLabel(safety).toUpperCase(), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)));
  }

  String _safetyLabel(SafetyClass safety) => switch (safety) { SafetyClass.removable => 'Removable', SafetyClass.caution => 'Caution', SafetyClass.review => 'Review', SafetyClass.protected => 'Protected' };
  String _categoryLabel(AppCategory category) => switch (category) { AppCategory.userApp => 'User App', AppCategory.googleApp => 'Google App', AppCategory.oemApp => 'OEM App', AppCategory.carrierApp => 'Carrier App', AppCategory.system => 'System', AppCategory.unknownVendor => 'System / Vendor' };
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.6)), borderRadius: BorderRadius.circular(20)), child: const Text('OFFLINE', style: TextStyle(fontSize: 10, color: Colors.greenAccent)));
}

extension FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
