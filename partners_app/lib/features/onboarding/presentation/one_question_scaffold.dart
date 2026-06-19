import 'package:flutter/material.dart';

/// Base scaffold for every wizard page. Apple-style — one decision per screen, generous whitespace,
/// sticky 56pt CTA at the bottom, progress dots at top.
///
/// Pages don't render their own AppBar — this scaffold owns the chrome.
class OneQuestionScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final bool nextEnabled;
  final String? nextLabel;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;
  final String? skipLabel;
  final int currentStep;
  final int totalSteps;

  const OneQuestionScaffold({
    super.key,
    required this.title,
    required this.child,
    required this.nextEnabled,
    required this.onNext,
    required this.currentStep,
    required this.totalSteps,
    this.subtitle,
    this.nextLabel,
    this.onBack,
    this.onSkip,
    this.skipLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: onBack == null ? null
            : IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                          onPressed: onBack),
        title: _ProgressDots(current: currentStep, total: totalSteps, color: cs.primary),
        centerTitle: true,
      ),
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w800,
              letterSpacing: -0.5, height: 1.1)),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(subtitle!, style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant))),
          const SizedBox(height: 28),
          Expanded(child: child),
          if (onSkip != null) Padding(padding: const EdgeInsets.only(bottom: 4),
              child: Center(child: TextButton(onPressed: onSkip,
                child: Text(skipLabel ?? 'Skip', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))))),
          FilledButton(onPressed: nextEnabled ? onNext : null,
              child: Text(nextLabel ?? 'Next')),
        ]))));
  }
}


class _ProgressDots extends StatelessWidget {
  final int current;
  final int total;
  final Color color;
  const _ProgressDots({required this.current, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final inactive = color.withValues(alpha: 0.25);
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(total, (i) {
      final isCurrent = i == current;
      final isPast = i < current;
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: isCurrent ? 22 : 6, height: 6,
        decoration: BoxDecoration(
          color: (isPast || isCurrent) ? color : inactive,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }));
  }
}
