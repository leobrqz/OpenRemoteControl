import 'dart:collection';

/// Metadata supplied by Android's PackageManager and Build APIs.
class AndroidUpdateDeviceInfo {
  const AndroidUpdateDeviceInfo({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.sdkInt,
    required this.abis,
    required this.signerSha256,
  });

  final String packageName;
  final String versionName;
  final int versionCode;
  final int sdkInt;
  final List<String> abis;
  final List<String> signerSha256;

  factory AndroidUpdateDeviceInfo.fromMap(Map<Object?, Object?> map) {
    String stringValue(String key) {
      final value = map[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Invalid device field: $key');
      }
      return value.trim();
    }

    int intValue(String key) {
      final value = map[key];
      if (value is int && value > 0) return value;
      throw FormatException('Invalid device field: $key');
    }

    List<String> strings(String key) {
      final value = map[key];
      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException('Invalid device field: $key');
      }
      return List.unmodifiable(value.cast<String>());
    }

    return AndroidUpdateDeviceInfo(
      packageName: stringValue('packageName'),
      versionName: stringValue('versionName'),
      versionCode: intValue('versionCode'),
      sdkInt: intValue('sdkInt'),
      abis: strings('abis'),
      signerSha256: strings(
        'signerSha256',
      ).map((value) => value.toLowerCase()).toList(growable: false),
    );
  }
}

/// One stable, verified release that Android can install on this device.
class AndroidUpdateCandidate {
  AndroidUpdateCandidate({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.minSdk,
    required this.targetSdk,
    required this.maxSdk,
    required Iterable<String> abis,
    required Iterable<String> signerSha256,
    required this.assetName,
    required this.size,
    required this.sha256,
    required this.downloadUrl,
    required this.notes,
    required this.releaseUrl,
  }) : abis = List.unmodifiable(abis),
       signerSha256 = List.unmodifiable(signerSha256);

  final String packageName;
  final String versionName;
  final int versionCode;
  final int minSdk;
  final int targetSdk;
  final int? maxSdk;
  final List<String> abis;
  final List<String> signerSha256;
  final String assetName;
  final int size;
  final String sha256;
  final String downloadUrl;
  final String notes;
  final String releaseUrl;

  Map<String, Object?> toNativeMap() => {
    'packageName': packageName,
    'versionName': versionName,
    'versionCode': versionCode,
    'minSdk': minSdk,
    'targetSdk': targetSdk,
    'maxSdk': maxSdk,
    'abis': abis,
    'signerSha256': signerSha256,
    'asset': {'name': assetName, 'size': size, 'sha256': sha256},
    'size': size,
    'sha256': sha256,
    'downloadUrl': downloadUrl,
    'notes': notes,
    'releaseUrl': releaseUrl,
  };

  factory AndroidUpdateCandidate.fromNativeMap(Map<Object?, Object?> map) {
    final asset = map['asset'];
    if (asset is! Map) throw const FormatException('Invalid candidate asset');
    String stringValue(Map source, String key) {
      final value = source[key];
      if (value is! String) throw FormatException('Invalid candidate $key');
      return value;
    }

    int intValue(Map source, String key) {
      final value = source[key];
      if (value is! int) throw FormatException('Invalid candidate $key');
      return value;
    }

    List<String> strings(String key) {
      final value = map[key];
      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException('Invalid candidate $key');
      }
      return value.cast<String>();
    }

    final maxSdk = map['maxSdk'];
    if (maxSdk != null && maxSdk is! int) {
      throw const FormatException('Invalid candidate maxSdk');
    }
    final size = intValue(asset, 'size');
    final sha256 = stringValue(asset, 'sha256');
    return AndroidUpdateCandidate(
      packageName: stringValue(map, 'packageName'),
      versionName: stringValue(map, 'versionName'),
      versionCode: intValue(map, 'versionCode'),
      minSdk: intValue(map, 'minSdk'),
      targetSdk: intValue(map, 'targetSdk'),
      maxSdk: maxSdk as int?,
      abis: strings('abis'),
      signerSha256: strings('signerSha256'),
      assetName: stringValue(asset, 'name'),
      size: size,
      sha256: sha256,
      downloadUrl: stringValue(map, 'downloadUrl'),
      notes: stringValue(map, 'notes'),
      releaseUrl: stringValue(map, 'releaseUrl'),
    );
  }
}

enum AndroidUpdateState {
  checking,
  available,
  upToDate,
  deferred,
  idle,
  downloading,
  validating,
  ready,
  installing,
  cancelled,
  failed,
  permissionRequired,
  installationCancelled;

  static AndroidUpdateState fromNative(Object? value) => switch (value) {
    'downloading' => downloading,
    'validating' => validating,
    'ready' => ready,
    'installing' => installing,
    'cancelled' => cancelled,
    'failed' => failed,
    'permissionRequired' => permissionRequired,
    'installationCancelled' => installationCancelled,
    _ => idle,
  };
}

class AndroidUpdateSnapshot {
  const AndroidUpdateSnapshot({
    required this.state,
    required this.receivedBytes,
    required this.totalBytes,
    this.errorCode,
    this.candidate,
  });

  final AndroidUpdateState state;
  final int receivedBytes;
  final int totalBytes;
  final String? errorCode;
  final AndroidUpdateCandidate? candidate;

  double? get progress =>
      totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;

  factory AndroidUpdateSnapshot.fromMap(Map<Object?, Object?> map) {
    int count(String key) => map[key] is int ? map[key] as int : 0;
    final candidateMap = map['candidate'];
    return AndroidUpdateSnapshot(
      state: AndroidUpdateState.fromNative(map['state']),
      receivedBytes: count('receivedBytes'),
      totalBytes: count('totalBytes'),
      errorCode: map['errorCode'] is String ? map['errorCode'] as String : null,
      candidate: candidateMap is Map
          ? AndroidUpdateCandidate.fromNativeMap(candidateMap)
          : null,
    );
  }
}

/// A small immutable result returned after checking GitHub metadata.
class AndroidUpdateCheckResult {
  const AndroidUpdateCheckResult({this.candidate});

  final AndroidUpdateCandidate? candidate;
  bool get upToDate => candidate == null;
}

class AndroidUpdateException implements Exception {
  const AndroidUpdateException(this.code);
  final String code;
  @override
  String toString() => 'AndroidUpdateException($code)';
}

/// A string map that cannot be modified by notification callers.
Map<String, String> immutableNotification(Map<String, String> input) =>
    UnmodifiableMapView(Map<String, String>.of(input));
