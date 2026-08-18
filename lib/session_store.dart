import 'dart:convert';
import 'dart:io';

import 'adb_service.dart';

class RemovalSession {
  const RemovalSession({
    required this.id,
    required this.createdAt,
    required this.preset,
    required this.requestedPackages,
    required this.removedPackages,
    required this.failures,
    required this.backupEnabled,
    required this.healthPassed,
  });

  final String id;
  final DateTime createdAt;
  final String preset;
  final List<String> requestedPackages;
  final List<String> removedPackages;
  final Map<String, String> failures;
  final bool backupEnabled;
  final bool healthPassed;

  Map<String, Object?> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'preset': preset,
        'requestedPackages': requestedPackages,
        'removedPackages': removedPackages,
        'failures': failures,
        'backupEnabled': backupEnabled,
        'healthPassed': healthPassed,
      };

  factory RemovalSession.fromJson(Map<String, dynamic> json) {
    return RemovalSession(
      id: json['id']?.toString() ?? 'unknown',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      preset: json['preset']?.toString() ?? 'Manual',
      requestedPackages: (json['requestedPackages'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      removedPackages: (json['removedPackages'] as List<dynamic>? ?? const [])
          .map((value) => value.toString())
          .toList(),
      failures: (json['failures'] as Map<dynamic, dynamic>? ?? const {})
          .map((key, value) => MapEntry(key.toString(), value.toString())),
      backupEnabled: json['backupEnabled'] == true,
      healthPassed: json['healthPassed'] == true,
    );
  }
}

class SessionStore {
  String _safeDeviceId(String id) =>
      id.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  Directory _baseRoot() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    return Directory(AdbService.join(home, ['DroidPurifier']));
  }

  Directory sessionRoot(DeviceInfo device) => Directory(
        AdbService.join(
          _baseRoot().path,
          ['Sessions', _safeDeviceId(device.id)],
        ),
      );

  Directory reportRoot() =>
      Directory(AdbService.join(_baseRoot().path, ['Reports']));

  Future<void> save(DeviceInfo device, RemovalSession session) async {
    final root = sessionRoot(device);
    await root.create(recursive: true);
    final file = File(AdbService.join(root.path, ['${session.id}.json']));
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(session.toJson()),
    );
  }

  Future<List<RemovalSession>> list(DeviceInfo device) async {
    final root = sessionRoot(device);
    if (!await root.exists()) return [];
    final sessions = <RemovalSession>[];
    await for (final entity in root.list()) {
      if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
        continue;
      }
      try {
        final decoded = jsonDecode(await entity.readAsString());
        if (decoded is Map<String, dynamic>) {
          sessions.add(RemovalSession.fromJson(decoded));
        }
      } catch (_) {
        // Ignore corrupted history entries instead of breaking Restore.
      }
    }
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  Future<File> exportReport(
    DeviceInfo device,
    Map<String, Object?> report,
  ) async {
    final root = reportRoot();
    await root.create(recursive: true);
    final stamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final safeModel = device.model.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final file = File(
      AdbService.join(root.path, ['DroidPurifier-$safeModel-$stamp.json']),
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
    return file;
  }
}
