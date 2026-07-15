import 'dart:math' as math;

import 'package:blindbox_app/features/catalog/presentation/catalog_image_display.dart';
import 'package:blindbox_app/features/collection/insights/domain/collector_type_archetype.dart';
import 'package:blindbox_app/features/sharing/domain/share_card_payloads.dart';
import 'package:blindbox_app/shared/widgets/catalog_image_from_key.dart';
import 'package:blindbox_app/shared/widgets/collectible_thumb_image.dart';
import 'package:flutter/material.dart';

const Size kShelfyShareCardLogicalSize = Size(360, 640);

class CollectorTypeShareCard extends StatelessWidget {
  const CollectorTypeShareCard({super.key, required this.payload});

  final CollectorTypeSharePayload payload;

  @override
  Widget build(BuildContext context) {
    return _ShareCardCanvas(
      child: _PhysicalCard(
        motif: _MotifKind.forCollectorType(payload.archetypeId),
        child: Column(
          children: [
            _CardLabel(payload.label),
            const SizedBox(height: 16),
            Expanded(flex: 44, child: _MascotHero(payload: payload)),
            const SizedBox(height: 8),
            _RaisedStatement(
              lines: [payload.statementTop, payload.statementBottom],
              accent: payload.accent,
            ),
            const SizedBox(height: 12),
            _IdentityBand(text: payload.displayName.toUpperCase()),
            const SizedBox(height: 8),
            Text(
              payload.officialExplanation,
              textAlign: TextAlign.center,
              style: _ShareCardType.body(context).copyWith(fontSize: 12.5),
            ),
            const SizedBox(height: 2),
            Text(
              payload.motto,
              textAlign: TextAlign.center,
              style: _ShareCardType.body(context).copyWith(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: _ShareCardColors.ink.withValues(alpha: 0.56),
              ),
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _MetadataRow(payload.metadata)),
                const SizedBox(width: 10),
                const _WaxSeal(icon: Icons.all_inclusive_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MasterCompleteShareCard extends StatelessWidget {
  const MasterCompleteShareCard({super.key, required this.payload});

  final MasterCompleteSharePayload payload;

  @override
  Widget build(BuildContext context) {
    return _ShareCardCanvas(
      child: _PhysicalCard(
        motif: _MotifKind.chase,
        child: Column(
          children: [
            _CardLabel(
              payload.label,
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFFCBAA45),
            ),
            const SizedBox(height: 24),
            Expanded(
              flex: 43,
              child: _ImageHero(
                image: payload.image,
                name: payload.seriesName,
                seedKey: payload.seriesName,
              ),
            ),
            const SizedBox(height: 28),
            _RaisedStatement(
              lines: const ['THE CHASE', 'IS COMPLETE'],
              accent: _ShareCardColors.lilac,
            ),
            const SizedBox(height: 16),
            Text(
              'Every Regular.     Every Secret.',
              textAlign: TextAlign.center,
              style: _ShareCardType.body(context).copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _ShareCardColors.lilac,
              ),
            ),
            const SizedBox(height: 11),
            _IdentityBand(text: payload.seriesName),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _MetadataRow(payload.metadata)),
                const SizedBox(width: 10),
                const _WaxSeal(icon: Icons.emoji_events_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ShelfShareCard extends StatelessWidget {
  const ShelfShareCard({super.key, required this.payload});

  final ShelfSharePayload payload;

  @override
  Widget build(BuildContext context) {
    final items = payload.featuredSeries;
    final hero = items.isNotEmpty ? items.first : null;
    final supporting = items.skip(1).take(5).toList(growable: false);
    final collectorLine = payload.collectorTypeName == null
        ? 'Good finds live here.'
        : 'Good finds live here.';

    return _ShareCardCanvas(
      child: _PhysicalCard(
        motif: _MotifKind.shelf,
        padding: const EdgeInsets.fromLTRB(23, 18, 23, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardLabel('SHELFY SHELF CARD · CURRENT'),
            const SizedBox(height: 8),
            Text(
              'MY SHELF\nRIGHT NOW',
              textAlign: TextAlign.left,
              style: _ShareCardType.statement(context).copyWith(
                fontSize: 39,
                height: 1.02,
                letterSpacing: 1.2,
                color: _ShareCardColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              collectorLine,
              style: _ShareCardType.body(context).copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ShareCardColors.lilac,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: hero == null
                  ? const _EmptyShelfCardArt()
                  : _ShelfPortrait(hero: hero, supporting: supporting),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: _ProgressMetadata(
                    progress: payload.overallRegularProgress,
                    metadata:
                        'OWNED ${payload.ownedFigureCount} · SERIES ${payload.trackedSeriesCount} · MASTER ${payload.masterCompleteSeriesCount}',
                  ),
                ),
                const SizedBox(width: 10),
                const _WaxSeal(icon: Icons.collections_bookmark_rounded),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _ShareCardCanvas extends StatelessWidget {
  const _ShareCardCanvas({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kShelfyShareCardLogicalSize.width,
      height: kShelfyShareCardLogicalSize.height,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEDE6F6), Color(0xFFF7F0FA)],
          ),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _PhysicalCard extends StatelessWidget {
  const _PhysicalCard({
    required this.child,
    required this.motif,
    this.padding = const EdgeInsets.fromLTRB(22, 18, 22, 18),
  });

  final Widget child;
  final _MotifKind motif;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 322,
      height: 586,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 34,
            spreadRadius: -14,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: _ShareCardColors.lilac.withValues(alpha: 0.18),
            blurRadius: 22,
            spreadRadius: -18,
            offset: const Offset(0, 7),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.72),
            blurRadius: 10,
            offset: const Offset(-3, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFFFFFDF8).withValues(alpha: 0.82),
              width: 1.2,
            ),
            borderRadius: BorderRadius.circular(32),
          ),
          child: CustomPaint(
            painter: _CardMaterialPainter(motif: motif),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class _MascotHero extends StatelessWidget {
  const _MascotHero({required this.payload});

  final CollectorTypeSharePayload payload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 226,
        height: 226,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.11),
              blurRadius: 16,
              spreadRadius: -11,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: ClipOval(
          clipBehavior: Clip.antiAlias,
          child: Transform.scale(
            scale: 1.05,
            child: Image.asset(
              payload.mascotAssetPath,
              width: 226,
              height: 226,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageHero extends StatelessWidget {
  const _ImageHero({
    required this.image,
    required this.name,
    required this.seedKey,
  });

  final ShareCardImageRef image;
  final String name;
  final String seedKey;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF7),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 22,
            spreadRadius: -10,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.88),
            blurRadius: 11,
            offset: const Offset(-2, -4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.86),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.16),
                blurRadius: 8,
                spreadRadius: -7,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: _ShareCardImage(
              image: image,
              name: name,
              seedKey: seedKey,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}

class _ShelfPortrait extends StatelessWidget {
  const _ShelfPortrait({required this.hero, required this.supporting});

  final ShelfShareSeriesItem hero;
  final List<ShelfShareSeriesItem> supporting;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 4,
              top: 0,
              width: width - 8,
              height: height * 0.59,
              child: Transform.rotate(
                angle: -0.015,
                child: _Polaroid(
                  image: hero.image,
                  name: hero.seriesName,
                  seedKey: hero.seriesId,
                  hero: true,
                ),
              ),
            ),
            for (var i = 0; i < supporting.length; i++)
              _supportingPhoto(
                context: context,
                item: supporting[i],
                index: i,
                width: width,
                height: height,
              ),
          ],
        );
      },
    );
  }

  Widget _supportingPhoto({
    required BuildContext context,
    required ShelfShareSeriesItem item,
    required int index,
    required double width,
    required double height,
  }) {
    final specs = <({double x, double y, double w, double a})>[
      (x: -2, y: height * 0.46, w: width * 0.31, a: -0.1),
      (x: width * 0.32, y: height * 0.55, w: width * 0.34, a: 0.055),
      (x: width * 0.68, y: height * 0.47, w: width * 0.31, a: 0.09),
      (x: width * 0.08, y: height * 0.70, w: width * 0.31, a: 0.065),
      (x: width * 0.58, y: height * 0.69, w: width * 0.33, a: -0.065),
    ];
    final spec = specs[index % specs.length];
    return Positioned(
      left: spec.x,
      top: spec.y,
      width: spec.w,
      child: Transform.rotate(
        angle: spec.a,
        child: _Polaroid(
          image: item.image,
          name: item.seriesName,
          seedKey: item.seriesId,
        ),
      ),
    );
  }
}

class _Polaroid extends StatelessWidget {
  const _Polaroid({
    required this.image,
    required this.name,
    required this.seedKey,
    this.hero = false,
  });

  final ShareCardImageRef image;
  final String name;
  final String seedKey;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(hero ? 16 : 8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: hero ? 0.2 : 0.16),
            blurRadius: hero ? 24 : 14,
            spreadRadius: hero ? -10 : -7,
            offset: Offset(0, hero ? 16 : 9),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.72),
            blurRadius: hero ? 8 : 5,
            offset: const Offset(-1, -2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: hero ? 0.9 : 0.78),
          width: hero ? 1.1 : 0.7,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          hero ? 7 : 5,
          hero ? 7 : 5,
          hero ? 7 : 5,
          hero ? 12 : 10,
        ),
        child: AspectRatio(
          aspectRatio: hero ? 1.32 : 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(hero ? 12 : 5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 7,
                  spreadRadius: -6,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(hero ? 12 : 5),
              child: _ShareCardImage(
                image: image,
                name: name,
                seedKey: seedKey,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareCardImage extends StatelessWidget {
  const _ShareCardImage({
    required this.image,
    required this.name,
    required this.seedKey,
    required this.fit,
  });

  final ShareCardImageRef image;
  final String name;
  final String seedKey;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return switch (image.kind) {
      ShareCardImageKind.catalogSeries => CatalogImageFromKey(
        imageKey: image.value,
        name: name,
        seedKey: seedKey,
        displayMode: CatalogImageDisplayMode.seriesCoverHero,
        borderRadius: BorderRadius.zero,
      ),
      ShareCardImageKind.asset ||
      ShareCardImageKind.localFile => CollectibleThumbImage(
        imageRef: image.value,
        name: name,
        seedKey: seedKey,
        fit: fit,
        borderRadius: BorderRadius.zero,
      ),
    };
  }
}

class _RaisedStatement extends StatelessWidget {
  const _RaisedStatement({required this.lines, required this.accent});

  final List<String> lines;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = Color.lerp(_ShareCardColors.ink, accent, 0.18)!;
    return Column(
      children: [
        for (final line in lines)
          Text(
            line,
            textAlign: TextAlign.center,
            style: _ShareCardType.statement(context).copyWith(
              color: color,
              shadows: [
                Shadow(
                  color: Colors.white.withValues(alpha: 0.9),
                  blurRadius: 2,
                  offset: const Offset(-0.5, -0.8),
                ),
                Shadow(
                  color: Colors.black.withValues(alpha: 0.11),
                  blurRadius: 2,
                  offset: const Offset(0.7, 1),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel(this.text, {this.icon, this.iconColor});

  final String text;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 264),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.28),
        border: Border.all(
          color: _ShareCardColors.lilac.withValues(alpha: 0.26),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.7),
            blurRadius: 5,
            offset: const Offset(-1, -1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor ?? _ShareCardColors.lilac),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _ShareCardType.label(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityBand extends StatelessWidget {
  const _IdentityBand({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _ShareCardColors.lilac.withValues(alpha: 0.18),
        ),
        color: Colors.white.withValues(alpha: 0.18),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.fade,
        softWrap: true,
        style: _ShareCardType.label(
          context,
        ).copyWith(fontSize: 12.5, height: 1.18, color: _ShareCardColors.sage),
      ),
    );
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: _ShareCardType.label(context).copyWith(
        fontSize: 8.5,
        letterSpacing: 1.45,
        color: _ShareCardColors.ink.withValues(alpha: 0.5),
      ),
    );
  }
}

class _ProgressMetadata extends StatelessWidget {
  const _ProgressMetadata({required this.progress, required this.metadata});

  final int progress;
  final String metadata;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$progress% REGULAR PROGRESS',
          style: _ShareCardType.label(context).copyWith(fontSize: 9.5),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (progress / 100).clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: _ShareCardColors.lilac.withValues(alpha: 0.12),
            color: _ShareCardColors.lilac.withValues(alpha: 0.58),
          ),
        ),
        const SizedBox(height: 8),
        _MetadataRow(metadata),
      ],
    );
  }
}

class _WaxSeal extends StatelessWidget {
  const _WaxSeal({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: CustomPaint(
        painter: const _SealCompressionPainter(),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.32, -0.4),
                colors: [
                  const Color(0xFFE3D5F0).withValues(alpha: 0.96),
                  const Color(0xFFC8B7E3).withValues(alpha: 0.88),
                  const Color(0xFFA995CC).withValues(alpha: 0.78),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: -5,
                  offset: const Offset(0, 9),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.75),
                  blurRadius: 6,
                  offset: const Offset(-1.5, -2.5),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 15,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                  Text(
                    'Shelfy',
                    style: _ShareCardType.body(context).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SealCompressionPainter extends CustomPainter {
  const _SealCompressionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 1);
    final paint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.black.withValues(alpha: 0.11),
              Colors.black.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromCircle(center: center, radius: size.width * 0.56),
          );
    canvas.drawCircle(center, size.width * 0.48, paint);
  }

  @override
  bool shouldRepaint(covariant _SealCompressionPainter oldDelegate) {
    return false;
  }
}

class _EmptyShelfCardArt extends StatelessWidget {
  const _EmptyShelfCardArt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Your shelf is waiting.',
        style: _ShareCardType.body(context),
      ),
    );
  }
}

enum _MotifKind {
  completionist,
  hunter,
  luckyOne,
  dreamer,
  loyalist,
  curator,
  trendChaser,
  worldbuilder,
  minimalist,
  wanderer,
  chase,
  shelf;

  static _MotifKind forCollectorType(CollectorTypeArchetypeId id) {
    return switch (id) {
      CollectorTypeArchetypeId.completionist => _MotifKind.completionist,
      CollectorTypeArchetypeId.hunter => _MotifKind.hunter,
      CollectorTypeArchetypeId.luckyOne => _MotifKind.luckyOne,
      CollectorTypeArchetypeId.dreamer => _MotifKind.dreamer,
      CollectorTypeArchetypeId.loyalist => _MotifKind.loyalist,
      CollectorTypeArchetypeId.curator => _MotifKind.curator,
      CollectorTypeArchetypeId.trendChaser => _MotifKind.trendChaser,
      CollectorTypeArchetypeId.worldbuilder => _MotifKind.worldbuilder,
      CollectorTypeArchetypeId.minimalist => _MotifKind.minimalist,
      CollectorTypeArchetypeId.wanderer => _MotifKind.wanderer,
    };
  }
}

class _CardMaterialPainter extends CustomPainter {
  const _CardMaterialPainter({required this.motif});

  final _MotifKind motif;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(32),
    );
    final base = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFBF3), Color(0xFFF4EDE4)],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(r, base);

    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _ShareCardColors.lilac.withValues(alpha: 0.22);
    final inset = RRect.fromRectAndRadius(
      Rect.fromLTWH(11, 11, size.width - 22, size.height - 22),
      const Radius.circular(25),
    );
    canvas.drawRRect(inset, edge);

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.76);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
        const Radius.circular(29),
      ),
      highlight,
    );

    _paintPaperGrain(canvas, size);
    _paintMotifs(canvas, size);
  }

  void _paintPaperGrain(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 0.45
      ..color = Colors.black.withValues(alpha: 0.018);
    for (var i = 0; i < 70; i++) {
      final x = (i * 47 % size.width).toDouble();
      final y = (i * 83 % size.height).toDouble();
      canvas.drawLine(Offset(x, y), Offset(x + 10, y + 0.8), paint);
    }
  }

  void _paintMotifs(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round
      ..color = _ShareCardColors.ink.withValues(alpha: 0.055);
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..color = _ShareCardColors.ink.withValues(alpha: 0.04);

    switch (motif) {
      case _MotifKind.completionist:
        _drawCheck(canvas, const Offset(38, 72), paint);
        _drawCheck(canvas, Offset(size.width - 44, 94), paint);
        _drawInfinity(canvas, Offset(44, size.height - 116), paint);
        _drawSeal(canvas, Offset(size.width - 56, 74), paint);
        break;
      case _MotifKind.hunter:
        _drawTarget(canvas, const Offset(44, 88), paint);
        _drawPath(canvas, size, paint);
        break;
      case _MotifKind.luckyOne:
        _drawStar(canvas, const Offset(42, 94), paint);
        _drawStar(canvas, Offset(size.width - 56, 122), paint);
        break;
      case _MotifKind.dreamer:
        _drawMoon(canvas, const Offset(48, 92), paint);
        _drawCloud(canvas, Offset(size.width - 72, 118), paint);
        break;
      case _MotifKind.loyalist:
        _drawOrbit(canvas, Offset(size.width - 72, 106), paint);
        break;
      case _MotifKind.curator:
        _drawFrame(canvas, const Rect.fromLTWH(34, 82, 36, 46), paint);
        _drawFrame(canvas, Rect.fromLTWH(size.width - 72, 108, 34, 42), paint);
        break;
      case _MotifKind.trendChaser:
        _drawCalendar(canvas, const Rect.fromLTWH(34, 86, 42, 36), paint);
        break;
      case _MotifKind.worldbuilder:
        _drawGrid(canvas, const Rect.fromLTWH(32, 82, 58, 48), paint);
        break;
      case _MotifKind.minimalist:
        canvas.drawLine(
          const Offset(34, 96),
          Offset(size.width - 34, 96),
          paint,
        );
        break;
      case _MotifKind.wanderer:
        _drawPath(canvas, size, paint);
        _drawCompass(canvas, Offset(size.width - 60, 96), paint);
        break;
      case _MotifKind.chase:
        _drawPath(canvas, size, paint);
        _drawStar(canvas, Offset(size.width - 42, 124), paint);
        canvas.drawCircle(const Offset(44, 112), 4, fill);
        canvas.drawCircle(const Offset(58, 112), 4, paint);
        break;
      case _MotifKind.shelf:
        _drawShelf(canvas, Offset(size.width - 78, 112), paint);
        _drawPath(canvas, size, paint);
        _drawFrame(canvas, const Rect.fromLTWH(35, 80, 34, 42), paint);
        break;
    }
  }

  void _drawCheck(Canvas canvas, Offset o, Paint p) {
    final path = Path()
      ..moveTo(o.dx - 8, o.dy)
      ..lineTo(o.dx - 2, o.dy + 7)
      ..lineTo(o.dx + 10, o.dy - 9);
    canvas.drawPath(path, p);
  }

  void _drawInfinity(Canvas canvas, Offset o, Paint p) {
    final path = Path();
    for (var i = 0; i <= 64; i++) {
      final t = i / 64 * math.pi * 2;
      final x = o.dx + math.sin(t) * 14;
      final y = o.dy + math.sin(t * 2) * 6;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, p);
  }

  void _drawSeal(Canvas canvas, Offset o, Paint p) {
    canvas.drawCircle(o, 13, p);
    canvas.drawCircle(o, 8, p);
  }

  void _drawTarget(Canvas canvas, Offset o, Paint p) {
    canvas.drawCircle(o, 14, p);
    canvas.drawCircle(o, 7, p);
    canvas.drawCircle(o, 2, p);
  }

  void _drawPath(Canvas canvas, Size size, Paint p) {
    final path = Path()
      ..moveTo(28, size.height * 0.72)
      ..cubicTo(
        82,
        size.height * 0.66,
        120,
        size.height * 0.83,
        180,
        size.height * 0.76,
      )
      ..cubicTo(
        238,
        size.height * 0.7,
        258,
        size.height * 0.88,
        size.width - 34,
        size.height * 0.82,
      );
    canvas.drawPath(path, p..strokeWidth = 1);
  }

  void _drawStar(Canvas canvas, Offset o, Paint p) {
    canvas.drawLine(Offset(o.dx - 8, o.dy), Offset(o.dx + 8, o.dy), p);
    canvas.drawLine(Offset(o.dx, o.dy - 8), Offset(o.dx, o.dy + 8), p);
  }

  void _drawMoon(Canvas canvas, Offset o, Paint p) {
    canvas.drawArc(Rect.fromCircle(center: o, radius: 13), -1.1, 4.2, false, p);
  }

  void _drawCloud(Canvas canvas, Offset o, Paint p) {
    canvas.drawArc(
      Rect.fromLTWH(o.dx, o.dy, 18, 16),
      math.pi,
      math.pi,
      false,
      p,
    );
    canvas.drawArc(
      Rect.fromLTWH(o.dx + 12, o.dy - 5, 22, 22),
      math.pi,
      math.pi,
      false,
      p,
    );
    canvas.drawLine(Offset(o.dx, o.dy + 8), Offset(o.dx + 38, o.dy + 8), p);
  }

  void _drawOrbit(Canvas canvas, Offset o, Paint p) {
    canvas.drawOval(Rect.fromCenter(center: o, width: 52, height: 22), p);
    canvas.drawCircle(o, 5, p);
  }

  void _drawFrame(Canvas canvas, Rect rect, Paint p) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      p,
    );
  }

  void _drawCalendar(Canvas canvas, Rect rect, Paint p) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      p,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top + 11),
      Offset(rect.right, rect.top + 11),
      p,
    );
  }

  void _drawGrid(Canvas canvas, Rect rect, Paint p) {
    for (var i = 0; i < 4; i++) {
      final x = rect.left + rect.width / 3 * i;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), p);
    }
    for (var i = 0; i < 4; i++) {
      final y = rect.top + rect.height / 3 * i;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), p);
    }
  }

  void _drawCompass(Canvas canvas, Offset o, Paint p) {
    canvas.drawCircle(o, 14, p);
    canvas.drawLine(Offset(o.dx, o.dy - 9), Offset(o.dx + 6, o.dy + 7), p);
  }

  void _drawShelf(Canvas canvas, Offset o, Paint p) {
    canvas.drawLine(Offset(o.dx, o.dy + 30), Offset(o.dx + 54, o.dy + 30), p);
    canvas.drawLine(Offset(o.dx + 8, o.dy), Offset(o.dx + 8, o.dy + 30), p);
    canvas.drawLine(
      Offset(o.dx + 24, o.dy + 9),
      Offset(o.dx + 24, o.dy + 30),
      p,
    );
    canvas.drawLine(
      Offset(o.dx + 40, o.dy + 4),
      Offset(o.dx + 40, o.dy + 30),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant _CardMaterialPainter oldDelegate) {
    return oldDelegate.motif != motif;
  }
}

abstract final class _ShareCardColors {
  static const ink = Color(0xFF3E3948);
  static const lilac = Color(0xFFA995CC);
  static const sage = Color(0xFF71886E);
}

abstract final class _ShareCardType {
  static TextStyle statement(BuildContext context) {
    return Theme.of(context).textTheme.headlineMedium!.copyWith(
      fontWeight: FontWeight.w900,
      fontSize: 34,
      height: 1.02,
      letterSpacing: 1.1,
      color: _ShareCardColors.ink,
    );
  }

  static TextStyle body(BuildContext context) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: _ShareCardColors.ink.withValues(alpha: 0.68),
      height: 1.28,
      letterSpacing: 0.02,
    );
  }

  static TextStyle label(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall!.copyWith(
      color: _ShareCardColors.lilac.withValues(alpha: 0.9),
      fontWeight: FontWeight.w800,
      letterSpacing: 2.0,
      height: 1.1,
    );
  }
}
