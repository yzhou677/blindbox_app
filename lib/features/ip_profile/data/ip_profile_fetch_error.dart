// Classifies transport / Firestore failures for bounded IP-profile retries.
// Lives in data (not domain): classification inspects Firebase / IO exception
// types at the repository boundary.
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';

enum IpProfileFailureKind { transient, permanent }

IpProfileFailureKind classifyIpProfileFailure(Object error) {
  if (error is TimeoutException) return IpProfileFailureKind.transient;
  if (error is SocketException) return IpProfileFailureKind.transient;
  if (error is HttpException) return IpProfileFailureKind.transient;
  if (error is HandshakeException) return IpProfileFailureKind.transient;

  if (error is FirebaseException) {
    final code = error.code.toLowerCase();
    switch (code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'resource-exhausted':
      case 'aborted':
      case 'cancelled':
      case 'internal':
      case 'unknown':
      case 'network-request-failed':
        return IpProfileFailureKind.transient;
      case 'permission-denied':
      case 'unauthenticated':
      case 'invalid-argument':
      case 'failed-precondition':
      case 'data-loss':
      case 'already-exists':
        return IpProfileFailureKind.permanent;
      default:
        // Prefer retry for unfamiliar transport-ish codes.
        if (code.contains('network') || code.contains('unavailable')) {
          return IpProfileFailureKind.transient;
        }
        return IpProfileFailureKind.permanent;
    }
  }

  final text = error.toString().toLowerCase();
  if (text.contains('socket') ||
      text.contains('network') ||
      text.contains('timed out') ||
      text.contains('timeout') ||
      text.contains('unavailable') ||
      text.contains('connection')) {
    return IpProfileFailureKind.transient;
  }

  return IpProfileFailureKind.permanent;
}

bool isTransientIpProfileFailure(Object error) =>
    classifyIpProfileFailure(error) == IpProfileFailureKind.transient;
