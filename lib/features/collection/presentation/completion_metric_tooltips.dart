abstract final class CompletionMetricTooltips {
  CompletionMetricTooltips._();

  static const completedSeries =
      'Series where every Regular figure has been collected. Master Complete series are included.';

  static const masterComplete =
      'Series where every Regular and Secret figure has been collected.';

  static const regularProgress =
      'Average progress toward Complete across all tracked series. Secrets do not reduce Regular progress.';

  static const masterCompletion =
      'Percentage of series with Secret figures that have reached Master Complete. Series without Secrets are not included.';

  static const secretsCollected = 'Secret figures marked as owned.';
}
