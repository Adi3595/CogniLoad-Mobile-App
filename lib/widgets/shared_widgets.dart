import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final double? borderWidth;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CogniloadTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? CogniloadTheme.surfaceHighlight,
          width: borderWidth ?? 1,
        ),
      ),
      child: child,
    );
  }
}

class ScoreBadge extends StatelessWidget {
  final double score;
  final double size;

  const ScoreBadge({super.key, required this.score, this.size = 120});

  @override
  Widget build(BuildContext context) {
    final color = CogniloadTheme.scoreColor(score);
    final label = CogniloadTheme.scoreLabel(score);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 8,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.toStringAsFixed(0),
                style: TextStyle(
                  color: color,
                  fontSize: size * 0.28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: CogniloadTheme.textSecondary,
                  fontSize: size * 0.095,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FactorBar extends StatelessWidget {
  final String label;
  final double score;
  final IconData icon;
  final int delay;

  const FactorBar({
    super.key,
    required this.label,
    required this.score,
    required this.icon,
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    final color = CogniloadTheme.scoreColor(score);

    return Animate(
      delay: Duration(milliseconds: delay),
      effects: const [FadeEffect(), SlideEffect(begin: Offset(0.1, 0))],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label,
                          style: const TextStyle(
                              color: CogniloadTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                      Text(
                        '${score.toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: score / 100,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppIconWidget extends StatelessWidget {
  final Uint8List? iconBytes;
  final String appName;
  final double size;

  const AppIconWidget({
    super.key,
    required this.iconBytes,
    required this.appName,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    if (iconBytes != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.memory(
          iconBytes!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    final initial = appName.isNotEmpty ? appName[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: CogniloadTheme.surfaceHighlight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: CogniloadTheme.primary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

class RecommendationCard extends StatelessWidget {
  final String recommendation;
  final int index;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      CogniloadTheme.primary,
      CogniloadTheme.secondary,
      CogniloadTheme.accent,
      CogniloadTheme.accentGreen,
      CogniloadTheme.accentRed,
    ];
    final color = colors[index % colors.length];

    return Animate(
      delay: Duration(milliseconds: index * 100),
      effects: const [FadeEffect(), SlideEffect(begin: Offset(0, 0.2))],
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: CogniloadTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                recommendation,
                style: const TextStyle(
                  color: CogniloadTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: CogniloadTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )),
                if (subtitle != null)
                  Text(subtitle!,
                      style: const TextStyle(
                          color: CogniloadTheme.textMuted, fontSize: 12)),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: CogniloadTheme.textMuted),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    color: CogniloadTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: CogniloadTheme.textMuted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
