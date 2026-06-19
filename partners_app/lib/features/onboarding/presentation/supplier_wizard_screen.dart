import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/partner_auth_notifier.dart';
import '../../../core/network/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/onboarding_draft_provider.dart';
import 'one_question_scaffold.dart';


/// 7-page Supplier wizard.
///
///   0 Welcome
///   1 Identity (full_name + company)
///   2 Animals supported (multi-select)
///   3 Per-animal forms (Tirik / Tayyor)
///   4 Location
///   5 Self-delivery + vehicle
///   6 Photo + submit
class SupplierWizardScreen extends ConsumerStatefulWidget {
  final String phone;
  const SupplierWizardScreen({super.key, required this.phone});
  @override
  ConsumerState<SupplierWizardScreen> createState() => _SupplierWizardScreenState();
}


class _SupplierWizardScreenState extends ConsumerState<SupplierWizardScreen> {
  final _pageCtrl = PageController();
  int _step = 0;
  bool _submitting = false;
  String? _error;

  void _go(int delta) {
    final next = (_step + delta).clamp(0, 6);
    setState(() => _step = next);
    _pageCtrl.animateToPage(next, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
  }

  Future<void> _submit() async {
    setState(() { _submitting = true; _error = null; });
    final t = AppLocalizations.of(context);
    final draft = ref.read(onboardingDraftProvider);
    final router = GoRouter.of(context);
    try {
      final user = await ref.read(firebaseBridgeProvider).phoneRegister(
        phone: widget.phone, fullName: draft.fullName,
        businessName: draft.companyName, roleOverride: 'SUPPLIER');
      final api = ref.read(apiClientProvider);
      // First POST creates SupplierProfile if missing; subsequent edits are PATCH.
      final post = await api.dio.post('/suppliers/me/', data: draft.toSupplierPayload());
      if (post.statusCode != 200 && post.statusCode != 201) {
        await api.dio.patch('/suppliers/me/', data: draft.toSupplierPayload());
      }
      ref.read(partnerAuthProvider.notifier).setAuthenticated(user);
      await ref.read(onboardingDraftProvider.notifier).clear();
      if (mounted) router.go('/home');
    } catch (e) {
      if (mounted) setState(() { _error = t.onboardingSubmitFailed; _submitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _pageCtrl,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _WelcomePage(step: _step, onNext: () => _go(1)),
        _IdentityPage(step: _step, onBack: () => _go(-1), onNext: () => _go(1)),
        _AnimalsPage(step: _step, onBack: () => _go(-1), onNext: () => _go(1)),
        _FormsPage(step: _step, onBack: () => _go(-1), onNext: () => _go(1)),
        _LocationPage(step: _step, onBack: () => _go(-1), onNext: () => _go(1)),
        _SelfDeliveryPage(step: _step, onBack: () => _go(-1), onNext: () => _go(1)),
        _PhotoPage(step: _step, onBack: () => _go(-1), onSubmit: _submit,
                    submitting: _submitting, error: _error),
      ],
    );
  }
}


// ---- Page 0 ----

class _WelcomePage extends StatelessWidget {
  final int step; final VoidCallback onNext;
  const _WelcomePage({required this.step, required this.onNext});
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return OneQuestionScaffold(
      title: t.onboardingWelcomeSupplier,
      currentStep: step, totalSteps: 7,
      nextEnabled: true, onNext: onNext,
      child: Center(child: Container(width: 144, height: 144,
        decoration: BoxDecoration(shape: BoxShape.circle,
            color: const Color(0xFF1B5E20).withValues(alpha: 0.12)),
        child: const Icon(Icons.store_rounded, size: 64, color: Color(0xFF1B5E20)))),
    );
  }
}


// ---- Page 1 — Identity (full_name + company on one page) ----

class _IdentityPage extends ConsumerStatefulWidget {
  final int step; final VoidCallback onBack; final VoidCallback onNext;
  const _IdentityPage({required this.step, required this.onBack, required this.onNext});
  @override
  ConsumerState<_IdentityPage> createState() => _IdentityPageState();
}


class _IdentityPageState extends ConsumerState<_IdentityPage> {
  late final TextEditingController _name;
  late final TextEditingController _company;
  @override
  void initState() {
    super.initState();
    final d = ref.read(onboardingDraftProvider);
    _name = TextEditingController(text: d.fullName);
    _company = TextEditingController(text: d.companyName);
  }
  @override
  void dispose() { _name.dispose(); _company.dispose(); super.dispose(); }

  bool get _valid => _name.text.trim().split(RegExp(r'\s+')).length >= 2;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return OneQuestionScaffold(
      title: t.onboardingAboutYouTitle,
      currentStep: widget.step, totalSteps: 7,
      onBack: widget.onBack,
      nextEnabled: _valid,
      onNext: () {
        ref.read(onboardingDraftProvider.notifier).update((d) => d.copyWith(
            fullName: _name.text.trim(), companyName: _company.text.trim()));
        widget.onNext();
      },
      child: Column(children: [
        TextField(controller: _name, autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: t.onboardingFullName),
          onChanged: (_) => setState(() {})),
        const SizedBox(height: 14),
        TextField(controller: _company,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: t.onboardingCompanyName)),
      ]),
    );
  }
}


// ---- Page 2 — Animals supported ----

class _AnimalsPage extends ConsumerStatefulWidget {
  final int step; final VoidCallback onBack; final VoidCallback onNext;
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
      ('MOL', t.animalMol), ('QOY', t.animalQoy), ('ECHKI', t.animalEchki),
      ('OT', t.animalOt), ('TOVUQ', t.animalTovuq),
    ];
    return OneQuestionScaffold(
      title: t.onboardingAnimalsTitleSupplier,
      subtitle: t.onboardingAnimalsHint,
      currentStep: widget.step, totalSteps: 7,
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
              border: Border.all(color: on ? cs.primary : cs.outlineVariant, width: 1.4)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (on) Padding(padding: const EdgeInsets.only(right: 6),
                  child: Icon(Icons.check_rounded, size: 18, color: cs.onPrimary)),
              Text(a.$2, style: TextStyle(fontWeight: FontWeight.w700,
                  color: on ? cs.onPrimary : cs.onSurface)),
            ])),
        );
      }).toList()),
    );
  }
}


// ---- Page 3 — Per-animal forms (Tirik / Tayyor) ----

class _FormsPage extends ConsumerStatefulWidget {
  final int step; final VoidCallback onBack; final VoidCallback onNext;
  const _FormsPage({required this.step, required this.onBack, required this.onNext});
  @override
  ConsumerState<_FormsPage> createState() => _FormsPageState();
}


class _FormsPageState extends ConsumerState<_FormsPage> {
  late Map<String, Set<String>> _modes;
  @override
  void initState() {
    super.initState();
    final d = ref.read(onboardingDraftProvider);
    _modes = {for (final a in d.animalsSupported)
        a: (d.deliveryModes[a] ?? const ['CUT']).toSet()};
  }

  bool get _valid => _modes.values.every((s) => s.isNotEmpty);

  void _toggle(String animal, String form) {
    setState(() {
      final s = _modes[animal] ?? <String>{};
      if (s.contains(form)) { s.remove(form); } else { s.add(form); }
      _modes[animal] = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final animalLabels = {
      'MOL': t.animalMol, 'QOY': t.animalQoy, 'ECHKI': t.animalEchki,
      'OT': t.animalOt, 'TOVUQ': t.animalTovuq,
    };
    return OneQuestionScaffold(
      title: t.onboardingFormsTitle,
      subtitle: t.onboardingFormsHint,
      currentStep: widget.step, totalSteps: 7,
      onBack: widget.onBack,
      nextEnabled: _valid,
      onNext: () {
        ref.read(onboardingDraftProvider.notifier).update((d) => d.copyWith(
            deliveryModes: _modes.map((k, v) => MapEntry(k, v.toList()))));
        widget.onNext();
      },
      child: ListView(children: _modes.keys.map((code) {
        final s = _modes[code]!;
        return Padding(padding: const EdgeInsets.only(bottom: 14),
          child: Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cs.outlineVariant)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(animalLabels[code] ?? code,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _FormChip(label: t.formLive, on: s.contains('LIVE'),
                    onTap: () => _toggle(code, 'LIVE'))),
                const SizedBox(width: 10),
                Expanded(child: _FormChip(label: t.formCut, on: s.contains('CUT'),
                    onTap: () => _toggle(code, 'CUT'))),
              ]),
            ])));
      }).toList()),
    );
  }
}


class _FormChip extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _FormChip({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: on ? cs.primary : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: on ? cs.primary : cs.outlineVariant)),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w700,
          color: on ? cs.onPrimary : cs.onSurface))));
  }
}


// ---- Page 4 — Location (reuses pattern from Qassob; abbreviated) ----

class _LocationPage extends ConsumerStatefulWidget {
  final int step; final VoidCallback onBack; final VoidCallback onNext;
  const _LocationPage({required this.step, required this.onBack, required this.onNext});
  @override
  ConsumerState<_LocationPage> createState() => _LocationPageState();
}


class _LocationPageState extends ConsumerState<_LocationPage> {
  double? _lat;
  double? _lng;
  String _region = '';
  bool _locating = false;
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
    setState(() => _locating = true);
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) await Geolocator.requestPermission();
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() { _lat = 41.3111; _lng = 69.2797; _region = 'Tashkent'; _locating = false; });
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10)));
      setState(() { _lat = pos.latitude; _lng = pos.longitude;
                     _region = 'Tashkent'; _locating = false; });
    } catch (_) {
      setState(() { _lat = 41.3111; _lng = 69.2797; _region = 'Tashkent'; _locating = false; });
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
      currentStep: widget.step, totalSteps: 7,
      onBack: widget.onBack,
      nextEnabled: ok,
      onNext: () {
        ref.read(onboardingDraftProvider.notifier).update((d) => d.copyWith(
            lat: _lat, lng: _lng, region: _region, address: _addressCtrl.text.trim()));
        widget.onNext();
      },
      child: Column(children: [
        Container(height: 160,
          decoration: BoxDecoration(color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20)),
          alignment: Alignment.center,
          child: _locating ? const CircularProgressIndicator()
              : ok ? Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.location_on_rounded, size: 48, color: cs.primary),
                  Text(_region, style: tt.titleMedium),
                  Text('${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                ])
              : Icon(Icons.map_outlined, size: 48, color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: _locating ? null : _detect,
            icon: const Icon(Icons.my_location_rounded),
            label: Text(t.onboardingLocationDetect)),
        const SizedBox(height: 16),
        TextField(controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Address'),
            maxLines: 2),
      ]),
    );
  }
}


// ---- Page 5 — Self-delivery + vehicle ----

class _SelfDeliveryPage extends ConsumerStatefulWidget {
  final int step; final VoidCallback onBack; final VoidCallback onNext;
  const _SelfDeliveryPage({required this.step, required this.onBack, required this.onNext});
  @override
  ConsumerState<_SelfDeliveryPage> createState() => _SelfDeliveryPageState();
}


class _SelfDeliveryPageState extends ConsumerState<_SelfDeliveryPage> {
  bool? _delivers;
  Set<String> _vehicles = {};
  final _plateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final d = ref.read(onboardingDraftProvider);
    _delivers = d.selfDelivers ? true : null;
    _vehicles = d.vehicleTypes.toSet();
    _plateCtrl.text = d.vehiclePlate;
  }
  @override
  void dispose() { _plateCtrl.dispose(); super.dispose(); }

  bool get _valid {
    if (_delivers == null) return false;
    if (_delivers == false) return true;
    return _vehicles.isNotEmpty && _plateCtrl.text.trim().length >= 4;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return OneQuestionScaffold(
      title: t.onboardingSelfDelivery,
      currentStep: widget.step, totalSteps: 7,
      onBack: widget.onBack,
      nextEnabled: _valid,
      onNext: () {
        ref.read(onboardingDraftProvider.notifier).update((d) => d.copyWith(
            selfDelivers: _delivers!,
            vehicleTypes: _delivers! ? _vehicles.toList() : const [],
            vehiclePlate: _delivers! ? _plateCtrl.text.trim() : ''));
        widget.onNext();
      },
      child: ListView(children: [
        Row(children: [
          Expanded(child: _YesNoCard(label: t.yes, selected: _delivers == true,
              onTap: () => setState(() => _delivers = true))),
          const SizedBox(width: 14),
          Expanded(child: _YesNoCard(label: t.no, selected: _delivers == false,
              onTap: () => setState(() => _delivers = false))),
        ]),
        if (_delivers == true) ...[
          const SizedBox(height: 20),
          Text(t.onboardingVehicleType, style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final v in [('REFRIGERATOR', t.vehicleRefrigerator),
                              ('CHORVA_TAXI', t.vehicleChorvaTaxi)])
              GestureDetector(
                onTap: () => setState(() {
                  if (_vehicles.contains(v.$1)) { _vehicles.remove(v.$1); } else { _vehicles.add(v.$1); }
                }),
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _vehicles.contains(v.$1) ? cs.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _vehicles.contains(v.$1) ? cs.primary : cs.outlineVariant)),
                  child: Text(v.$2, style: TextStyle(fontWeight: FontWeight.w700,
                      color: _vehicles.contains(v.$1) ? cs.onPrimary : cs.onSurface))),
              ),
          ]),
          const SizedBox(height: 16),
          TextField(controller: _plateCtrl,
            decoration: InputDecoration(labelText: t.onboardingVehiclePlate),
            onChanged: (_) => setState(() {})),
        ],
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
        child: Container(height: 110,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: 1.4)),
          alignment: Alignment.center,
          child: Text(label, style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: selected ? cs.onPrimary : cs.onSurface)))));
  }
}


// ---- Page 6 — Photo + submit ----

class _PhotoPage extends ConsumerStatefulWidget {
  final int step; final VoidCallback onBack; final VoidCallback onSubmit;
  final bool submitting;
  final String? error;
  const _PhotoPage({required this.step, required this.onBack, required this.onSubmit,
                     required this.submitting, this.error});
  @override
  ConsumerState<_PhotoPage> createState() => _PhotoPageState();
}


class _PhotoPageState extends ConsumerState<_PhotoPage> {
  String? _path;
  @override
  void initState() {
    super.initState();
    _path = ref.read(onboardingDraftProvider).photoPath;
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, maxWidth: 1280);
    if (file != null) {
      setState(() => _path = file.path);
      ref.read(onboardingDraftProvider.notifier).update((d) => d.copyWith(photoPath: file.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return OneQuestionScaffold(
      title: t.onboardingPhotoSupplier,
      currentStep: widget.step, totalSteps: 7,
      onBack: widget.onBack,
      nextEnabled: !widget.submitting,
      nextLabel: widget.submitting ? t.onboardingSubmitting : t.onboardingSubmit,
      onNext: widget.onSubmit,
      onSkip: widget.submitting ? null : widget.onSubmit,
      skipLabel: t.skip,
      child: Column(children: [
        GestureDetector(onTap: _pick, child: Container(
          height: 220,
          decoration: BoxDecoration(color: cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant)),
          alignment: Alignment.center,
          child: _path != null
              ? ClipRRect(borderRadius: BorderRadius.circular(20),
                  child: Image.file(File(_path!), fit: BoxFit.cover, width: double.infinity, height: 220))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.camera_alt_rounded, size: 48, color: cs.onSurfaceVariant),
                  Text(t.onboardingTakePhoto, style: TextStyle(color: cs.onSurfaceVariant)),
                ]))),
        if (widget.error != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(widget.error!, style: TextStyle(color: cs.error))),
      ]),
    );
  }
}
