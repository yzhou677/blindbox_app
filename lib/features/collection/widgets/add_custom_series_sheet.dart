export 'package:blindbox_app/features/collection/data/custom_series_conventions.dart'
    show CustomFigureDraft;
export 'custom_series_form_sheet.dart'
    show CustomSeriesFormSheet, CustomSeriesFormSubmit;

import 'package:blindbox_app/features/collection/widgets/custom_series_form_sheet.dart';

/// Back-compat alias — prefer [CustomSeriesFormSheet.create].
class AddCustomSeriesSheet extends CustomSeriesFormSheet {
  AddCustomSeriesSheet({super.key, required CustomSeriesFormSubmit onSubmit})
      : super.create(onSubmit: onSubmit);
}
