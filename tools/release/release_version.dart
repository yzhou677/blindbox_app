import 'dart:io';

/// CI versionCode floor.
///
/// Play Store rejects a versionCode that is not strictly greater than the
/// newest code already uploaded. The checked-in pubspec build number is the
/// historical manual code (today `1.0.14+27`, so 27). A brand-new GitHub
/// Actions workflow starts `github.run_number` at 1, which Play would refuse.
///
/// CI codes are `offset + github.run_number` (100001, 100002, ...). Failed
/// runs still consume a run number; gaps are allowed, decreases are not.
/// Keep manual / pubspec build numbers below this offset.
const int releaseVersionCodeOffset = 100000;

/// Highest versionCode the Play Developer API accepts.
const int playStoreMaxVersionCode = 2100000000;

final RegExp _releaseTagPattern = RegExp(
  r'^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
);

class ReleaseVersion {
  const ReleaseVersion({
    required this.tag,
    required this.versionName,
    required this.versionCode,
  });

  /// Tag as pushed, for example `v1.2.3`.
  final String tag;

  /// Android versionName. The leading `v` is stripped.
  final String versionName;

  /// Android versionCode sent to Play.
  final int versionCode;
}

class ReleaseVersionParseException implements Exception {
  ReleaseVersionParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Turns a Git ref or a workflow input into a release tag.
///
/// `refs/tags/v1.2.3` → `v1.2.3`.
/// `v1.2.3` → `v1.2.3`.
/// A branch ref (`refs/heads/...`) or a blank string → null (no tag).
String? releaseTagFromRef(String ref) {
  final trimmed = ref.trim();
  if (trimmed.isEmpty) return null;
  const tagPrefix = 'refs/tags/';
  if (trimmed.startsWith(tagPrefix)) {
    final tag = trimmed.substring(tagPrefix.length).trim();
    return tag.isEmpty ? null : tag;
  }
  if (trimmed.startsWith('refs/')) return null;
  return trimmed;
}

int releaseVersionCodeForRun(int githubRunNumber) {
  if (githubRunNumber < 1) {
    throw ReleaseVersionParseException(
      'github.run_number must be a positive integer, got $githubRunNumber.',
    );
  }
  final code = releaseVersionCodeOffset + githubRunNumber;
  if (code > playStoreMaxVersionCode) {
    throw ReleaseVersionParseException(
      'versionCode $code exceeds the Play Store maximum $playStoreMaxVersionCode.',
    );
  }
  return code;
}

/// Parses a tag-shaped ref into the names Gradle / Play need.
///
/// Accepts `v1.2.3` and `refs/tags/v1.2.3` only. `1.2.3`, `v1.2`,
/// `v1.2.3-beta`, and any branch ref are errors. There is no "latest pubspec"
/// fallback: a release without a tag must stop.
ReleaseVersion parseReleaseVersion({
  required String ref,
  required int githubRunNumber,
}) {
  final tag = releaseTagFromRef(ref);
  if (tag == null) {
    final shown = ref.trim().isEmpty ? '(empty)' : '"${ref.trim()}"';
    throw ReleaseVersionParseException(
      'No release tag. Push a tag like v1.2.3, or pass that exact value to '
      'workflow_dispatch. Got: $shown.',
    );
  }
  final match = _releaseTagPattern.firstMatch(tag);
  if (match == null) {
    throw ReleaseVersionParseException(
      'Illegal release tag "$tag". Expected vMAJOR.MINOR.PATCH, for example '
      'v1.2.3. Pre-release suffixes and a missing "v" are not accepted.',
    );
  }
  return ReleaseVersion(
    tag: tag,
    versionName: '${match.group(1)}.${match.group(2)}.${match.group(3)}',
    versionCode: releaseVersionCodeForRun(githubRunNumber),
  );
}

/// Writes `tag`, `version_name`, and `version_code` for a later workflow step.
///
/// Reads `RELEASE_REF` and `RELEASE_RUN_NUMBER`. When `GITHUB_OUTPUT` is set
/// (Actions), the values are appended there. Nothing secret is printed.
void main() {
  final ref = Platform.environment['RELEASE_REF'] ?? '';
  final runRaw = Platform.environment['RELEASE_RUN_NUMBER'] ?? '';
  final runNumber = int.tryParse(runRaw.trim());
  try {
    if (runNumber == null) {
      throw ReleaseVersionParseException(
        'RELEASE_RUN_NUMBER must be a positive integer, got '
        '"${runRaw.trim()}".',
      );
    }
    final parsed = parseReleaseVersion(ref: ref, githubRunNumber: runNumber);
    final lines = [
      'tag=${parsed.tag}',
      'version_name=${parsed.versionName}',
      'version_code=${parsed.versionCode}',
    ];
    final outputPath = Platform.environment['GITHUB_OUTPUT'];
    if (outputPath != null && outputPath.isNotEmpty) {
      File(
        outputPath,
      ).writeAsStringSync('${lines.join('\n')}\n', mode: FileMode.append);
    }
    stdout.writeln(
      'Release versionName=${parsed.versionName} '
      'versionCode=${parsed.versionCode} tag=${parsed.tag}',
    );
  } on ReleaseVersionParseException catch (error) {
    stderr.writeln('::error::${error.message}');
    exitCode = 1;
  }
}
