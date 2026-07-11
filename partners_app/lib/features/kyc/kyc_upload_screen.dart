
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utils/upload.dart';
import 'kyc_providers.dart';


/// KYC upload screen — partners pick a kind (PASSPORT / LICENSE / FACILITY), take a photo, upload.
/// Backend stores image + admin reviews; signal flips profile.is_verified when both required are approved.
class KycUploadScreen extends ConsumerWidget {
  const KycUploadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(kycDocsProvider);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop()),
        title: Text(t.kycTitle)),
      body: SafeArea(child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString(), style: TextStyle(color: cs.error))),
        data: (docs) {
          final byKind = {for (final d in docs) d['kind']: d};
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
            Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
              child: Text(t.kycRequiredNote,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
            _KycRow(kind: 'PASSPORT', label: t.kycPassport, doc: byKind['PASSPORT']),
            _KycRow(kind: 'BUSINESS_LICENSE', label: t.kycLicense, doc: byKind['BUSINESS_LICENSE']),
            _KycRow(kind: 'FACILITY_PHOTO', label: t.kycFacility, doc: byKind['FACILITY_PHOTO']),
          ]);
        },
      )),
    );
  }
}


class _KycRow extends ConsumerStatefulWidget {
  final String kind;
  final String label;
  final Map<String, dynamic>? doc;
  const _KycRow({required this.kind, required this.label, required this.doc});
  @override
  ConsumerState<_KycRow> createState() => _KycRowState();
}


class _KycRowState extends ConsumerState<_KycRow> {
  bool _uploading = false;
  String? _error;

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, maxWidth: 2048);
    if (file == null) return;
    setState(() { _uploading = true; _error = null; });
    try {
      final api = ref.read(apiClientProvider);
      final form = FormData.fromMap({
        'kind': widget.kind,
        'image': await multipartFromPath(file.path),
      });
      final r = await api.dio.post('/kyc/', data: form);
      if (r.statusCode == 200 || r.statusCode == 201) {
        await ref.read(kycDocsProvider.notifier).refresh();
      } else {
        setState(() => _error = 'HTTP ${r.statusCode}');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final approved = widget.doc?['is_approved'] == true;
    final pending = widget.doc != null && !approved;
    return Padding(padding: const EdgeInsets.only(bottom: 14),
      child: Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outlineVariant)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(widget.label,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
            if (approved) _Badge(label: t.kycApproved,
                bg: const Color(0xFFD3EDD3), fg: const Color(0xFF1F5E1F))
            else if (pending) _Badge(label: t.kycPending,
                bg: const Color(0xFFFFE0B2), fg: const Color(0xFF8A4F00)),
          ]),
          if (widget.doc?['image_url'] != null
              && (widget.doc!['image_url'] as String).isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(borderRadius: BorderRadius.circular(12),
                child: Image.network(widget.doc!['image_url'] as String,
                    height: 120, width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (a, b, c) => const SizedBox.shrink()))),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _uploading ? null : _pickAndUpload,
              icon: _uploading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_rounded),
              label: Text(widget.doc == null ? t.kycUpload : t.kycReplace)),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: TextStyle(color: cs.error))),
        ])));
  }
}


class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge({required this.label, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w800,
          fontSize: 11, letterSpacing: 0.4)));
}
