import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import 'android_update_models.dart';

class AndroidUpdateHttpResponse {
  const AndroidUpdateHttpResponse({
    required this.statusCode,
    required this.body,
    this.headers = const {},
  });

  final int statusCode;
  final List<int> body;
  final Map<String, String> headers;
}

/// Injectable HTTP boundary so repository policy can be tested without a socket.
abstract interface class AndroidUpdateHttpClient {
  Future<AndroidUpdateHttpResponse> get(Uri uri, {required int maxBytes});
}

class IoAndroidUpdateHttpClient implements AndroidUpdateHttpClient {
  IoAndroidUpdateHttpClient({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<AndroidUpdateHttpResponse> get(
    Uri uri, {
    required int maxBytes,
  }) async {
    var next = uri;
    for (var redirects = 0; ; redirects++) {
      _validateTransportUri(next, initial: uri);
      final request = await _client
          .getUrl(next)
          .timeout(const Duration(seconds: 12));
      request.followRedirects = false;
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'OpenRemoteControl-Android',
      );
      request.headers.set('X-GitHub-Api-Version', '2022-11-28');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      final headers = <String, String>{};
      response.headers.forEach((name, values) {
        headers[name.toLowerCase()] = values.join(',');
      });
      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null || redirects >= 3) {
          throw const AndroidUpdateException('unavailable');
        }
        next = next.resolve(location);
        continue;
      }
      final body = <int>[];
      try {
        await for (final chunk in response.timeout(
          const Duration(seconds: 20),
        )) {
          if (body.length + chunk.length > maxBytes) {
            throw const AndroidUpdateException('integrity');
          }
          body.addAll(chunk);
        }
      } on TimeoutException {
        throw const AndroidUpdateException('network');
      }
      return AndroidUpdateHttpResponse(
        statusCode: response.statusCode,
        body: body,
        headers: headers,
      );
    }
  }

  static void _validateTransportUri(Uri uri, {required Uri initial}) {
    if (uri.scheme != 'https' || uri.userInfo.isNotEmpty || uri.hasPort) {
      throw const AndroidUpdateException('unavailable');
    }
    final host = uri.host.toLowerCase();
    final initialHost = initial.host.toLowerCase();
    final allowed = initialHost == 'api.github.com'
        ? host == 'api.github.com' &&
              uri.path == initial.path &&
              uri.query == initial.query
        : initialHost == 'github.com' &&
              (host == 'github.com'
                  ? uri.path == initial.path
                  : host == 'release-assets.githubusercontent.com' ||
                        host == 'objects.githubusercontent.com');
    if (!allowed) throw const AndroidUpdateException('unavailable');
  }
}

class AndroidUpdateRepository {
  AndroidUpdateRepository({AndroidUpdateHttpClient? httpClient})
    : _httpClient = httpClient ?? IoAndroidUpdateHttpClient();

  static const owner = 'leobrqz';
  static const repository = 'OpenRemoteControl';
  static const packageName = 'org.openremotecontrol.open_remote_control';
  static const catalogName = 'android-update.json';
  static const apkName = 'OpenRemoteControl-Android-universal-release.apk';
  static const _releasePageSize = 30;
  static const _maxReleasePages = 6;
  static const _releaseListUrl =
      'https://api.github.com/repos/$owner/$repository/releases';
  static const _maxReleaseListBytes = 1024 * 1024;
  static const _maxCatalogBytes = 64 * 1024;
  static const _maxApkBytes = 200 * 1024 * 1024;

  final AndroidUpdateHttpClient _httpClient;

  Future<AndroidUpdateCheckResult> check(AndroidUpdateDeviceInfo device) async {
    try {
      final rawReleases = <Object?>[];
      var releaseListTruncated = false;
      for (var page = 1; page <= _maxReleasePages; page++) {
        final pageUrl = Uri.parse(_releaseListUrl).replace(
          queryParameters: {'per_page': '$_releasePageSize', 'page': '$page'},
        );
        final response = await _get(pageUrl, maxBytes: _maxReleaseListBytes);
        if (response.statusCode != 200) {
          throw const AndroidUpdateException('network');
        }
        final decoded = _decodeJson(response.body, _maxReleaseListBytes);
        if (decoded is! List || decoded.length > _releasePageSize) {
          throw const AndroidUpdateException('integrity');
        }
        rawReleases.addAll(decoded);
        if (decoded.length < _releasePageSize) break;
        if (page == _maxReleasePages) releaseListTruncated = true;
      }
      final releases = <_Release>[];
      for (final item in rawReleases) {
        if (item is! Map) continue;
        final release = _Release.tryParse(item);
        if (release != null &&
            !release.draft &&
            !release.prerelease &&
            _isStableVersionTag(release.tag) &&
            _isReleaseUrl(release.url, release.tag)) {
          final version = StableVersion.tryParse(release.versionName);
          if (version != null &&
              _tagVersion(release.tag) == release.versionName &&
              version.compareTo(StableVersion.parse(device.versionName)) > 0) {
            releases.add(release);
          }
        }
      }
      releases.sort(
        (a, b) => StableVersion.parse(
          b.versionName,
        ).compareTo(StableVersion.parse(a.versionName)),
      );

      String? lastFailure = releaseListTruncated ? 'unavailable' : null;
      var sawUnavailable = releaseListTruncated;
      var sawAssetIntegrityFailure = false;
      var sawMalformedMetadata = false;
      var sawKnownIncompatibleRelease = false;
      for (final release in releases) {
        final candidate = release.asset(catalogName);
        if (candidate == null) {
          lastFailure = 'unavailable';
          sawUnavailable = true;
          continue;
        }
        if (!_isReleaseAssetUrl(candidate.url, release.tag, catalogName) ||
            candidate.size == null ||
            candidate.size! < 1 ||
            candidate.size! > 64 * 1024) {
          lastFailure = 'unavailable';
          sawUnavailable = true;
          continue;
        }
        try {
          final catalogResponse = await _get(
            Uri.parse(candidate.url),
            maxBytes: _maxCatalogBytes,
          );
          if (catalogResponse.statusCode != 200) {
            lastFailure = 'unavailable';
            sawUnavailable = true;
            continue;
          }
          if (catalogResponse.body.length != candidate.size) {
            lastFailure = 'integrity';
            sawAssetIntegrityFailure = true;
            continue;
          }
          if (candidate.digest != null) {
            final digest = await Sha256().hash(catalogResponse.body);
            final actual =
                'sha256:${digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
            if (actual != candidate.digest) {
              lastFailure = 'integrity';
              sawAssetIntegrityFailure = true;
              continue;
            }
          }
          final catalog = _decodeJson(catalogResponse.body, _maxCatalogBytes);
          if (catalog is! Map) throw const FormatException('catalog object');
          final parsed = _parseCatalog(catalog, release, device);
          if (parsed == null) {
            sawKnownIncompatibleRelease = true;
            continue;
          }
          if (parsed.versionCode <= device.versionCode ||
              StableVersion.parse(
                    parsed.versionName,
                  ).compareTo(StableVersion.parse(device.versionName)) <=
                  0) {
            sawKnownIncompatibleRelease = true;
            continue;
          }
          if (_compatible(parsed, device)) {
            return AndroidUpdateCheckResult(candidate: parsed);
          }
          sawKnownIncompatibleRelease = true;
        } on AndroidUpdateException catch (error) {
          lastFailure = error.code;
          sawUnavailable |= error.code == 'unavailable';
          sawAssetIntegrityFailure |= error.code == 'integrity';
        } on FormatException {
          lastFailure = 'integrity';
          sawMalformedMetadata = true;
        }
      }
      if (sawUnavailable) {
        throw const AndroidUpdateException('unavailable');
      }
      if (sawAssetIntegrityFailure) {
        throw const AndroidUpdateException('integrity');
      }
      if (sawMalformedMetadata && !sawKnownIncompatibleRelease) {
        throw AndroidUpdateException(lastFailure ?? 'integrity');
      }
      return const AndroidUpdateCheckResult();
    } on AndroidUpdateException {
      rethrow;
    } on SocketException {
      throw const AndroidUpdateException('network');
    } on TimeoutException {
      throw const AndroidUpdateException('network');
    } on FormatException {
      throw const AndroidUpdateException('integrity');
    } catch (_) {
      throw const AndroidUpdateException('network');
    }
  }

  Future<AndroidUpdateHttpResponse> _get(
    Uri uri, {
    required int maxBytes,
  }) async {
    try {
      final response = await _httpClient
          .get(uri, maxBytes: maxBytes)
          .timeout(const Duration(seconds: 25));
      if (response.body.length > maxBytes) {
        throw const AndroidUpdateException('integrity');
      }
      return response;
    } on AndroidUpdateException {
      rethrow;
    } on TimeoutException {
      throw const AndroidUpdateException('network');
    } on SocketException {
      throw const AndroidUpdateException('network');
    }
  }

  Object? _decodeJson(List<int> bytes, int limit) {
    if (bytes.length > limit) throw const FormatException('oversize');
    return jsonDecode(utf8.decode(bytes, allowMalformed: false));
  }

  AndroidUpdateCandidate? _parseCatalog(
    Map catalog,
    _Release release,
    AndroidUpdateDeviceInfo device,
  ) {
    if (catalog['schemaVersion'] != 1 ||
        catalog['packageName'] != packageName ||
        catalog['versionName'] != release.versionName ||
        !StableVersion.isStable(catalog['versionName']) ||
        catalog['versionCode'] is! int ||
        catalog['minSdk'] is! int ||
        catalog['targetSdk'] is! int ||
        (catalog['maxSdk'] != null && catalog['maxSdk'] is! int) ||
        catalog['abis'] is! List ||
        catalog['signerSha256'] is! List ||
        catalog['asset'] is! Map) {
      throw const FormatException('catalog schema');
    }
    final assetMap = catalog['asset'] as Map;
    if (assetMap['name'] != apkName ||
        assetMap['size'] is! int ||
        assetMap['sha256'] is! String) {
      throw const FormatException('catalog asset');
    }
    final size = assetMap['size'] as int;
    final hash = (assetMap['sha256'] as String).toLowerCase();
    final asset = release.asset(apkName);
    if (asset == null || !_isReleaseAssetUrl(asset.url, release.tag, apkName)) {
      throw const AndroidUpdateException('unavailable');
    }
    if (size < 1 ||
        size > _maxApkBytes ||
        (asset.size != null && asset.size != size) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('invalid asset dimensions');
    }
    if (asset.digest != null && asset.digest != 'sha256:$hash') {
      throw const AndroidUpdateException('integrity');
    }
    final code = catalog['versionCode'] as int;
    final minSdk = catalog['minSdk'] as int;
    final targetSdk = catalog['targetSdk'] as int;
    final maxSdk = catalog['maxSdk'] as int?;
    if (code < 1 ||
        minSdk < 1 ||
        targetSdk < 1 ||
        minSdk > 1000 ||
        targetSdk > 1000 ||
        (maxSdk != null && (maxSdk < minSdk || maxSdk > 1000))) {
      throw const FormatException('invalid sdk/version code');
    }
    final abis = (catalog['abis'] as List).cast<Object?>();
    if (abis.length > 16 ||
        abis.any(
          (value) =>
              value is! String ||
              !RegExp(r'^[A-Za-z0-9_-]{1,32}$').hasMatch(value),
        )) {
      throw const FormatException('invalid abis');
    }
    final signers = (catalog['signerSha256'] as List).cast<Object?>();
    if (signers.isEmpty ||
        signers.length > 8 ||
        signers.any(
          (value) =>
              value is! String || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value),
        )) {
      throw const FormatException('invalid signers');
    }
    final apk = release.asset(apkName)!;
    final releaseNotes = release.notes.length > 12000
        ? release.notes.substring(0, 12000)
        : release.notes;
    return AndroidUpdateCandidate(
      packageName: packageName,
      versionName: release.versionName,
      versionCode: code,
      minSdk: minSdk,
      targetSdk: targetSdk,
      maxSdk: maxSdk,
      abis: abis.cast<String>(),
      signerSha256: signers.cast<String>().map((value) => value.toLowerCase()),
      assetName: apk.name,
      size: size,
      sha256: hash,
      downloadUrl: apk.url,
      notes: releaseNotes,
      releaseUrl: release.url,
    );
  }

  bool _compatible(
    AndroidUpdateCandidate candidate,
    AndroidUpdateDeviceInfo d,
  ) {
    if (candidate.packageName != d.packageName ||
        d.sdkInt < candidate.minSdk ||
        (candidate.maxSdk != null && d.sdkInt > candidate.maxSdk!) ||
        (d.sdkInt >= 34 && candidate.targetSdk < 23) ||
        (d.sdkInt >= 35 && candidate.targetSdk < 24)) {
      return false;
    }
    if (candidate.abis.isNotEmpty &&
        !candidate.abis.any((abi) => d.abis.contains(abi))) {
      return false;
    }
    final expected = candidate.signerSha256.toSet();
    final installed = d.signerSha256
        .map((value) => value.toLowerCase())
        .toSet();
    return installed.isNotEmpty &&
        expected.length == candidate.signerSha256.length &&
        expected.length == installed.length &&
        expected.containsAll(installed);
  }

  static bool _isStableVersionTag(String tag) => tag.startsWith('v')
      ? StableVersion.isStable(tag.substring(1))
      : StableVersion.isStable(tag);

  static String _tagVersion(String tag) =>
      tag.startsWith('v') ? tag.substring(1) : tag;

  static bool _isReleaseUrl(String value, String tag) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.pathSegments.length == 5 &&
        uri.pathSegments[0] == owner &&
        uri.pathSegments[1] == repository &&
        uri.pathSegments[2] == 'releases' &&
        uri.pathSegments[3] == 'tag' &&
        uri.pathSegments[4] == tag;
  }

  static bool _isReleaseAssetUrl(String value, String tag, String name) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'github.com' &&
        uri.userInfo.isEmpty &&
        !uri.hasPort &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.pathSegments.length == 6 &&
        uri.pathSegments[0] == owner &&
        uri.pathSegments[1] == repository &&
        uri.pathSegments[2] == 'releases' &&
        uri.pathSegments[3] == 'download' &&
        uri.pathSegments[4] == tag &&
        uri.pathSegments[5] == name;
  }
}

class StableVersion implements Comparable<StableVersion> {
  StableVersion(this.major, this.minor, this.patch);
  final BigInt major;
  final BigInt minor;
  final BigInt patch;

  static final _pattern = RegExp(r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$');

  static bool isStable(Object? value) =>
      value is String && value.length <= 256 && _pattern.hasMatch(value);

  static StableVersion? tryParse(Object? value) {
    if (value is! String || value.length > 256) return null;
    final match = _pattern.firstMatch(value);
    if (match == null) return null;
    final parts = [for (var i = 1; i <= 3; i++) BigInt.tryParse(match[i]!)];
    if (parts.any((part) => part == null)) return null;
    return StableVersion(parts[0]!, parts[1]!, parts[2]!);
  }

  static StableVersion parse(String value) =>
      tryParse(value) ?? (throw const FormatException('Not a stable semver'));

  @override
  int compareTo(StableVersion other) {
    final majorOrder = major.compareTo(other.major);
    if (majorOrder != 0) return majorOrder;
    final minorOrder = minor.compareTo(other.minor);
    return minorOrder != 0 ? minorOrder : patch.compareTo(other.patch);
  }
}

class _Release {
  const _Release({
    required this.tag,
    required this.versionName,
    required this.draft,
    required this.prerelease,
    required this.url,
    required this.notes,
    required this.assets,
  });

  final String tag;
  final String versionName;
  final bool draft;
  final bool prerelease;
  final String url;
  final String notes;
  final List<_ReleaseAsset> assets;

  static _Release? tryParse(Map value) {
    final tag = value['tag_name'];
    final url = value['html_url'];
    final assetsValue = value['assets'];
    final draft = value['draft'];
    final prerelease = value['prerelease'];
    if (tag is! String ||
        url is! String ||
        assetsValue is! List ||
        assetsValue.length > 100 ||
        draft is! bool ||
        prerelease is! bool) {
      return null;
    }
    final version = AndroidUpdateRepository._tagVersion(tag);
    return _Release(
      tag: tag,
      versionName: version,
      draft: draft,
      prerelease: prerelease,
      url: url,
      notes: value['body'] is String ? (value['body'] as String) : '',
      assets: assetsValue
          .whereType<Map>()
          .map(_ReleaseAsset.tryParse)
          .whereType<_ReleaseAsset>()
          .toList(growable: false),
    );
  }

  _ReleaseAsset? asset(String name) {
    for (final candidate in assets) {
      if (candidate.name == name) return candidate;
    }
    return null;
  }
}

class _ReleaseAsset {
  const _ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
    required this.digest,
  });
  final String name;
  final String url;
  final int? size;
  final String? digest;

  static _ReleaseAsset? tryParse(Map value) {
    final name = value['name'];
    final url = value['browser_download_url'];
    final size = value['size'];
    final digestValue = value['digest'];
    String? digest;
    if (digestValue != null) {
      if (digestValue is! String ||
          !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digestValue)) {
        return null;
      }
      digest = digestValue.toLowerCase();
    }
    if (name is! String ||
        url is! String ||
        (size != null && (size is! int || size < 0))) {
      return null;
    }
    return _ReleaseAsset(
      name: name,
      url: url,
      size: size as int?,
      digest: digest,
    );
  }
}
