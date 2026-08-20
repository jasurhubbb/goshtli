import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/utils/upload.dart';
import '../../shared/widgets/image_source_picker.dart';

String _copy(BuildContext context, String uz, String ru, String en) {
  return _copyForLanguage(
      Localizations.localeOf(context).languageCode, uz, ru, en);
}

String _copyForLanguage(String languageCode, String uz, String ru, String en) {
  return switch (languageCode) {
    'ru' => ru,
    'en' => en,
    _ => uz,
  };
}

/// Listing-entry form for the platform's own catalog team.
///
/// The form loads every active category and never asks for a supplier profile, seller preferences,
/// or self-delivery. Uzbek and Russian listing copy is captured separately so both buyer locales get
/// intentional content rather than duplicated text.
class NewListingScreen extends ConsumerStatefulWidget {
  const NewListingScreen({super.key});

  @override
  ConsumerState<NewListingScreen> createState() => _NewListingScreenState();
}

class _NewListingScreenState extends ConsumerState<NewListingScreen> {
  final _nameUz = TextEditingController();
  final _nameRu = TextEditingController();
  final _descriptionUz = TextEditingController();
  final _descriptionRu = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _priceMin = TextEditingController();
  final _priceMax = TextEditingController();

  String? _form;
  int _headCount = 1;
  File? _photo;
  bool _submitting = false;
  bool _loading = true;
  String? _error;
  String? _warning;
  int? _marketId;
  int? _categoryId;
  List<Map<String, dynamic>> _categories = const [];

  @override
  void initState() {
    super.initState();
    // _bootstrap reads Localizations from context; defer it until inherited widgets are available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bootstrap();
    });
  }

  @override
  void dispose() {
    _nameUz.dispose();
    _nameRu.dispose();
    _descriptionUz.dispose();
    _descriptionRu.dispose();
    _quantity.dispose();
    _price.dispose();
    _priceMin.dispose();
    _priceMax.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final languageCode = Localizations.localeOf(context).languageCode;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        _warning = null;
      });
    }
    final api = ref.read(apiClientProvider);
    int? marketId;
    List<Map<String, dynamic>> categories = const [];
    String? warning;

    try {
      final response = await api.dio.get('/markets/me/');
      if (_isSuccess(response.statusCode) &&
          response.data is Map &&
          response.data['id'] is num) {
        marketId = (response.data['id'] as num).toInt();
      }
    } catch (_) {}

    // Compatibility fallback for deployments that do not yet expose /markets/me/. The operator
    // still gets a usable form, with a clear warning that the active platform market was selected.
    if (marketId == null) {
      try {
        final response = await api.dio.get('/markets/');
        final markets = _asList(response.data);
        if (markets.isNotEmpty && markets.first['id'] is num) {
          marketId = (markets.first['id'] as num).toInt();
          warning = _copyForLanguage(
            languageCode,
            'Ichki bozor aniqlanmadi. E\'lon birinchi faol platforma bozoriga biriktiriladi.',
            'Внутренний рынок не определён. Объявление будет привязано к первому активному рынку платформы.',
            'The internal market was not found. This listing will use the first active platform market.',
          );
        }
      } catch (_) {}
    }

    try {
      final response = await api.dio.get('/categories/');
      if (_isSuccess(response.statusCode)) categories = _asList(response.data);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _marketId = marketId;
      _categories = categories;
      _warning = warning;
      _loading = false;
      if (marketId == null) {
        _error = _copy(
          context,
          'Platforma bozori topilmadi. Administrator bozor yaratishi kerak.',
          'Рынок платформы не найден. Администратор должен создать рынок.',
          'No platform market was found. An administrator needs to create one.',
        );
      } else if (categories.isEmpty) {
        _error = _copy(
          context,
          'Faol kategoriya topilmadi. Avval kategoriya yarating.',
          'Активные категории не найдены. Сначала создайте категорию.',
          'No active categories were found. Create a category first.',
        );
      }
    });
  }

  bool _isSuccess(int? statusCode) =>
      statusCode != null && statusCode >= 200 && statusCode < 300;

  List<Map<String, dynamic>> _asList(dynamic raw) {
    if (raw is List) return raw.cast<Map<String, dynamic>>();
    if (raw is Map && raw['results'] is List) {
      return (raw['results'] as List).cast<Map<String, dynamic>>();
    }
    return const [];
  }

  Future<void> _pickPhoto() async {
    final picked = await showImageSourcePicker(context, imageQuality: 80);
    if (picked != null && mounted) setState(() => _photo = File(picked));
  }

  void _openFullscreen() {
    if (_photo == null) return;
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
              child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image.file(_photo!, fit: BoxFit.contain),
          )),
        ),
      ),
    ));
  }

  bool get _valid {
    if (_submitting || _loading || _error != null) return false;
    if (_nameUz.text.trim().length < 2 || _nameRu.text.trim().length < 2) {
      return false;
    }
    if (_marketId == null || _categoryId == null || _form == null) return false;
    if (_form == 'RAW_CUT') {
      final quantity = double.tryParse(_quantity.text.trim());
      final price = double.tryParse(_price.text.trim());
      return quantity != null && quantity > 0 && price != null && price > 0;
    }
    final min = double.tryParse(_priceMin.text.trim());
    final max = double.tryParse(_priceMax.text.trim());
    return _headCount > 0 &&
        min != null &&
        min > 0 &&
        max != null &&
        max >= min;
  }

  Future<void> _editHeadCount() async {
    final controller = TextEditingController(text: '$_headCount');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_copy(
            context, 'Nechta bosh?', 'Сколько голов?', 'How many heads?')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context).cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text.trim())),
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && value > 0 && mounted) {
      setState(() => _headCount = value);
    }
  }

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    HapticFeedback.selectionClick();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(apiClientProvider);
      final today = DateTime.now();
      final isLive = _form == 'LIVE';
      final response = await api.dio.post('/listings/', data: {
        'market_id': _marketId,
        'category_id': _categoryId,
        'name_uz': _nameUz.text.trim(),
        'name_ru': _nameRu.text.trim(),
        'description_uz': _descriptionUz.text.trim(),
        'description_ru': _descriptionRu.text.trim(),
        'quantity_kg': isLive ? '$_headCount' : _quantity.text.trim(),
        'price_per_kg': isLive ? _priceMin.text.trim() : _price.text.trim(),
        'sale_type': isLive ? 'BY_HEAD' : 'BY_WEIGHT',
        'is_live_animal': isLive,
        if (isLive) 'head_count': _headCount,
        if (isLive) 'price_min': _priceMin.text.trim(),
        if (isLive) 'price_max': _priceMax.text.trim(),
        'location': 'Tashkent',
        'available_from':
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
        'status': 'ACTIVE',
        // Internal fulfillment always uses the platform's delivery workflow.
        'supplier_delivers': false,
      });
      if (!_isSuccess(response.statusCode)) {
        throw _ListingSubmissionException(_detailFromResponse(response.data) ??
            'HTTP ${response.statusCode}');
      }
      final rawId = response.data is Map ? response.data['id'] : null;
      final id = rawId is num ? rawId.toInt() : null;
      if (id == null) {
        throw const _ListingSubmissionException('Listing id was not returned.');
      }

      var photoFailed = false;
      if (_photo != null) {
        try {
          final form = FormData.fromMap({
            'image': await multipartFromPath(_photo!.path),
          });
          final upload =
              await api.dio.post('/listings/$id/photos/', data: form);
          photoFailed = !_isSuccess(upload.statusCode);
        } catch (_) {
          photoFailed = true;
        }
      }

      if (!mounted) return;
      if (photoFailed) {
        messenger.showSnackBar(SnackBar(
            content: Text(_copy(
          context,
          'E\'lon saqlandi, lekin rasm yuklanmadi.',
          'Объявление сохранено, но фото не загрузилось.',
          'The listing was saved, but its photo did not upload.',
        ))));
      } else {
        messenger.showSnackBar(SnackBar(
            content: Text(_copy(
          context,
          'E\'lon katalogga qo\'shildi.',
          'Объявление добавлено в каталог.',
          'The listing was added to the catalog.',
        ))));
      }
      context.pop(id);
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _detailFromResponse(error.response?.data) ??
            error.message ??
            _copy(context, 'Tarmoq xatosi', 'Ошибка сети', 'Network error');
      });
    } on _ListingSubmissionException catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.message;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = error.toString();
        });
      }
    }
  }

  String? _detailFromResponse(dynamic data) {
    if (data is Map) {
      if (data['detail'] is String) return data['detail'] as String;
      final parts = <String>[];
      data.forEach((key, value) {
        if (value is List && value.isNotEmpty) {
          parts.add('$key: ${value.first}');
        }
      });
      if (parts.isNotEmpty) return parts.join('\n');
    }
    return null;
  }

  String _categoryLabel(Map<String, dynamic> category) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'ru') {
      return (category['name_ru'] ?? category['name_uz'] ?? '—').toString();
    }
    return (category['name_uz'] ?? category['name_ru'] ?? '—').toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.pop(),
        ),
        title: Text(t.catalogAddNew),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  GestureDetector(
                    onTap: _photo == null ? _pickPhoto : _openFullscreen,
                    child: Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: _photo == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_a_photo_outlined,
                                    size: 40, color: cs.onSurfaceVariant),
                                const SizedBox(height: 8),
                                Text(
                                  _copy(context, 'Rasm qo\'shish',
                                      'Добавить фото', 'Add photo'),
                                  style: tt.bodyMedium
                                      ?.copyWith(color: cs.onSurfaceVariant),
                                ),
                              ],
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.file(_photo!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity),
                            ),
                    ),
                  ),
                  if (_photo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: OutlinedButton.icon(
                        onPressed: _pickPhoto,
                        icon: const Icon(Icons.image_outlined),
                        label: Text(_copy(context, 'Boshqa rasm', 'Другое фото',
                            'Choose another')),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Text(
                      _copy(context, 'E\'lon matni', 'Текст объявления',
                          'Listing copy'),
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameUz,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: "Nomi — o'zbekcha *",
                        hintText: "Barra go'shti"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameRu,
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Название — по-русски *',
                        hintText: 'Свежее мясо'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionUz,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        labelText: "Tavsif — o'zbekcha",
                        alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descriptionRu,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        labelText: 'Описание — по-русски',
                        alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 22),
                  Text(
                      _copy(context, "Go'sht turi *", 'Категория *',
                          'Category *'),
                      style:
                          tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((category) {
                      final id = (category['id'] as num).toInt();
                      return _FormChip(
                        label: _categoryLabel(category),
                        selected: _categoryId == id,
                        onTap: () => setState(() => _categoryId = id),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Text(
                      _copy(context, 'Mahsulot shakli *', 'Форма товара *',
                          'Listing type *'),
                      style:
                          tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _FormChip(
                      label: _copy(context, "Tayyor go'sht", 'Готовое мясо',
                          'Ready meat'),
                      selected: _form == 'RAW_CUT',
                      onTap: () => setState(() => _form = 'RAW_CUT'),
                    ),
                    _FormChip(
                      label:
                          _copy(context, 'Tirik', 'Живой скот', 'Live animal'),
                      selected: _form == 'LIVE',
                      onTap: () => setState(() => _form = 'LIVE'),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  if (_form == 'LIVE') ...[
                    Text(
                        _copy(context, 'Nechta bosh? *', 'Сколько голов? *',
                            'Head count *'),
                        style: tt.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    _CountStepper(
                      count: _headCount,
                      onDec: () => setState(() {
                        if (_headCount > 1) _headCount--;
                      }),
                      onInc: () => setState(() => _headCount++),
                      onEdit: _editHeadCount,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _copy(
                          context,
                          "Narx oralig'i (so'm/bosh) *",
                          'Диапазон цены (сум/голова) *',
                          'Price range (UZS/head) *'),
                      style:
                          tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                          child: TextField(
                        controller: _priceMin,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: _copy(
                                context, 'Eng past', 'Минимум', 'Minimum')),
                      )),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('—',
                            style: tt.titleLarge
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ),
                      Expanded(
                          child: TextField(
                        controller: _priceMax,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: _copy(
                                context, 'Eng yuqori', 'Максимум', 'Maximum')),
                      )),
                    ]),
                  ] else if (_form == 'RAW_CUT') ...[
                    Row(children: [
                      Expanded(
                          child: TextField(
                        controller: _quantity,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: _copy(context, 'Miqdor (kg) *',
                                'Количество (кг) *', 'Quantity (kg) *')),
                      )),
                      const SizedBox(width: 12),
                      Expanded(
                          child: TextField(
                        controller: _price,
                        onChanged: (_) => setState(() {}),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: InputDecoration(
                            labelText: _copy(context, "Narx so'm/kg *",
                                'Цена сум/кг *', 'Price UZS/kg *')),
                      )),
                    ]),
                  ] else
                    Text(
                      _copy(context, 'Mahsulot shaklini tanlang',
                          'Выберите форму товара', 'Choose a listing type'),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  if (_warning != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: _MessageBox(
                          message: _warning!,
                          background: const Color(0xFFFFF4E5),
                          foreground: const Color(0xFF8A4F00)),
                    ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: Column(children: [
                        _MessageBox(
                            message: _error!,
                            background: cs.errorContainer,
                            foreground: cs.onErrorContainer),
                        if (_marketId == null || _categories.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: OutlinedButton.icon(
                              onPressed: _bootstrap,
                              icon: const Icon(Icons.refresh_rounded),
                              label: Text(t.tryAgain),
                            ),
                          ),
                      ]),
                    ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: _valid ? _submit : null,
                      icon: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Icon(Icons.publish_rounded),
                      label: Text(_submitting
                          ? t.loading
                          : _copy(context, 'E\'lonni chiqarish',
                              'Опубликовать объявление', 'Publish listing')),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ListingSubmissionException implements Exception {
  final String message;

  const _ListingSubmissionException(this.message);
}

class _MessageBox extends StatelessWidget {
  final String message;
  final Color background;
  final Color foreground;

  const _MessageBox({
    required this.message,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(10)),
        child: Text(message, style: TextStyle(color: foreground)),
      );
}

class _CountStepper extends StatelessWidget {
  final int count;
  final VoidCallback onDec;
  final VoidCallback onInc;
  final VoidCallback onEdit;

  const _CountStepper({
    required this.count,
    required this.onDec,
    required this.onInc,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          onPressed: count > 1 ? onDec : null,
          icon: const Icon(Icons.remove_rounded),
          visualDensity: VisualDensity.compact,
        ),
        InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('$count',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 14, color: cs.onSurfaceVariant),
            ]),
          ),
        ),
        IconButton(
          onPressed: onInc,
          icon: const Icon(Icons.add_rounded),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }
}

class _FormChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FormChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
        ),
        child: Text(label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: selected ? cs.onPrimary : cs.onSurface,
            )),
      ),
    );
  }
}
