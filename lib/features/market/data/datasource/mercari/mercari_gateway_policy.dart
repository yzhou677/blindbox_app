import 'package:blindbox_app/features/market/data/datasource/mercari/mercari_gateway_exception.dart';
import 'package:blindbox_app/features/market/data/sandbox/market_sandbox_config.dart';

/// Retry with calm exponential backoff for gateway reads.
Future<T> mercariGatewayWithRetries<T>(
  Future<T> Function() action, {
  int maxAttempts = MarketSandboxConfig.gatewayMaxAttempts,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await action();
    } on MercariGatewayException catch (e) {
      lastError = e;
      if (!_isRetriable(e) || attempt >= maxAttempts - 1) rethrow;
    } catch (e) {
      lastError = e;
      if (attempt >= maxAttempts - 1) rethrow;
    }
    final delay = MarketSandboxConfig.retryDelayForAttempt(attempt);
    await Future<void>.delayed(delay);
  }
  throw lastError ?? MercariGatewayException('Gateway request failed');
}

bool _isRetriable(MercariGatewayException e) {
  final code = e.statusCode;
  if (code == null) return true;
  return code == 408 || code == 429 || code >= 500;
}
