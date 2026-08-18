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
  final Set<String> _selected = <String>{};

  List<DeviceInfo> _devices = <DeviceInfo>[];
  DeviceInfo? _device;
  List<String> _packages = <String>[];
  Set<String> _apexPackages = <String>{};
  List<String> _backupPackages = <String>[];
  String _search = '';
  String _filter = 'All';
  String? _activePreset;
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
      _activePreset = null;
    });
    await _loadPackages();
  }

  void _replaceSelection(
    Iterable<String> packages, {
    required String preset,
    String? filter,
  }) {
    setState(() {
      _selected
        ..clear()
        ..addAll(packages.where((packageName) => !_protected(packageName)));
      _activePreset = preset;
      if (filter != null) _filter = filter;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text('${_selected.length} packages selected.'),
      ),
    );
  }

  void _applyRecommendedDeGoogle() {
    _replaceSelection(
      _packages.where(_isRecommended),
      preset: 'recommended',
      filter: 'De-Google',
    );
  }

  void _applyFullDeGoogle() {
    _replaceSelection(
      _packages.where(_isFull),
      preset: 'full',
      filter: 'De-Google',
    );
  }

  void _applyManufacturerBloatware() {
    _replaceSelection(
      _packages.where((packageName) =>
          RiskDatabase.manufacturerBloat.contains(packageName) &&
          !_protected(packageName)),
      preset: 'oem',
    );
  }

  void _selectSafeVisible() {
    setState(() {
      _selected.addAll(_safeVisiblePackages);
      _activePreset = null;
    });
  }

  void _togglePackage(String packageName) {
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
              width: 700,
              height: 500,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (includesGoogleFramework)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Colors.orangeAccent),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Full De-Google can break apps that depend on Play Services, FCM or Google APIs.',
                            ),
                          ),
                        ],
                      ),
                    ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Back up APK files first'),
                    value: backup,
                    onChanged: (value) => setLocalState(() => backup = value),
                  ),
                  if (dangerous.isNotEmpty) ...[
                    Text(
                      '${dangerous.length} High/Critical package(s). Type CONFIRM:',
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      onChanged: (_) => setLocalState(() {}),
                      decoration: const InputDecoration(
                        hintText: 'CONFIRM',
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
                        final risk = _risk(packageName);
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
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
              width: 500,
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
        if (_protected(packageName)) {
          failures[packageName] =
              'Package became protected by the Android safety policy.';
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
      _activePreset = null;
    });
    await _loadPackages();
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Removal complete'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$succeeded removed. ${failures.length} failed/skipped.'),
              if (failures.isNotEmpty) ...[
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView(
                    shrinkWrap: true,
                    children: failures.entries
                        .map(
                          (entry) => ListTile(
                            dense: true,
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
        toolbarHeight: 56,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded),
            SizedBox(width: 9),
            Text('Droid Purifier'),
          ],
        ),
        actions: [
          if (_device != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
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
            tooltip: 'Refresh',
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
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android, size: 64),
            const SizedBox(height: 14),
            const Text(
              'Connect an Android device',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enable USB debugging and approve the RSA prompt.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loading ? null : _refreshDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Detect devices'),
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
              const SizedBox(width: 16),
              Text(
                'Android ${device.androidVersion}${device.sdkInt == null ? '' : ' • API ${device.sdkInt}'}',
              ),
              const SizedBox(width: 16),
              Text('${device.battery} battery'),
              const Spacer(),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 0, label: Text('Debloat')),
                  ButtonSegment(value: 1, label: Text('Restore')),
                ],
                selected: {_tab},
                onSelectionChanged: _busy
                    ? null
                    : (value) => setState(() => _tab = value.first),
              ),
            ],
          ),
        ),
        Expanded(child: _tab == 0 ? _debloatView() : _restoreView()),
      ],
    );
  }

  Widget _debloatView() {
    final visible = _visiblePackages;
    final safeVisible = _safeVisiblePackages;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Apps',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 12),
              Text(
                '${_packages.length} installed',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
              const Spacer(),
              if (_selected.isNotEmpty)
                FilledButton.icon(
                  onPressed: _busy ? null : _reviewAndRemove,
                  icon: const Icon(Icons.delete_sweep, size: 19),
                  label: Text('Remove (${_selected.length})'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _presetChoice(
                  keyName: 'recommended',
                  title: 'Recommended',
                  count: _recommendedCount,
                  icon: Icons.verified_user_outlined,
                  tooltip:
                      'Removes Google apps and non-core Google services. Keeps Play Services, GSF and Play Store.',
                  onPressed: _applyRecommendedDeGoogle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _presetChoice(
                  keyName: 'full',
                  title: 'Full De-Google',
                  count: _fullCount,
                  icon: Icons.gpp_good_outlined,
                  tooltip:
                      'Also selects Play Services, GSF and Play Store. Android core stays protected.',
                  onPressed: _applyFullDeGoogle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _presetChoice(
                  keyName: 'oem',
                  title: 'OEM Bloatware',
                  count: _manufacturerCount,
                  icon: Icons.factory_outlined,
                  tooltip: 'Curated Samsung, Xiaomi, OPPO, realme and OEM extras.',
                  onPressed: _applyManufacturerBloatware,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.shield_outlined,
                size: 17,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$_googleCoreCount Android-core Google packages protected • ${_apexPackages.length} Mainline/APEX locked • $_manualGoogleCount manual-review',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Tooltip(
                message:
                    'Unknown future Google packages are never auto-selected. Android core packages remain locked on old and new Android versions.',
                child: const Icon(Icons.info_outline, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search, size: 20),
                      hintText: 'Search apps or packages',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 44,
                child: DropdownButton<String>(
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
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) => setState(() => _filter = value ?? 'All'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed:
                    _busy || safeVisible.isEmpty ? null : _selectSafeVisible,
                child: Text('Select safe (${safeVisible.length})'),
              ),
              const SizedBox(width: 4),
              TextButton(
                onPressed:
                    _busy || _selected.isEmpty ? null : _clearSelection,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${visible.length} shown • ${_selected.length} selected',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final packageName = visible[index];
                        final risk = _risk(packageName);
                        final protected = risk.protected;
                        final selected = _selected.contains(packageName);

                        return ListTile(
                          dense: true,
                          visualDensity: const VisualDensity(
                            horizontal: -2,
                            vertical: -2,
                          ),
                          minVerticalPadding: 3,
                          leading: Checkbox(
                            value: selected,
                            onChanged: protected || _busy
                                ? null
                                : (_) => _togglePackage(packageName),
                          ),
                          title: Text(
                            risk.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            packageName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onTap: protected || _busy
                              ? null
                              : () => _togglePackage(packageName),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (risk.deGoogleTier == DeGoogleTier.core)
                                _smallTag('CORE', Colors.lightBlueAccent)
                              else if (risk.deGoogleTier ==
                                  DeGoogleTier.manual)
                                _smallTag('MANUAL', Colors.orangeAccent),
                              const SizedBox(width: 6),
                              _riskBadge(risk.level),
                              const SizedBox(width: 2),
                              Tooltip(
                                message: risk.note,
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

  Widget _presetChoice({
    required String keyName,
    required String title,
    required int count,
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    final selected = _activePreset == keyName;
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _busy ? null : onPressed,
          icon: Icon(selected ? Icons.check_circle : icon, size: 19),
          label: Text('$title ($count)'),
          style: OutlinedButton.styleFrom(
            backgroundColor:
                selected ? scheme.primaryContainer.withValues(alpha: 0.55) : null,
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outline,
            ),
          ),
        ),
      ),
    );
  }

  Widget _restoreView() {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Restore',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text('Restore previously backed-up packages.'),
          const SizedBox(height: 10),
          Expanded(
            child: _backupPackages.isEmpty
                ? const Center(
                    child: Text('No local package backups found for this device.'),
                  )
                : Card(
                    margin: EdgeInsets.zero,
                    child: ListView.separated(
                      itemCount: _backupPackages.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final packageName = _backupPackages[index];
                        return ListTile(
                          dense: true,
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

  Widget _smallTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _riskBadge(RiskLevel level) {
    final label = switch (level) {
      RiskLevel.low => 'LOW',
      RiskLevel.medium => 'MED',
      RiskLevel.high => 'HIGH',
      RiskLevel.critical => 'CRIT',
      RiskLevel.protected => 'LOCKED',
    };
    final color = switch (level) {
      RiskLevel.low => Colors.greenAccent,
      RiskLevel.medium => Colors.amberAccent,
      RiskLevel.high => Colors.orangeAccent,
      RiskLevel.critical => Colors.redAccent,
      RiskLevel.protected => Colors.blueGrey,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
