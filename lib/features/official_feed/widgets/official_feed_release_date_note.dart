import 'package:blindbox_app/core/theme/collectible_tokens.dart';
import 'package:blindbox_app/features/official_feed/presentation/official_feed_copy.dart';
import 'package:flutter/material.dart';

/// Quiet release-date disclosure below the Official updates header.
class OfficialFeedReleaseDateNote extends StatelessWidget {
  const OfficialFeedReleaseDateNote({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final tokens = CollectibleTokens.of(context);

    return Text(
      OfficialFeedCopy.releaseDateDisclosure,
      style: tokens.supportiveMeta(textTheme, scheme),
    );
  }
}
