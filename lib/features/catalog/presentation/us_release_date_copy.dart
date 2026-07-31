import 'package:flutter/material.dart';

/// Copy and formatting for catalog **U.S.** release dates.
///
/// Source field: catalog JSON / Firestore `releaseDate` (ISO date-only string).
abstract final class UsReleaseDateCopy {
  UsReleaseDateCopy._();

  static const label = 'U.S. Release Date';

  static const infoSemanticLabel = 'About U.S. release date';

  static const disclosure =
      'Based on the official U.S. website. Dates may vary by region.';
}

/// Full English month names — always includes calendar year (unlike some
/// [MaterialLocalizations.formatMediumDate] builds that drop it).
const _usReleaseMonths = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Date value for the U.S. release row (e.g. `May 23, 2025`).
///
/// [localizations] is accepted for call-site consistency with other formatters;
/// the calendar string is year-stable English matching in-app collectible dates.
String? formatUsReleaseDateValue(
  DateTime? date,
  MaterialLocalizations localizations,
) {
  if (date == null) return null;
  final year = date.year;
  final month = date.month;
  final day = date.day;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  // Reject obviously corrupt calendar fields without throwing.
  if (year < 1990 || year > 2100) return null;
  return '${_usReleaseMonths[month - 1]} $day, $year';
}

/// Compact header line: `U.S. Release Date · May 23, 2025`.
///
/// Returns null when the date is missing or cannot be formatted.
String? formatUsReleaseDateLine(
  DateTime? date,
  MaterialLocalizations localizations,
) {
  final value = formatUsReleaseDateValue(date, localizations);
  if (value == null || value.trim().isEmpty) return null;
  return '${UsReleaseDateCopy.label} · $value';
}
