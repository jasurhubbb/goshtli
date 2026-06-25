import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/auth/partner_auth_notifier.dart';
import '../../../core/network/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/image_source_picker.dart';
import '../providers/onboarding_draft_provider.dart';
import 'one_question_scaffold.dart';


/// 8-page Qassob wizard.
///
/// Pages:
///   0 Welcome
///   1 Years of experience  (CupertinoPicker 0-50)
///   2 Full name           (TextField)
///   3 Animals supported   (multi-select chips)
///   4 Daily capacity      (slider 1-50)
///   5 Has slaughterhouse  (Ha/Yo'q toggle)
///   6 Location            (GPS autodetect + manual)
///   7 Photo + submit      (image_picker; skip OK)
class QassobWizardScreen extends ConsumerStatefulWidget {
  final String phone;
  const QassobWizardScreen({super.key, required this.phone});
  @override
  ConsumerState<QassobWizardScreen> createState() => _QassobWizardScreenState();
}


class _QassobWizardScreenState extends ConsumerState<QassobWizardScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _submitting = false;
  String? _submitError;

  @override
  void dispose() { _pageCtrl.dispose(); super.dispose(); }

  void _go(int delta) {
    final next = (_step + delta).clamp(0, 7);
    setState(() => _step = next);
    _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _submitError = null; });
    final t = AppLocalizations.of(context);
    final draft = ref.read(onboardingDraftProvider);
    final router = GoRouter.of(context);
    try {
      // Backend creates BUYER by default; partner-app wizard overrides role to QASSOB on phone-register.
      final user = await ref.read(firebaseBridgeProvider).phoneRegister(
        phone: widget.phone, fullName: draft.fullName,
        businessName: '', roleOverride: 'QASSOB');
      // Now POST /qassobs/me/ with the wizard payload.
      final api = ref.read(apiClientProvider);
      final r = await api.dio.post('/qassobs/me/', data: draft.toQassobPayload());
      if (r.statusCode == 201 || r.statusCode == 200) {
        ref.read(partnerAuthProvider.notifier).setAuthenticated(user);
        await ref.read(onboardingDraftProvider.notifier).clear();
        if (mounted) router.go('/home');
      } else {
        if (mounted) setState(() { _submitError = t.onboardingSubmitFailed; _submitting = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _submitError = t.onboardingSubmitFailed; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageCtrl,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _WelcomePage(step: _step, onNext: () => _go(1)),
        _YearsPage(step: _step, onBack: () => _go(-1), onNext: () => _go(1)),
        _FullNamePage(step: _step, onBack: () => _go(-1), onNext: () => _go(1)),
        _AnimalsPage(step: _step, onBack: () => _go(-1), onNext: () => _go(1)),
        _CapacityPage(step: _step, onBack: () => _go(-1), onNext: () => _go(1)),
        _SlaughterhousePage(step: _step, onBack: () => _go(-1), onNext: () => _go(1)),
        _LocationPage(step: _step, onBack: () => _go(-1), onNext: () => _go(1)),
        _PhotoSubmitPage(step: _step, onBack: () => _go(-1), onSubmit: _submit,
                          submitting: _submitting, error: _submitError),
      ],
    );
  }
}


// ============================================================================
// PAGE 0 — Welcome
// ============================================================================

class _WelcomePage extends StatelessWidget {
  final int step;
  final VoidCallback onNext;
  const _WelcomePage({required this.step, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return OneQuestionScaffold(
      title: t.onboardingWelcomeQassob,
      currentStep: step, totalSteps: 8,
      nextEnabled: true,
      onNext: onNext,
      child: Center(child: Container(width: 144, height: 144,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: cs.primary.withValues(alpha: 0.12)),
        child: Icon(Icons.cut_rounded, size: 64, color: cs.primary))),
    );
  }
}


// ============================================================================
// PAGE 1 — Years of experience
// ============================================================================

class _YearsPage extends ConsumerStatefulWidget {
  final int step;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _YearsPage({required this.step, required this.onBack, required this.onNext});
  @override
  ConsumerState<_YearsPage> createState() => _YearsPageState();
}


class _YearsPageState extends ConsumerState<_YearsPage> {
  late int _years;
  @override
  void initState() {
    super.initState();
    _years = ref.read(onboardingDraftProvider).yearsExperience;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    return OneQuestionScaffold(
      title: t.onboardingExperience,
      currentStep: widget.step, totalSteps: 8,
      onBack: widget.onBack,
      nextEnabled: true,
      onNext: () {
        ref.read(onboardingDraftProvider.notifier).update((d) => d.copyWith(yearsExperience: _years));
        widget.onNext();
      },
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(height: 200, child: CupertinoPicker(
          itemExtent: 48,
          scrollController: FixedExtentScrollController(initialItem: _years),
          onSelectedItemChanged: (v) => setState(() => _years = v),
          children: List.generate(51, (i) => Center(
              child: Text('$i', style: tt.displaySmall?.copyWith(fontWeight: FontWeight.w700)))),
        )),
      ]),
    );
  }
}


// ============================================================================
// PAGE 2 — Full name
// ============================================================================

class _FullNamePage extends ConsumerStatefulWidget {
  final int step;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _FullNamePage({required this.step, required this.onBack, required this.onNext});
  @override
  ConsumerState<_FullNamePage> createState() => _FullNamePageState();
}


class _FullNamePageState extends ConsumerState<_FullNamePage> {
  late final TextEditingController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(onboardingDraftProvider).fullName);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  bool get _valid => _ctrl.text.trim().split(RegExp(r'\s+')).length >= 2;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return OneQuestionScaffold(
      title: t.onboardingYourName,
      currentStep: widget.step, totalSteps: 8,
      onBack: widget.onBack,
      nextEnabled: _valid,
      onNext: () {
        ref.read(onboardingDraftProvider.notifier).update((d) => d.copyWith(fullName: _ctrl.text.trim()));
        widget.onNext();
      },
      child: Column(children: [
        TextField(
          controller: _ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: Theme.of(context).textTheme.headlineSmall,
          decoration: InputDecoration(hintText: t.onboardingFullName),
          onChanged: (_) => setState(() {}),
        ),
      ]),
    );
  }
}


// ============================================================================
// PAGE 3 — Animals supported
// ============================================================================

class _AnimalsPage extends ConsumerStatefulWidget {
  final int step;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _AnimalsPage({required this.step, required this.onBack, required this.onNext});
  @override
  ConsumerState<_AnimalsPage> createState() => _AnimalsPageState();
}


class _AnimalsPageState extends ConsumerState<_AnimalsPage> {
  late Set<String> _selected;
  @override
  void initState() {
    super.initState();
    _selected = ref.read(onboardingDraftProvider).animalsSupported.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final animals = [
      ('MOL', t.animalMol), ('QOY', t.animalQoy),
      ('ECHKI', t.animalEchki), ('OT', t.animalOt),
    ];
    return OneQuestionScaffold(
      title: t.onboardingAnimalsTitleQassob,
      subtitle: t.onboardingAnimalsHint,
      currentStep: widget.step, totalSteps: 8,
      onBack: widget.onBack,
      nextEnabled: _selected.isNotEmpty,
      onNext: () {
        ref.read(onboardingDraftProvider.notifier).update((d) =>
            d.copyWith(animalsSupported: _selected.toList()));
        widget.onNext();
      },
      child: Wrap(spacing: 12, runSpacing: 12, children: animals.map((a) {
        final on = _selected.contains(a.$1);
        return GestureDetector(
          onTap: () => setState(() {
            if (on) { _selected.remove(a.$1); } else { _selected.add(a.$1); }
          }),
          child: Container(padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              color: on ? cs.primary : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: on ? cs.primary : cs.outlineVariant, width: 1.4),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (on) Padding(padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_rounded, size: 18, color: cs.onPrimary)),
              Text(a.$2, style: TextStyle(
                fontWeight: FontWeight.w700,
                color: on ? cs.onPrimary : cs.onSurface)),
            ])),
        );
      }).toList()),
    );
  }
}


// ============================================================================
// PAGE 4 — Daily capacity
// ============================================================================

class _CapacityPage extends ConsumerStatefulWidget {
  final int step;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _CapacityPage({required this.step, required this.onBack, required this.onNext});
  @override
  ConsumerState<_CapacityPage> createState() => _CapacityPageState();
}


class _CapacityPageState extends ConsumerState<_CapacityPage> {
  late double _value;
  @override
  void initState() {
    super.initState();
    _value = ref.read(onboardingDraftProvider).dailyCapacityHead.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return OneQuestionScaffold(
      title: t.onboardingCapacity,
      currentStep: widget.step, totalSteps: 8,
      onBack: widget.onBack,
      nextEnabled: true,
      onNext: () {
        ref.read(onboardingDraftProvider.notifier).update((d) =>
            d.copyWith(dailyCapacityHead: _value.round()));
        widget.onNext();
      },
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('${_value.round()}', style: tt.displayLarge?.copyWith(
            fontSize: 96, fontWeight: FontWeight.w900, color: cs.primary)),
        const SizedBox(height: 8),
        Text('bosh / kun', style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 36),
        Slider(min: 1, max: 50, divisions: 49, value: _value,
            onChanged: (v) => setState(() => _value = v)),
      ]),
    );
  }
}


// ============================================================================
// PAGE 5 — Has slaughterhouse?
// ============================================================================

class _SlaughterhousePage extends ConsumerStatefulWidget {
  final int step;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _SlaughterhousePage({required this.step, required this.onBack, required this.onNext});
  @override
  ConsumerState<_SlaughterhousePage> createState() => _SlaughterhousePageState();
}


class _SlaughterhousePageState extends ConsumerState<_SlaughterhousePage> {
  late bool? _value;
  @override
  void initState() {
    super.initState();
    final d = ref.read(onboardingDraftProvider);
    _value = d.isSlaughterhouse ? true : null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return OneQuestionScaffold(
      title: t.onboardingSlaughterhouse,
      currentStep: widget.step, totalSteps: 8,
      onBack: widget.onBack,
      nextEnabled: _value != null,
      onNext: () {
        ref.read(onboardingDraftProvider.notifier).update((d) =>
            d.copyWith(isSlaughterhouse: _value!));
        widget.onNext();
      },
      child: Row(children: [
        Expanded(child: _YesNoCard(label: t.yes, selected: _value == true,
            onTap: () => setState(() => _value = true))),
        const SizedBox(width: 14),
        Expanded(child: _YesNoCard(label: t.no, selected: _value == false,
            onTap: () => setState(() => _value = false))),
      ]),
    );
  }
}


class _YesNoCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _YesNoCard({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(color: selected ? cs.primary : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20),
        child: Container(height: 150,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: 1.4)),
          alignment: Alignment.center,
          child: Text(label, style: tt.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: selected ? cs.onPrimary : cs.onSurface)))));
  }
}


// ============================================================================
// PAGE 6 — Location
// ============================================================================

class _LocationPage extends ConsumerStatefulWidget {
  final int step;
  final VoidCallback onBack;
  final VoidCallback onNext;
  const _LocationPage({required this.step, required this.onBack, required this.onNext});
  @override
  ConsumerState<_LocationPage> createState() => _LocationPageState();
}


class _LocationPageState extends ConsumerState<_LocationPage> {
  double? _lat;
  double? _lng;
  String _region = '';
  bool _locating = false;
  String? _error;
  final _addressCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final d = ref.read(onboardingDraftProvider);
    _lat = d.lat; _lng = d.lng;
    _region = d.region;
    _addressCtrl.text = d.address;
  }

  @override
  void dispose() { _addressCtrl.dispose(); super.dispose(); }

  Future<void> _detect() async {
    setState(() { _locating = true; _error = null; });
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        // Service off — fall back to Tashkent center so the user can still proceed.
        setState(() { _lat = 41.3111; _lng = 69.2797; _region = 'Tashkent';
                       _locating = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10)));
      setState(() {
        _lat = pos.latitude; _lng = pos.longitude;
        _region = 'Tashkent';                               // reverse-geocode wiring lives in shared_core later
        _locating = false;
      });
    } catch (e) {
      // Fallback: Tashkent center so the wizard always completes.
      setState(() { _lat = 41.3111; _lng = 69.2797; _region = 'Tashkent';
                     _locating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final ok = _lat != null && _lng != null;
    return OneQuestionScaffold(
      title: t.onboardingLocation,
      currentStep: widget.step, totalSteps: 8,
      onBack: widget.onBack,
      nextEnabled: ok,
      onNext: () {
        ref.read(onboardingDraftProvider.notifier).update((d) => d.copyWith(
            lat: _lat, lng: _lng, region: _region,
            address: _addressCtrl.text.trim()));
        widget.onNext();
      },
      child: Column(children: [
        Container(height: 160,
          decoration: BoxDecoration(color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20)),
          alignment: Alignment.center,
          child: _locating
              ? const CircularProgressIndicator()
              : ok
                  ? Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.location_on_rounded, size: 48, color: cs.primary),
                      const SizedBox(height: 8),
                      Text('$_region', style: tt.titleMedium),
                      Text('${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    ])
                  : Icon(Icons.map_outlined, size: 48, color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _locating ? null : _detect,
          icon: const Icon(Icons.my_location_rounded),
          label: Text(t.onboardingLocationDetect),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _addressCtrl,
          decoration: InputDecoration(hintText: t.onboardingFullName,
              labelText: 'Address (street, neighborhood)'),
          maxLines: 2,
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: TextStyle(color: cs.error))),
      ]),
    );
  }
}


// ============================================================================
// PAGE 7 — Photo + submit
// ============================================================================

class _PhotoSubmitPage extends ConsumerStatefulWidget {
  final int step;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final bool submitting;
  final String? error;
  const _PhotoSubmitPage({required this.step, required this.onBack, required this.onSubmit,
                           required this.submitting, this.error});
  @override
  ConsumerState<_PhotoSubmitPage> createState() => _PhotoSubmitPageState();
}


class _PhotoSubmitPageState extends ConsumerState<_PhotoSubmitPage> {
  String? _path;
  @override
  void initState() {
    super.initState();
    _path = ref.read(onboardingDraftProvider).photoPath;
  }

  Future<void> _pick() async {
    // showImageSourcePicker gives the user camera-vs-gallery choice, with BoxFit.cover handled by
    // the preview below. Replaces the hard-coded camera-only path that was a dead-end for users
    // without a working camera or who already had a good photo in gallery.
    final picked = await showImageSourcePicker(context);
    if (picked != null) {
      setState(() => _path = picked);
      ref.read(onboardingDraftProvider.notifier).update((d) => d.copyWith(photoPath: picked));
    }
  }

  void _openFullscreen() {
    if (_path == null) return;
    Navigator.of(context).push(MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImageViewer(path: _path!)));
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return OneQuestionScaffold(
      title: t.onboardingPhoto,
      currentStep: widget.step, totalSteps: 8,
      onBack: widget.onBack,
      nextEnabled: !widget.submitting,
      nextLabel: widget.submitting ? t.onboardingSubmitting : t.onboardingSubmit,
      onNext: widget.onSubmit,
      onSkip: widget.submitting ? null : widget.onSubmit,
      skipLabel: t.skip,
      child: Column(children: [
        // Tap the empty area → pick. Tap the filled image → fullscreen preview. The "Boshqa rasm
        // tanlash" button below the picked image is the explicit re-pick affordance.
        GestureDetector(onTap: _path == null ? _pick : _openFullscreen,
          child: Container(height: 220,
            decoration: BoxDecoration(color: cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cs.outlineVariant)),
            alignment: Alignment.center,
            child: _path != null
                ? ClipRRect(borderRadius: BorderRadius.circular(20),
                    child: Image.file(File(_path!),
                        fit: BoxFit.cover, width: double.infinity, height: 220))
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add_a_photo_outlined, size: 48, color: cs.onSurfaceVariant),
                    const SizedBox(height: 8),
                    Text(t.onboardingTakePhoto, style: TextStyle(color: cs.onSurfaceVariant)),
                  ]))),
        if (_path != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: OutlinedButton.icon(onPressed: _pick,
                icon: const Icon(Icons.image_outlined),
                label: const Text("Boshqa rasm tanlash"))),
        if (widget.error != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(widget.error!, style: TextStyle(color: cs.error))),
      ]),
    );
  }
}


/// Simple fullscreen viewer with pinch-to-zoom + close-on-tap. Used by every "tap picked photo to
/// preview" affordance in the partner app (wizard pages, Servisim gallery, listing form).
class _FullscreenImageViewer extends StatelessWidget {
  final String path;
  const _FullscreenImageViewer({required this.path});
  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent,
          foregroundColor: Colors.white, elevation: 0),
      body: GestureDetector(onTap: () => Navigator.pop(context),
        child: Center(child: InteractiveViewer(minScale: 0.5, maxScale: 4,
            child: Image.file(File(path), fit: BoxFit.contain)))));
  }
}


