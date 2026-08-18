import 'dart:async';

import 'package:flutter/material.dart';

import 'adb_service.dart';
import 'package_policy.dart';

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
  Set<String> _apexPackages = <String>{};
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

  RiskInfo _risk(String packageName) {
    final device = _device;
    return RiskDatabase.get(
      packageName,
      sdkInt: device?.sdkInt,
      isApex: _apexPackages.contains(packageName),
      setupComplete: device?.setupComplete ?? true,
    );
  }

  bool _protected(String packageName) => _risk(packageName).protected;

  bool _isRecommended(String packageName) {
    final device = _device;
    return RiskDatabase.isRecommendedDeGoogle(
      packageName,
      sdkInt: device?.sdkInt,
      isApex: _apexPackages.contains(packageName),
      setupComplete: device?.setupComplete ?? true,
    );
  }

  bool _isFull(String packageName) {
    final device = _device;
    return RiskDatabase.isFullDeGoogle(
      packageName,
      sdkInt: device?.sdkInt,
      isApex: _apexPackages.contains(packageName),
      setupComplete: device?.setupComplete ?? true,
    );
  }

  List<String> get _visiblePackages {
    final query = _search.trim().toLowerCase();
    return _packages.where((packageName) {
      final risk = _risk(packageName);
      if (query.isNotEmpty &&
          !packageName.toLowerCase().contains(query) &&
          !risk.name.toLowerCase().contains(query) &&
          !risk.note.toLowerCase().contains(query)) {
        return false;
      }

      switch (_filter) {
        case 'De-Google':
          return risk.googleRemovalCandidate;
        case 'Google namespace':
          return RiskDatabase.isGoogleRelated(packageName);
        case 'Android core':
          return risk.level == RiskLevel.protected;
        case 'Low risk':
          return risk.level == RiskLevel.low;
        case 'Review':
          return risk.level == RiskLevel.medium ||
              risk.level == RiskLevel.high ||
              risk.level == RiskLevel.critical;
        default:
          return true;
      }
    }).toList();
  }

  List<String> get _safeVisiblePackages => _visiblePackages.where((packageName) {
        final risk = _risk(packageName);
        if (risk.protected) return false;

        if (_filter == 'De-Google' || _filter == 'Google namespace') {
          return risk.autoSelect &&
              (risk.level == RiskLevel.low || risk.level == RiskLevel.medium);
        }

        if (RiskDatabase.manufacturerBloat.contains(packageName)) {
          return risk.level == RiskLevel.low || risk.level == RiskLevel.medium;
        }

        return risk.autoSelect &&
            (risk.level == RiskLevel.low || risk.level == RiskLevel.medium);
      }).toList();

  int get _recommendedCount => _packages.where(_isRecommended).length;
  int get _fullCount => _packages.where(_isFull).length;
  int get _manualGoogleCount => _packages.where((packageName) {
        final risk = _risk(packageName);
        return risk.deGoogleTier == DeGoogleTier.manual && !risk.protected;
      }).length;
  int get _googleCoreCount => _packages.where((packageName) {
        final risk = _risk(packageName);
        return RiskDatabase.isGoogleRelated(packageName) &&
            risk.deGoogleTier == DeGoogleTier.core;
      }).length;
  int get _manufacturerCount => _packages
      .where((packageName) =>
          RiskDatabase.manufacturerBloat.contains(packageName) &&
          !_protected(packageName))
      .length;

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
      if (selected == null) {
        for (final item in devices) {
          if (item.ready) {
            selected = item;
            break;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _device = selected;
      });
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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final inventory = await _adb.packageInventory(
        device.id,
        sdkInt: device.sdkInt,
      );
      final backups = await _backups.packages(device);
      if (!mounted || _device?.id != device.id) return;
      setState(() {
        _packages = inventory.packages;
        _apexPackages = inventory.apexPackages;
        _backupPackages = backups;
        _selected.removeWhere((packageName) =>
            !inventory.packages.contains(packageName) ||
            RiskDatabase.isProtected(
              packageName,
              sdkInt: device.sdkInt,
              isApex: inventory.apexPackages.contains(packageName),
              setupComplete: device.setupComplete,
            ));
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
    setState(() {
      _device = next;
      _selected.clear();
      _packages = <String>[];
      _apexPackages = <String>{};
    });
    await _loadPackages();
  }

  void _applyRecommendedDeGoogle() {
    var added = 0;
    setState(() {
      for (final packageName in _packages) {
        if (_isRecommended(packageName) && _selected.add(packageName)) added++;
      }
      _filter = 'De-Google';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Recommended De-Google: $added package(s) added. Play Services, GSF and Play Store are kept by this preset.',
        ),
      ),
    );
  }

  void _applyFullDeGoogle() {
    var added = 0;
    setState(() {
      for (final packageName in _packages) {
        if (_isFull(packageName) && _selected.add(packageName)) added++;
      }
      _filter = 'De-Google';
    });

    final manual = _manualGoogleCount;
    final core = _googleCoreCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 7),
        content: Text(
          'Full De-Google: $added package(s) added. $manual package(s) need manual review/replacements; $core Android-core Google-namespaced package(s) stay protected.',
        ),
      ),
    );
  }

  void _applyManufacturerBloatware() {
    var added = 0;
    setState(() {
      for (final packageName in _packages) {
        if (RiskDatabase.manufacturerBloat.contains(packageName) &&
            !_protected(packageName) &&
            _selected.add(packageName)) {
          added++;
        }
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Manufacturer Bloatware: $added package(s) added. Review before removal.',
        ),
      ),
    );
  }

  void _selectSafeVisible() {
    final safe = _safeVisiblePackages;
    setState(() => _selected.addAll(safe));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${safe.length} curated low/medium-risk package(s) selected. High/Critical, unknown and Android-core packages were skipped.',
        ),
      ),
    );
  }

  Future<void> _reviewAndRemove() async {
    final device = _device;
    if (device == null || _selected.isEmpty) return;

    final packages = _selected
        .where((packageName) => !_protected(packageName))
        .toList()
      ..sort();
    if (packages.isEmpty) return;

    final dangerous = packages.where((packageName) {
      final level = _risk(packageName).level;
      return level == RiskLevel.high || level == RiskLevel.critical;
    }).toList();
    final includesGoogleFramework = packages.any((packageName) =>
        packageName == 'com.google.android.gms' ||
        packageName == 'com.google.android.gsf' ||
        packageName == 'com.google.android.gsf.login' ||
        packageName == 'com.android.vending');

    var backup = true;
    final controller = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) {
          final enabled =
              dangerous.isEmpty || controller.text.trim() == 'CONFIRM';
          return AlertDialog(
            title: Text('Remove ${packages.length} selected package(s)?'),
            content: SizedBox(
              width: 720,
              height: 550,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Packages are removed only for Android user 0. Protected Android core/Mainline packages cannot enter this list.',
                  ),
                  if (includesGoogleFramework) ...[
                    const SizedBox(height: 10),
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orangeAccent),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Full De-Google includes Google framework components. Basic Android should remain intact, but third-party apps that require Play Services, FCM, Google APIs or Play Integrity can stop working.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Back up APK files first'),
                    subtitle: const Text(
                      'If backup fails, that package will not be removed.',
                    ),
                    value: backup,
                    onChanged: (value) => setLocalState(() => backup = value),
                  ),
                  if (dangerous.isNotEmpty) ...[
                    Text(
                      '${dangerous.length} High/Critical package(s) selected. Type CONFIRM:',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      onChanged: (_) => setLocalState(() {}),
                      decoration: const InputDecoration(hintText: 'CONFIRM'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const Text(
                    'Selected packages',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: packages.length,
                      itemBuilder: (context, index) {
                        final packageName = packages[index];
                        final risk = _risk(packageName);
                        return ListTile(
                          dense: true,
                          title: Text(risk.name),
                          subtitle: Text(packageName),
                          trailing: _riskBadge(risk.level),
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
                onPressed:
                    enabled ? () => Navigator.pop(dialogContext, true) : null,
                child: Text(backup ? 'Backup & remove' : 'Remove'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (approved == true) await _removeBatch(device, packages, backup);
  }

  Future<void> _removeBatch(
    DeviceInfo device,
    List<String> packages,
    bool backup,
  ) async {
    setState(() => _busy = true);
    var succeeded = 0;
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
                    const SizedBox(height: 18),
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
        if (_protected(packageName)) {
          failures[packageName] =
              'Package became protected by the current Android safety policy.';
          continue;
        }
        if (backup) {
          progress.value =
              '${index + 1}/${packages.length}: backing up $packageName';
          await _adb.backup(
            device.id,
            packageName,
            _backups.packageDir(device, packageName),
            sdkInt: device.sdkInt,
          );
        }
        progress.value =
            '${index + 1}/${packages.length}: removing $packageName';
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
    setState(() {
      _busy = false;
      _selected.clear();
    });
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
              Text('$succeeded removed. ${failures.length} failed/skipped.'),
              if (failures.isNotEmpty) ...[
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView(
                    shrinkWrap: true,
                    children: failures.entries
                        .map(
                          (entry) => ListTile(
                            title: Text(entry.key),
                            subtitle: Text(entry.value),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(String packageName) async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$packageName restored.')),
      );
      await _loadPackages();
    } else {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore failed'),
          content: Text(error!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded),
            SizedBox(width: 10),
            Text('Droid Purifier'),
          ],
        ),
        actions: [
          if (_device != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
            tooltip: 'Refresh devices',
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text(_error!),
              leading:
                  const Icon(Icons.error_outline, color: Colors.redAccent),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('DISMISS'),
                ),
              ],
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
            const Text(
              'Connect an Android device',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Enable USB debugging, connect the phone, and approve the RSA prompt. ADB is bundled with release builds.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _loading ? null : _refreshDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Detect devices'),
            ),
            if (_devices.any((item) => !item.ready)) ...[
              const SizedBox(height: 16),
              ..._devices.where((item) => !item.ready).map(
                    (item) => Text(
                      '${item.id}: ${item.status}',
                      style: const TextStyle(color: Colors.orangeAccent),
                    ),
                  ),
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
              Text(
                'Android ${device.androidVersion}${device.sdkInt == null ? '' : ' • API ${device.sdkInt}'}',
              ),
              const SizedBox(width: 18),
              Text('Battery ${device.battery}'),
              const Spacer(),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.apps),
                    label: Text('Debloat'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.restore),
                    label: Text('Restore'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: _busy
                    ? null
                    : (value) => setState(() => _tab = value.first),
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
    final safeVisible = _safeVisiblePackages;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Installed apps',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'De-Google presets remove Google apps/services while Android core modules stay protected.',
                    ),
                  ],
                ),
              ),
              if (_selected.isNotEmpty)
                FilledButton.icon(
                  onPressed: _busy ? null : _reviewAndRemove,
                  icon: const Icon(Icons.delete_sweep),
                  label: Text('Review & remove (${_selected.length})'),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Compatibility protection: ${_apexPackages.length} APEX/Mainline package(s) detected and locked. Unknown future Google packages are never auto-selected. Google-namespaced Android core packages are labeled as Android core, not “Google bloatware.”',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _presetButton(
                'Recommended De-Google',
                '$_recommendedCount matches • apps + non-core Google services • keeps Play Services / GSF / Play Store',
                Icons.verified_user_outlined,
                _applyRecommendedDeGoogle,
              ),
              _presetButton(
                'Full De-Google',
                '$_fullCount matches • adds Play Services / GSF / Play Store • Android core stays protected',
                Icons.gpp_good_outlined,
                _applyFullDeGoogle,
              ),
              _presetButton(
                'Manufacturer Bloatware',
                '$_manufacturerCount matches • Samsung / Xiaomi / OPPO / realme',
                Icons.factory_outlined,
                _applyManufacturerBloatware,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search package, app name or description',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _filter,
                items: const [
                  'All',
                  'De-Google',
                  'Google namespace',
                  'Android core',
                  'Low risk',
                  'Review',
                ]
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _filter = value ?? 'All'),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed:
                    _busy || safeVisible.isEmpty ? null : _selectSafeVisible,
                child: Text('Select safe shown (${safeVisible.length})'),
              ),
              TextButton(
                onPressed: _busy || _selected.isEmpty
                    ? null
                    : () => setState(() => _selected.clear()),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${visible.length} shown • ${_packages.length} installed • ${_selected.length} selected • $_manualGoogleCount Google package(s) manual-review • $_googleCoreCount Google-namespaced Android-core',
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final packageName = visible[index];
                        final risk = _risk(packageName);
                        final protected = risk.protected;
                        return CheckboxListTile(
                          value: _selected.contains(packageName),
                          onChanged: protected || _busy
                              ? null
                              : (_) => setState(
                                    () => _selected.contains(packageName)
                                        ? _selected.remove(packageName)
                                        : _selected.add(packageName),
                                  ),
                          title: Row(
                            children: [
                              Expanded(child: Text(risk.name)),
                              if (risk.deGoogleTier == DeGoogleTier.core)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Text(
                                    'ANDROID CORE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.lightBlueAccent,
                                    ),
                                  ),
                                )
                              else if (risk.deGoogleTier ==
                                  DeGoogleTier.manual)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Text(
                                    'MANUAL REVIEW',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orangeAccent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
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

  Widget _presetButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 390,
      child: OutlinedButton(
        onPressed: _busy ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(subtitle, style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
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
          const Text(
            'Restore',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Restore packages using install-existing when supported, with local APK backups as fallback for older/newer Android builds.',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _backupPackages.isEmpty
                ? const Center(
                    child: Text('No local package backups found for this device.'),
                  )
                : Card(
                    child: ListView.separated(
                      itemCount: _backupPackages.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final packageName = _backupPackages[index];
                        return ListTile(
                          title: Text(_risk(packageName).name),
                          subtitle: Text(packageName),
                          trailing: FilledButton.tonal(
                            onPressed:
                                _busy ? null : () => _restore(packageName),
                            child: const Text('Restore'),
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
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
