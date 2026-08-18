import 'dart:async';
import 'dart:convert';
import 'dart:io';

class DeviceInfo {
  const DeviceInfo({
    required this.id,
    required this.status,
    required this.model,
    required this.manufacturer,
    required this.androidVersion,
    required this.sdkInt,
    required this.battery,
    required this.setupComplete,
  });

  final String id;
  final String status;
  final String model;
  final String manufacturer;
  final String androidVersion;
  final int? sdkInt;
  final String battery;
  final bool setupComplete;

  bool get ready => status == 'device';
}

class PackageInventory {
  const PackageInventory({
    required this.packages,
    required this.apexPackages,
  });

  final List<String> packages;
  final Set<String> apexPackages;
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

  Future<ProcessResult> run(
    List<String> args, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      return await Process.run(await executable, args).timeout(timeout);
    } on TimeoutException {
      throw AdbException('ADB command timed out: adb ${args.join(' ')}');
    } on ProcessException catch (error) {
      throw AdbException('ADB could not be started. ${error.message}');
    }
  }

  Future<ProcessResult> _shell(
    String deviceId,
    List<String> command, {
    Duration timeout = const Duration(seconds: 60),
  }) =>
      run(['-s', deviceId, 'shell', ...command], timeout: timeout);

  Future<String> _shellText(String deviceId, List<String> command) async {
    final result = await _shell(deviceId, command);
    return result.stdout.toString().trim();
  }

  Future<List<DeviceInfo>> devices() async {
    final result = await run(['devices']);
    if (result.exitCode != 0) {
      throw AdbException(result.stderr.toString().trim());
    }

    final output = <DeviceInfo>[];
    final lines = result.stdout.toString().split(RegExp(r'\r?\n'));
    for (final line in lines.skip(1)) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length < 2 || parts.first.isEmpty) continue;
      final id = parts[0];
      final status = parts[1];
      if (status != 'device') {
        output.add(DeviceInfo(
          id: id,
          status: status,
          model: 'Unknown',
          manufacturer: 'Unknown',
          androidVersion: 'Unknown',
          sdkInt: null,
          battery: 'Unknown',
          setupComplete: false,
        ));
        continue;
      }
      output.add(await _details(id));
    }
    return output;
  }

  Future<DeviceInfo> _details(String id) async {
    final model = await _shellText(id, ['getprop', 'ro.product.model']);
    final manufacturer =
        await _shellText(id, ['getprop', 'ro.product.manufacturer']);
    final version =
        await _shellText(id, ['getprop', 'ro.build.version.release']);
    final sdkText = await _shellText(id, ['getprop', 'ro.build.version.sdk']);
    final sdkInt = int.tryParse(sdkText.trim());

    final batteryDump = await _shellText(id, ['dumpsys', 'battery']);
    final level = RegExp(r'level:\s*(\d+)')
        .firstMatch(batteryDump)
        ?.group(1);

    // user_setup_complete exists across a wide range of Android releases.
    // device_provisioned is used as an additional fallback for older builds.
    final userSetup =
        await _shellText(id, ['settings', 'get', 'secure', 'user_setup_complete']);
    final provisioned =
        await _shellText(id, ['settings', 'get', 'global', 'device_provisioned']);
    final explicitlyIncomplete = userSetup == '0' || provisioned == '0';
    final explicitlyComplete = userSetup == '1' || provisioned == '1';
    final setupComplete = explicitlyComplete || !explicitlyIncomplete;

    return DeviceInfo(
      id: id,
      status: 'device',
      model: model.isEmpty ? 'Android device' : model,
      manufacturer: manufacturer.isEmpty ? 'Unknown' : manufacturer,
      androidVersion: version.isEmpty ? 'Unknown' : version,
      sdkInt: sdkInt,
      battery: level == null ? 'Unknown' : '$level%',
      setupComplete: setupComplete,
    );
  }

  List<String> _parsePackageList(String output) {
    final values = output
        .split(RegExp(r'\r?\n'))
        .where((line) => line.startsWith('package:'))
        .map((line) {
          // pm can return package:name or package:path=name depending on flags.
          final value = line.substring(8).trim();
          final equals = value.lastIndexOf('=');
          return equals >= 0 ? value.substring(equals + 1).trim() : value;
        })
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }

  Future<PackageInventory> packageInventory(
    String deviceId, {
    int? sdkInt,
  }) async {
    final result = await _shell(deviceId, ['pm', 'list', 'packages']);
    if (result.exitCode != 0) {
      throw AdbException(result.stderr.toString().trim());
    }
    final packages = _parsePackageList(result.stdout.toString());

    final apexPackages = <String>{};
    // APEX/Mainline appeared in Android 10 (API 29). --apex-only does not
    // exist on older versions, so only probe where it can be useful and treat
    // unsupported-command failures as an empty set.
    if (sdkInt == null || sdkInt >= 29) {
      try {
        final apex = await _shell(
          deviceId,
          ['pm', 'list', 'packages', '--apex-only'],
        );
        if (apex.exitCode == 0) {
          apexPackages.addAll(_parsePackageList(apex.stdout.toString()));
        }
      } catch (_) {
        // Fail safe: the static Mainline aliases in package_policy.dart still
        // protect known modules if a vendor shell does not expose this flag.
      }
    }

    return PackageInventory(packages: packages, apexPackages: apexPackages);
  }

  Future<void> backup(
    String deviceId,
    String packageName,
    Directory output, {
    int? sdkInt,
  }) async {
    final pathResult =
        await _shell(deviceId, ['pm', 'path', packageName]);
    if (pathResult.exitCode != 0) {
      throw AdbException('Could not locate APK files for $packageName.');
    }

    final paths = pathResult.stdout
        .toString()
        .split(RegExp(r'\r?\n'))
        .where((line) => line.startsWith('package:'))
        .map((line) => line.substring(8).trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (paths.isEmpty) {
      throw AdbException('No APK path was returned for $packageName.');
    }

    if (await output.exists()) await output.delete(recursive: true);
    await output.create(recursive: true);
    for (final remote in paths) {
      final fileName = remote.split('/').last;
      final local = join(
        output.path,
        [fileName.isEmpty ? 'base.apk' : fileName],
      );
      final pull = await run(
        ['-s', deviceId, 'pull', remote, local],
        timeout: const Duration(minutes: 5),
      );
      if (pull.exitCode != 0) {
        await output.delete(recursive: true);
        throw AdbException(
          'Backup failed for $packageName: ${pull.stderr.toString().trim()}',
        );
      }
    }

    await File(join(output.path, ['metadata.json'])).writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'package': packageName,
        'deviceId': deviceId,
        'androidSdk': sdkInt,
        'createdAt': DateTime.now().toIso8601String(),
      }),
    );
  }

  Future<String?> uninstall(String deviceId, String packageName) async {
    final result = await _shell(
      deviceId,
      ['pm', 'uninstall', '-k', '--user', '0', packageName],
    );
    final text = '${result.stdout}\n${result.stderr}'.trim();
    if (result.exitCode == 0 && text.toLowerCase().contains('success')) {
      return null;
    }
    return text.isEmpty ? 'Unknown uninstall failure.' : text;
  }

  Future<String?> restore(
    String deviceId,
    String packageName,
    Directory backupDir,
  ) async {
    // Modern Android path.
    try {
      final existing = await _shell(
        deviceId,
        ['cmd', 'package', 'install-existing', '--user', '0', packageName],
      );
      final text = '${existing.stdout}\n${existing.stderr}'.toLowerCase();
      if (existing.exitCode == 0 &&
          (text.contains('installed') || text.contains('success'))) {
        return null;
      }
    } catch (_) {
      // Continue to legacy/fallback methods.
    }

    // Some releases expose install-existing directly through pm.
    try {
      final legacy = await _shell(
        deviceId,
        ['pm', 'install-existing', '--user', '0', packageName],
      );
      final text = '${legacy.stdout}\n${legacy.stderr}'.toLowerCase();
      if (legacy.exitCode == 0 &&
          (text.contains('installed') || text.contains('success'))) {
        return null;
      }
    } catch (_) {
      // Continue to the local APK backup.
    }

    if (!await backupDir.exists()) return 'No APK backup is available.';
    final apks = await backupDir
        .list()
        .where((entry) => entry is File && entry.path.toLowerCase().endsWith('.apk'))
        .cast<File>()
        .map((file) => file.path)
        .toList();
    if (apks.isEmpty) return 'No APK backup is available.';

    final List<String> args;
    if (apks.length == 1) {
      args = ['-s', deviceId, 'install', '-r', '-d', apks.first];
    } else {
      args = ['-s', deviceId, 'install-multiple', '-r', '-d', ...apks];
    }
    final result = await run(args, timeout: const Duration(minutes: 5));
    final text = '${result.stdout}\n${result.stderr}'.trim();
    if (result.exitCode == 0 && text.toLowerCase().contains('success')) {
      return null;
    }
    return text.isEmpty ? 'Restore failed.' : text;
  }
}

class BackupStore {
  Directory root(DeviceInfo device) {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    final safeId = device.id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return Directory(
      AdbService.join(home, ['DroidPurifier', 'Backups', safeId]),
    );
  }

  Directory packageDir(DeviceInfo device, String packageName) =>
      Directory(AdbService.join(root(device).path, [packageName]));

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
