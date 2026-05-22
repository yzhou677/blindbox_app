/// How strongly shelf-wide interpretation can be stated from taxonomy coverage.
enum ShelfInterpretationConfidence {
  low,
  medium,
  high,
}

extension ShelfInterpretationConfidenceX on ShelfInterpretationConfidence {
  int get rank => index;
}
