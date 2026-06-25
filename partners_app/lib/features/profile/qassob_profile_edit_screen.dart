import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_core/shared_core.dart';

import '../../core/auth/partner_auth_notifier.dart';
import '../../core/network/providers.dart';
import '../../shared/widgets/image_source_picker.dart';
import '../servisim/servisim_screen.dart' show qassobMeProvider;


/// Full-page profile editor for qassobs. Sits behind Profil → Profilni tahrirlash. Different from
/// the lightweight Profilni tahrirlash sheet because qassobs also need to manage their avatar photo
/// (the buyer-app Servislar tab uses it as the primary card image), and a bottom sheet's height
/// constraint makes a photo editor awkward.
///
/// Editable fields:
///   • Avatar photo — tap to upload (camera/gallery via shared sheet); has dedicated "Rasmni
///     o'chirish" action when a photo already exists
///   • Full name (writes to both User.full_name and QassobProfile.full_name)
///   • Phone visibility toggle (drives whether the buyer-app card shows the call button)
///
/// All in one screen, one Save button. Avatar upload uses multipart PATCH; the rest goes via JSON
/// PATCH so we don't lose existing structured fields by accident.
class QassobProfileEditScreen extends ConsumerStatefulWidget {
  const QassobProfileEditScreen({super.key});
  @override
  ConsumerState<QassobProfileEditScreen> createState() => _QassobProfileEditScreenState();
}


class _QassobProfileEditScreenState extends ConsumerState<QassobProfileEditScreen> {
  final _nameCtrl = TextEditingController();
  bool _phoneVisible = true;
  String? _avatarUrl;                  // server-side URL (immutable until save)
  File? _newAvatarFile;                // freshly picked local file pending upload
  bool _removeAvatar = false;          // user tapped "rasmni o'chirish" before saving
  bool _saving = false;
  bool _hydrated = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic> m, User user) {
    if (_hydrated) return;
    _nameCtrl.text = (m['full_name'] as String?)?.trim().isNotEmpty == true
        ? m['full_name'] as String
        : user.fullName;
    _phoneVisible = (m['phone_visible'] as bool?) ?? true;
    _avatarUrl = (m['photo_url'] as String?) ?? '';
    _hydrated = true;
  }

  Future<void> _pickAvatar() async {
    final picked = await showImageSourcePicker(context);
    if (picked != null) {
      setState(() {
        _newAvatarFile = File(picked);
        _removeAvatar = false;
      });
    }
  }

  void _removeAvatarTap() {
    setState(() {
      _newAvatarFile = null;
      _avatarUrl = '';
      _removeAvatar = true;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() { _saving = true; _error = null; });
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(apiClientProvider);
      final fullName = _nameCtrl.text.trim();

      // 1) Mirror full_name to User.full_name so the dashboard greeting + chat list pick it up.
      await api.dio.patch('/auth/me/', data: {'full_name': fullName});

      // 2) Structured JSON PATCH for name + phone_visible. Photo NOT included here — handled below.
      await api.dio.patch('/qassobs/me/', data: {
        'full_name': fullName,
        'phone_visible': _phoneVisible,
      });

      // 3) Avatar — three states: new file (multipart upload), explicit remove, or no change.
      if (_newAvatarFile != null) {
        final form = FormData.fromMap({
          'photo': await MultipartFile.fromFile(_newAvatarFile!.path,
              filename: _newAvatarFile!.path.split('/').last),
        });
        await api.dio.patch('/qassobs/me/', data: form,
            options: Options(contentType: 'multipart/form-data'));
      } else if (_removeAvatar) {
        // DRF accepts an empty string for clearing a FileField via the JSON-image path; the field
        // serializer treats "" as "no file", flips the column to NULL.
        await api.dio.patch('/qassobs/me/', data: {'photo': null});
      }

      // 4) Refresh AuthState (greeting) + qassobMeProvider (Servisim).
      final me = await api.dio.get('/auth/me/');
      ref.read(partnerAuthProvider.notifier)
          .setAuthenticated(User.fromJson(me.data as Map<String, dynamic>));
      ref.invalidate(qassobMeProvider);

      messenger.showSnackBar(const SnackBar(content: Text("Profil saqlandi")));
      if (mounted) context.pop(true);
    } on DioException catch (e) {
      final data = e.response?.data;
      final detail = (data is Map && data['detail'] is String)
          ? data['detail'] as String
          : (e.message ?? 'Tarmoq xatosi');
      setState(() { _error = detail; _saving = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(partnerAuthProvider);
    final async = ref.watch(qassobMeProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final user = auth is AuthAuthenticated ? auth.user : null;

    return Scaffold(
      appBar: AppBar(title: const Text("Profilni tahrirlash"),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => context.pop())),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString(),
            style: TextStyle(color: cs.error))),
        data: (m) {
          if (m == null || user == null) {
            return const Center(child: Padding(padding: EdgeInsets.all(24),
                child: Text("Profilni yuklash imkoni bo'lmadi", textAlign: TextAlign.center)));
          }
          _hydrate(m, user);

          // Determine which image to render — fresh local file wins, then server URL, otherwise
          // placeholder avatar.
          Widget avatarChild;
          if (_newAvatarFile != null) {
            avatarChild = ClipOval(child: Image.file(_newAvatarFile!,
                fit: BoxFit.cover, width: 120, height: 120));
          } else if (!_removeAvatar && (_avatarUrl ?? '').isNotEmpty) {
            avatarChild = ClipOval(child: Image.network(_avatarUrl!,
                fit: BoxFit.cover, width: 120, height: 120,
                errorBuilder: (_, __, ___) => _avatarPlaceholder(cs)));
          } else {
            avatarChild = _avatarPlaceholder(cs);
          }
          final hasPhoto = (_newAvatarFile != null)
              || (!_removeAvatar && (_avatarUrl ?? '').isNotEmpty);

          return ListView(padding: const EdgeInsets.fromLTRB(20, 18, 20, 32), children: [
            // ---- Avatar block
            Center(child: Stack(children: [
              GestureDetector(onTap: _pickAvatar,
                child: Container(width: 120, height: 120,
                  decoration: BoxDecoration(shape: BoxShape.circle,
                      color: cs.primary.withValues(alpha: 0.10),
                      border: Border.all(color: cs.outlineVariant, width: 1)),
                  child: avatarChild)),
              Positioned(right: 0, bottom: 0,
                child: GestureDetector(onTap: _pickAvatar,
                  child: Container(padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 18)))),
            ])),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton.icon(onPressed: _pickAvatar,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text("Rasmni o'zgartirish")),
              if (hasPhoto) Padding(padding: const EdgeInsets.only(left: 12),
                  child: TextButton.icon(onPressed: _removeAvatarTap,
                    style: TextButton.styleFrom(foregroundColor: cs.error),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text("O'chirish"))),
            ]),
            const SizedBox(height: 24),

            // ---- Name field
            Text("To'liq ism",
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(border: OutlineInputBorder(),
                  hintText: 'Ism Familiya')),

            const SizedBox(height: 22),
            // ---- Phone visibility
            Container(decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant)),
              child: SwitchListTile.adaptive(
                value: _phoneVisible,
                onChanged: (v) => setState(() => _phoneVisible = v),
                title: const Text("Mijozlar uchun ochiq",
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text("Buyer telefon raqamingizni ko'ra oladi va to'g'ridan-to'g'ri qo'ng'iroq qila oladi",
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)))),

            if (_error != null) Padding(padding: const EdgeInsets.only(top: 18),
                child: Text(_error!, style: TextStyle(color: cs.error))),

            const SizedBox(height: 30),
            FilledButton(onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: Colors.white))
                  : const Text("Saqlash",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          ]);
        },
      ),
    );
  }

  Widget _avatarPlaceholder(ColorScheme cs) =>
      Icon(Icons.person_rounded, color: cs.primary, size: 56);
}
