import 'package:blindbox_app/features/ip_profile/domain/ip_introduction_profile.dart';

const String kIpProfilesCollection = 'ip_profiles';

/// Maps a Firestore `ip_profiles/{ipId}` document into a presentation profile.
///
/// Returns `null` when the document is missing required rich fields (callers
/// hide the Discover info icon). Never uses display names as identity.
IpIntroductionProfile? mapIpIntroductionProfile({
  required String documentId,
  required Map<String, dynamic>? data,
}) {
  final ipId = documentId.trim();
  if (ipId.isEmpty || data == null) return null;

  final marketing = _readString(data, 'marketingDisplayName');
  final display = _readString(data, 'displayName');
  final name = marketing.isNotEmpty ? marketing : display;
  if (name.isEmpty) return null;

  final shortDescription = _readString(data, 'shortDescription');
  if (shortDescription.isEmpty) return null;

  final tags = _readStyleTags(data['styleTags']);
  if (tags.length != 3) return null;

  final creator = data['creator'];
  String? creatorName;
  String? creatorBio;
  if (creator is Map) {
    final map = Map<String, dynamic>.from(creator);
    creatorName = _readString(map, 'displayName');
    if (creatorName.isEmpty) {
      creatorName = _readString(map, 'name');
    }
    creatorBio = _readString(map, 'bio');
    if (creatorBio.isEmpty) {
      creatorBio = _readString(map, 'shortBio');
    }
  }

  final profile = IpIntroductionProfile(
    ipId: ipId,
    displayName: name,
    shortDescription: shortDescription,
    styleTags: tags,
    creatorDisplayName: (creatorName == null || creatorName.isEmpty)
        ? null
        : creatorName,
    creatorBio: (creatorBio == null || creatorBio.isEmpty) ? null : creatorBio,
  );
  return profile.isValidForIntroduction ? profile : null;
}

String _readString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is String) return value.trim();
  return '';
}

List<String> _readStyleTags(Object? raw) {
  if (raw is! List) return const [];
  final out = <String>[];
  for (final item in raw) {
    if (item is! String) continue;
    final tag = item.trim();
    if (tag.isEmpty) continue;
    out.add(tag);
  }
  return out;
}
