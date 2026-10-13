import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:open_remote_control/src/client/updates/android_update_models.dart';
import 'package:open_remote_control/src/client/updates/android_update_repository.dart';

void main() {
  group('AndroidUpdateRepository', () {
    test(
      'selects the next compatible stable release without APK download',
      () async {
        final http = _FakeHttp(
          releases: [
            _release('1.2.0', catalogUrl: _catalogUrl('1.2.0')),
            _release('1.1.0', catalogUrl: _catalogUrl('1.1.0')),
            _release('9.0.0', prerelease: true),
            _release('8.0.0', draft: true),
          ],
          catalogs: {
            '1.2.0': _catalog('1.2.0', abis: ['x86_64']),
            '1.1.0': _catalog('1.1.0'),
          },
        );

        final result = await AndroidUpdateRepository(
          httpClient: http,
        ).check(_device());

        expect(result.candidate?.versionName, '1.1.0');
        expect(result.candidate?.versionCode, 12);
        expect(result.candidate?.downloadUrl, _apkUrl('1.1.0'));
        expect(http.requestedUrls, contains(_catalogUrl('1.2.0')));
        expect(http.requestedUrls, contains(_catalogUrl('1.1.0')));
        expect(
          http.requestedUrls.where((url) => url.contains('.apk')),
          isEmpty,
        );
      },
    );

    test('reports up to date when there is no stable newer release', () async {
      final http = _FakeHttp(
        releases: [
          _release('2.0.0', prerelease: true),
          _release('1.0.1', draft: true),
          _release('nightly', tag: 'nightly'),
        ],
      );

      final result = await AndroidUpdateRepository(
        httpClient: http,
      ).check(_device());

      expect(result.upToDate, isTrue);
      expect(http.requestedUrls, hasLength(1));
    });

    test(
      'orders numeric semver components instead of comparing strings',
      () async {
        final http = _FakeHttp(
          releases: [
            _release('1.9.0', catalogUrl: _catalogUrl('1.9.0')),
            _release('1.10.0', catalogUrl: _catalogUrl('1.10.0')),
          ],
          catalogs: {'1.9.0': _catalog('1.9.0'), '1.10.0': _catalog('1.10.0')},
        );

        final result = await AndroidUpdateRepository(
          httpClient: http,
        ).check(_device());
        expect(result.candidate?.versionName, '1.10.0');
      },
    );

    test('accepts Android ABI names containing hyphens', () async {
      final http = _FakeHttp(
        releases: [_release('1.1.0', catalogUrl: _catalogUrl('1.1.0'))],
        catalogs: {
          '1.1.0': _catalog('1.1.0', abis: ['arm64-v8a', 'armeabi-v7a']),
        },
      );

      final result = await AndroidUpdateRepository(
        httpClient: http,
      ).check(_device());

      expect(result.candidate?.versionName, '1.1.0');
      expect(result.candidate?.abis, ['arm64-v8a', 'armeabi-v7a']);
    });

    test(
      'finds a compatible release on a later bounded releases page',
      () async {
        final firstPage = [
          for (var patch = 0; patch < 30; patch++) _release('0.9.$patch'),
        ];
        final http = _FakeHttp(
          releases: firstPage,
          releasePages: [
            firstPage,
            [_release('1.1.0', catalogUrl: _catalogUrl('1.1.0'))],
          ],
          catalogs: {'1.1.0': _catalog('1.1.0')},
        );

        final result = await AndroidUpdateRepository(
          httpClient: http,
        ).check(_device());

        expect(result.candidate?.versionName, '1.1.0');
        expect(
          http.requestedUrls.where((url) => url.contains('api.github.com')),
          hasLength(2),
        );
      },
    );

    test(
      'rejects an APK size or API digest that disagrees with catalog',
      () async {
        final http = _FakeHttp(
          releases: [
            _release(
              '1.1.0',
              catalogUrl: _catalogUrl('1.1.0'),
              apkSize: 999,
              digest: 'a' * 64,
            ),
          ],
          catalogs: {'1.1.0': _catalog('1.1.0')},
        );

        expect(
          () => AndroidUpdateRepository(httpClient: http).check(_device()),
          throwsA(
            isA<AndroidUpdateException>().having(
              (e) => e.code,
              'code',
              'integrity',
            ),
          ),
        );
        expect(
          http.requestedUrls.where((url) => url.contains('.apk')),
          isEmpty,
        );
      },
    );

    test('checks catalog API size and optional SHA-256 digest', () async {
      final catalog = _catalog('1.1.0');
      for (final release in [
        _release('1.1.0', catalogUrl: _catalogUrl('1.1.0'), catalogSize: 1),
        _release(
          '1.1.0',
          catalogUrl: _catalogUrl('1.1.0'),
          catalogDigest: _hex('f'),
        ),
      ]) {
        final http = _FakeHttp(
          releases: [release],
          catalogs: {'1.1.0': catalog},
        );
        await expectLater(
          AndroidUpdateRepository(httpClient: http).check(_device()),
          throwsA(
            isA<AndroidUpdateException>().having(
              (error) => error.code,
              'code',
              'integrity',
            ),
          ),
        );
      }
    });

    test(
      'rejects a catalog URL outside the matching release asset path',
      () async {
        final http = _FakeHttp(
          releases: [
            _release(
              '1.1.0',
              catalogUrl: 'https://attacker.example/android-update.json',
            ),
          ],
        );

        expect(
          () => AndroidUpdateRepository(httpClient: http).check(_device()),
          throwsA(
            isA<AndroidUpdateException>().having(
              (e) => e.code,
              'code',
              'unavailable',
            ),
          ),
        );
        expect(http.requestedUrls, hasLength(1));
      },
    );

    test(
      'rejects signer and ABI mismatches, then returns up to date',
      () async {
        final http = _FakeHttp(
          releases: [
            _release('1.3.0', catalogUrl: _catalogUrl('1.3.0')),
            _release('1.2.0', catalogUrl: _catalogUrl('1.2.0')),
          ],
          catalogs: {
            '1.3.0': _catalog('1.3.0', abis: ['x86_64']),
            '1.2.0': _catalog('1.2.0', signer: 'b' * 64),
          },
        );

        final result = await AndroidUpdateRepository(
          httpClient: http,
        ).check(_device());
        expect(result.upToDate, isTrue);
      },
    );

    test('validates catalog schema, stable semver and version code', () async {
      final http = _FakeHttp(
        releases: [_release('1.1.0', catalogUrl: _catalogUrl('1.1.0'))],
        catalogs: {
          '1.1.0': {..._catalog('1.1.0'), 'versionCode': 9},
        },
      );

      final result = await AndroidUpdateRepository(
        httpClient: http,
      ).check(_device());
      expect(result.upToDate, isTrue);
    });

    test('rejects a malformed or prerelease catalog version', () async {
      final http = _FakeHttp(
        releases: [_release('1.1.0', catalogUrl: _catalogUrl('1.1.0'))],
        catalogs: {
          '1.1.0': {..._catalog('1.1.0'), 'versionName': '1.1.0-rc.1'},
        },
      );

      expect(
        () => AndroidUpdateRepository(httpClient: http).check(_device()),
        throwsA(
          isA<AndroidUpdateException>().having(
            (e) => e.code,
            'code',
            'integrity',
          ),
        ),
      );
    });

    test(
      'known incompatible catalog outweighs malformed older catalog metadata',
      () async {
        final http = _FakeHttp(
          releases: [
            _release('1.2.0', catalogUrl: _catalogUrl('1.2.0')),
            _release('1.1.0', catalogUrl: _catalogUrl('1.1.0')),
          ],
          catalogs: {
            '1.2.0': _catalog('1.2.0', abis: ['x86_64']),
            '1.1.0': {..._catalog('1.1.0'), 'versionName': '1.1.0-rc.1'},
          },
        );

        final result = await AndroidUpdateRepository(
          httpClient: http,
        ).check(_device());
        expect(result.upToDate, isTrue);
      },
    );

    test(
      'rejects target SDK levels blocked by Android device policy',
      () async {
        final http = _FakeHttp(
          releases: [
            _release('1.2.0', catalogUrl: _catalogUrl('1.2.0')),
            _release('1.1.0', catalogUrl: _catalogUrl('1.1.0')),
          ],
          catalogs: {
            '1.2.0': _catalog('1.2.0', targetSdk: 23),
            '1.1.0': _catalog('1.1.0', targetSdk: 22),
          },
        );

        final result = await AndroidUpdateRepository(
          httpClient: http,
        ).check(_device());
        expect(result.upToDate, isTrue);
      },
    );

    test('rejects minimum and maximum SDK mismatches', () async {
      final http = _FakeHttp(
        releases: [
          _release('1.3.0', catalogUrl: _catalogUrl('1.3.0')),
          _release('1.2.0', catalogUrl: _catalogUrl('1.2.0')),
        ],
        catalogs: {
          '1.3.0': _catalog('1.3.0', minSdk: 36),
          '1.2.0': _catalog('1.2.0', maxSdk: 34),
        },
      );

      final result = await AndroidUpdateRepository(
        httpClient: http,
      ).check(_device());
      expect(result.upToDate, isTrue);
    });
  });
}

AndroidUpdateDeviceInfo _device() => AndroidUpdateDeviceInfo(
  packageName: AndroidUpdateRepository.packageName,
  versionName: '1.0.0',
  versionCode: 10,
  sdkInt: 35,
  abis: ['arm64-v8a'],
  signerSha256: [_hex('a')],
);

String _hex(String character) => List.filled(64, character).join();

Map<String, Object?> _catalog(
  String version, {
  List<String> abis = const [],
  String? signer,
  int targetSdk = 35,
  int minSdk = 23,
  int? maxSdk,
}) => {
  'schemaVersion': 1,
  'packageName': AndroidUpdateRepository.packageName,
  'versionName': version,
  'versionCode': 12,
  'minSdk': minSdk,
  'targetSdk': targetSdk,
  'maxSdk': maxSdk,
  'abis': abis,
  'signerSha256': [signer ?? _hex('a')],
  'asset': {
    'name': AndroidUpdateRepository.apkName,
    'size': 1024,
    'sha256': _hex('c'),
  },
};

String _catalogUrl(String version) =>
    'https://github.com/leobrqz/OpenRemoteControl/releases/download/v$version/android-update.json';
String _apkUrl(String version) =>
    'https://github.com/leobrqz/OpenRemoteControl/releases/download/v$version/${AndroidUpdateRepository.apkName}';

Map<String, Object?> _release(
  String version, {
  String? tag,
  bool prerelease = false,
  bool draft = false,
  String? catalogUrl,
  int catalogSize = 500,
  String? catalogDigest,
  int apkSize = 1024,
  String? digest,
}) {
  final releaseTag = tag ?? 'v$version';
  final base =
      'https://github.com/leobrqz/OpenRemoteControl/releases/download/$releaseTag';
  return {
    'tag_name': releaseTag,
    'html_url':
        'https://github.com/leobrqz/OpenRemoteControl/releases/tag/$releaseTag',
    'draft': draft,
    'prerelease': prerelease,
    'body': 'Notes for $version',
    'assets': [
      if (catalogUrl != null)
        {
          'name': AndroidUpdateRepository.catalogName,
          'browser_download_url': catalogUrl,
          'size': catalogSize,
          if (catalogDigest != null) 'digest': 'sha256:$catalogDigest',
        },
      {
        'name': AndroidUpdateRepository.apkName,
        'browser_download_url': '$base/${AndroidUpdateRepository.apkName}',
        'size': apkSize,
        if (digest != null) 'digest': 'sha256:$digest',
      },
    ],
  };
}

class _FakeHttp implements AndroidUpdateHttpClient {
  _FakeHttp({
    required List<Map<String, Object?>> releases,
    List<List<Map<String, Object?>>>? releasePages,
    this.catalogs = const {},
  }) : releasePages = releasePages ?? [releases] {
    for (final page in this.releasePages) {
      for (final release in page) {
        final assets = release['assets'];
        if (assets is! List) continue;
        for (final rawAsset in assets) {
          if (rawAsset is! Map ||
              rawAsset['name'] != AndroidUpdateRepository.catalogName ||
              rawAsset['size'] != 500) {
            continue;
          }
          final url = rawAsset['browser_download_url'];
          if (url is! String) continue;
          final match = RegExp(
            r'/download/v([^/]+)/android-update\.json$',
          ).firstMatch(Uri.parse(url).path);
          final catalog = match == null ? null : catalogs[match.group(1)];
          if (catalog != null) {
            rawAsset['size'] = utf8.encode(jsonEncode(catalog)).length;
          }
        }
      }
    }
  }

  final List<List<Map<String, Object?>>> releasePages;
  final Map<String, Map<String, Object?>> catalogs;
  final requestedUrls = <String>[];

  @override
  Future<AndroidUpdateHttpResponse> get(
    Uri uri, {
    required int maxBytes,
  }) async {
    requestedUrls.add(uri.toString());
    if (uri.host == 'api.github.com') {
      final page = int.tryParse(uri.queryParameters['page'] ?? '1') ?? 1;
      final index = page - 1;
      return _json(
        index >= 0 && index < releasePages.length
            ? releasePages[index]
            : const <Object?>[],
      );
    }
    final match = RegExp(
      r'/download/v([^/]+)/android-update\.json$',
    ).firstMatch(uri.path);
    final version = match?.group(1);
    if (version == null || !catalogs.containsKey(version)) {
      return const AndroidUpdateHttpResponse(statusCode: 404, body: []);
    }
    return _json(catalogs[version]!);
  }

  AndroidUpdateHttpResponse _json(Object value) => AndroidUpdateHttpResponse(
    statusCode: 200,
    body: utf8.encode(jsonEncode(value)),
    headers: const {'content-type': 'application/json'},
  );
}
