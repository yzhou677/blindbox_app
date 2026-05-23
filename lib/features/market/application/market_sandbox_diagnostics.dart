import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Last Mercari sandbox refresh outcome (debug / emulator testing).
class MarketSandboxDiagnostics {
  const MarketSandboxDiagnostics({
    required this.gatewayUrl,
    required this.mercariListingCount,
    required this.visibleSnapshotCount,
    this.error,
    this.at,
  });

  final String gatewayUrl;
  final int mercariListingCount;
  final int visibleSnapshotCount;
  final String? error;
  final DateTime? at;

  bool get succeeded => error == null && mercariListingCount > 0;
}

final marketSandboxDiagnosticsProvider =
    NotifierProvider<MarketSandboxDiagnosticsNotifier, MarketSandboxDiagnostics?>(
  MarketSandboxDiagnosticsNotifier.new,
);

class MarketSandboxDiagnosticsNotifier extends Notifier<MarketSandboxDiagnostics?> {
  @override
  MarketSandboxDiagnostics? build() => null;

  void report(MarketSandboxDiagnostics value) => state = value;

  void clear() => state = null;
}
