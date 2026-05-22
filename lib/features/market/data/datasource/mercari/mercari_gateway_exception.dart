/// Gateway fetch failure — caught inside [MercariSandboxMarketSource], not in UI.
class MercariGatewayException implements Exception {
  MercariGatewayException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'MercariGatewayException: $message';
}
