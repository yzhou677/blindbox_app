abstract final class CompletionMetricTooltips {
  CompletionMetricTooltips._();

  static const completedSeries =
      'Series with all Regular figures collected. Includes Master Complete series.';

  static const masterComplete =
      'Series where every Regular and Secret figure has been collected.';

  static const regularProgress =
      'Average progress toward Regular Complete across all tracked series. Secret figures do not affect this progress.';

  static const masterCompletion =
      'Percentage of series with Secret figures that reached Master Complete. Series without Secrets are excluded.';

  static const secretsCollected = 'Secret figures marked as owned.';
}
