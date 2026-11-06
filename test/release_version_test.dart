import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tools/release/release_version.dart';

void main() {
  group('parseReleaseVersion normal tags', () {
    test('v1.2.3 becomes versionName 1.2.3 and a CI versionCode', () {
      final parsed = parseReleaseVersion(ref: 'v1.2.3', githubRunNumber: 1);

      expect(parsed.tag, 'v1.2.3');
      expect(parsed.versionName, '1.2.3');
      expect(parsed.versionCode, releaseVersionCodeOffset + 1);
    });

    test('refs/tags/v1.0.14 strips the Git ref prefix', () {
      final parsed = parseReleaseVersion(
        ref: 'refs/tags/v1.0.14',
        githubRunNumber: 8,
      );

      expect(parsed.tag, 'v1.0.14');
      expect(parsed.versionName, '1.0.14');
      expect(parsed.versionCode, 100008);
    });

    test('surrounding whitespace is ignored', () {
      final parsed = parseReleaseVersion(ref: '  v2.0.0  ', githubRunNumber: 3);

      expect(parsed.versionName, '2.0.0');
      expect(parsed.versionCode, 100003);
    });

    test('v0.0.0 is a real release tag', () {
      final parsed = parseReleaseVersion(ref: 'v0.0.0', githubRunNumber: 1);

      expect(parsed.versionName, '0.0.0');
    });
  });

  group('parseReleaseVersion missing tag', () {
    test('an empty ref is not a release', () {
      expect(
        () => parseReleaseVersion(ref: '', githubRunNumber: 1),
        throwsA(
          isA<ReleaseVersionParseException>().having(
            (error) => error.message,
            'message',
            contains('No release tag'),
          ),
        ),
      );
    });

    test('whitespace only is not a release', () {
      expect(
        () => parseReleaseVersion(ref: '   ', githubRunNumber: 1),
        throwsA(
          isA<ReleaseVersionParseException>().having(
            (error) => error.message,
            'message',
            contains('(empty)'),
          ),
        ),
      );
    });

    test('a branch ref is not a release', () {
      expect(
        () => parseReleaseVersion(ref: 'refs/heads/main', githubRunNumber: 1),
        throwsA(
          isA<ReleaseVersionParseException>().having(
            (error) => error.message,
            'message',
            contains('No release tag'),
          ),
        ),
      );
    });

    test('refs/tags/ with nothing after the prefix is not a release', () {
      expect(
        () => parseReleaseVersion(ref: 'refs/tags/', githubRunNumber: 1),
        throwsA(isA<ReleaseVersionParseException>()),
      );
    });
  });

  group('parseReleaseVersion illegal tags', () {
    for (final tag in [
      '1.2.3',
      'v1.2',
      'v1',
      'v1.2.3-beta',
      'v1.2.3+27',
      'V1.2.3',
      'v01.2.3',
      'v1.02.3',
      'vv1.2.3',
    ]) {
      test('"$tag" is rejected', () {
        expect(
          () => parseReleaseVersion(ref: tag, githubRunNumber: 1),
          throwsA(
            isA<ReleaseVersionParseException>().having(
              (error) => error.message,
              'message',
              contains('Illegal release tag'),
            ),
          ),
        );
      });
    }
  });

  group('versionCode', () {
    test('stays above the build number checked in to pubspec', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*\d+\.\d+\.\d+\+(\d+)\s*$',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull, reason: 'pubspec.yaml version: line');
      final buildNumber = int.parse(match!.group(1)!);

      expect(releaseVersionCodeOffset, greaterThan(buildNumber));
      expect(releaseVersionCodeForRun(1), greaterThan(buildNumber));
      expect(releaseVersionCodeForRun(1), releaseVersionCodeOffset + 1);
    });

    test('run number 0 is rejected', () {
      expect(
        () => releaseVersionCodeForRun(0),
        throwsA(
          isA<ReleaseVersionParseException>().having(
            (error) => error.message,
            'message',
            contains('positive integer'),
          ),
        ),
      );
    });

    test('a negative run number is rejected', () {
      expect(
        () => parseReleaseVersion(ref: 'v1.2.3', githubRunNumber: -1),
        throwsA(isA<ReleaseVersionParseException>()),
      );
    });
  });
}
