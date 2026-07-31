/// Cache / retry policy for rich IP introduction profiles.
abstract final class IpProfileCachePolicy {
  /// Valid profiles change rarely — reuse for a week.
  static const Duration successTtl = Duration(days: 7);

  /// Confirmed server-side absence — short negative cache only.
  static const Duration missingTtl = Duration(minutes: 10);

  /// Malformed docs: avoid hammering; allow recovery after PTR/reconnect/TTL.
  static const Duration malformedTtl = Duration(minutes: 30);

  static const int maxAttempts = 3;

  /// Backoff before attempt 2 and attempt 3 (three total attempts).
  static const Duration backoffAfterAttempt1 = Duration(milliseconds: 500);
  static const Duration backoffAfterAttempt2 = Duration(milliseconds: 1500);

  static Duration? backoffBeforeAttempt(int attemptIndex) {
    // attemptIndex is 0-based; delay applies before attempts 1 and 2.
    return switch (attemptIndex) {
      1 => backoffAfterAttempt1,
      2 => backoffAfterAttempt2,
      _ => null,
    };
  }
}

/// How a profile lookup should contact Firestore.
enum IpProfileFetchMode {
  /// Serve fresh in-memory success/negative cache when possible.
  cacheFirst,

  /// Prefer an explicit server read (pull-to-refresh / reconnect / TTL expiry).
  preferServer,
}
