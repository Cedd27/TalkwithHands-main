import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/alphabet_sign.dart';
import '../models/basic_word.dart';
import '../models/number_sign.dart';
import '../services/admin_upload_service.dart';
import '../services/alphabet_service.dart';
import '../services/basic_word_service.dart';
import '../services/number_service.dart';
import '../ui/app_shell.dart';

enum AdminContentTab { alphabets, numbers, basicWords }

extension AdminContentTabInfo on AdminContentTab {
  String get title {
    switch (this) {
      case AdminContentTab.alphabets:
        return 'ALPHABETS';
      case AdminContentTab.numbers:
        return 'NUMBERS';
      case AdminContentTab.basicWords:
        return 'BASIC WORDS';
    }
  }

  String get shortLabel {
    switch (this) {
      case AdminContentTab.alphabets:
        return 'ABC';
      case AdminContentTab.numbers:
        return '123';
      case AdminContentTab.basicWords:
        return 'WORDS';
    }
  }

  String get keyLabel {
    switch (this) {
      case AdminContentTab.alphabets:
        return 'Letter';
      case AdminContentTab.numbers:
        return 'Number';
      case AdminContentTab.basicWords:
        return 'Key';
    }
  }
}

class AdminContentScreen extends StatefulWidget {
  final String userName;
  final AdminContentTab initialTab;

  const AdminContentScreen({
    super.key,
    required this.userName,
    this.initialTab = AdminContentTab.alphabets,
  });

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();
  final _alphabetService = AlphabetService();
  final _numberService = NumberService();
  final _basicWordService = BasicWordService();
  final _uploadService = AdminUploadService();

  late AdminContentTab _tab;
  List<AdminSignItem> _items = [];
  Set<String> _selectedIds = {};
  bool _loading = true;
  bool _saving = false;
  String _query = '';
  String? _selectedBasicWordCategory;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _selectedIds = {};
    });

    try {
      final items = switch (_tab) {
        AdminContentTab.alphabets =>
          (await _alphabetService.listAllAlphabetSigns())
              .map(AdminSignItem.fromAlphabet)
              .toList(),
        AdminContentTab.numbers => (await _numberService.listAllNumberSigns())
            .map(AdminSignItem.fromNumber)
            .toList(),
        AdminContentTab.basicWords => (await _basicWordService.listBasicWords())
            .where(BasicWordService.isVisibleToUsers)
            .map(AdminSignItem.fromBasicWord)
            .toList(),
      };
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<AdminSignItem> get _filteredItems {
    final items = _items.where((item) {
      if (_tab == AdminContentTab.basicWords &&
          _selectedBasicWordCategory != null &&
          item.category != _selectedBasicWordCategory) {
        return false;
      }
      if (_query.isEmpty) return true;
      return item.label.toLowerCase().contains(_query) ||
          item.title.toLowerCase().contains(_query) ||
          item.category.toLowerCase().contains(_query) ||
          item.description.toLowerCase().contains(_query);
    });
    return items.toList();
  }

  Future<void> _deleteSelected() async {
    final selected = _items
        .where((item) => _selectedIds.contains(item.id))
        .map((item) => item.label)
        .join(', ');
    if (selected.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteDialog(
        title: 'Delete',
        message: 'Delete ${_selectedIds.length} selected item(s)?',
        details: selected,
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      for (final id in _selectedIds) {
        switch (_tab) {
          case AdminContentTab.alphabets:
            await _alphabetService.deleteAlphabetSign(id);
          case AdminContentTab.numbers:
            await _numberService.deleteNumberSign(id);
          case AdminContentTab.basicWords:
            await _basicWordService.deleteBasicWord(id);
        }
      }
      await _load();
      _snack('Deleted successfully.');
    } catch (e) {
      _snack(_messageFor(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openEditor([AdminSignItem? item]) async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SignEditorDialog(
        tab: _tab,
        item: item,
        uploadService: _uploadService,
        onSave: (payload) async {
          if (item == null) {
            switch (_tab) {
              case AdminContentTab.alphabets:
                await _alphabetService.createAlphabetSign(payload);
              case AdminContentTab.numbers:
                await _numberService.createNumberSign(payload);
              case AdminContentTab.basicWords:
                await _basicWordService.createBasicWord(payload);
            }
          } else {
            switch (_tab) {
              case AdminContentTab.alphabets:
                await _alphabetService.updateAlphabetSign(item.id, payload);
              case AdminContentTab.numbers:
                await _numberService.updateNumberSign(item.id, payload);
              case AdminContentTab.basicWords:
                await _basicWordService.updateBasicWord(item.id, payload);
            }
          }
        },
      ),
    );

    if (saved == true) {
      await _load();
      _snack(item == null ? 'Created successfully.' : 'Updated successfully.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIds.length;
    final canManageBasicWords = _tab == AdminContentTab.basicWords;

    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: widget.userName,
        activeScreen: _tab.title,
        onClose: () => Navigator.of(context).pop(),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                onBack: () => Navigator.of(context).pop(),
                onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              LayoutBuilder(
                builder: (context, constraints) => Text(
                  'ADMIN ${_tab.title}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kVividBlue,
                    fontSize: constraints.maxWidth < 390 ? 28 : 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width < 520 ? 16 : 28,
                ),
                child: _Toolbar(
                  controller: _searchController,
                  tab: _tab,
                  selectedCount: selectedCount,
                  saving: _saving,
                  canManage: canManageBasicWords,
                  onAdd: () => _openEditor(),
                  onDelete: selectedCount == 0 ? null : _deleteSelected,
                ),
              ),
              const SizedBox(height: 18),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    if (_error != null) {
      return _AdminStateMessage(
        message: _error!,
        actionLabel: 'Retry',
        onAction: _load,
      );
    }

    if (_tab == AdminContentTab.basicWords &&
        _query.isEmpty &&
        _selectedBasicWordCategory == null) {
      return _buildBasicWordCategoryGrid();
    }

    final items = _filteredItems;
    if (items.isEmpty) {
      return _AdminStateMessage(
        message: 'No matching records found.',
        actionLabel: _tab == AdminContentTab.basicWords ? 'Add item' : 'Retry',
        onAction:
            _tab == AdminContentTab.basicWords ? () => _openEditor() : _load,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1180
              ? 6
              : constraints.maxWidth >= 920
                  ? 5
                  : constraints.maxWidth >= 640
                      ? 4
                      : constraints.maxWidth >= 430
                          ? 3
                          : 2;
          final gap = constraints.maxWidth >= 900 ? 18.0 : 12.0;
          final horizontalPadding = constraints.maxWidth < 520 ? 16.0 : 28.0;
          final contentWidth =
              constraints.maxWidth > 1100 ? 1100.0 : constraints.maxWidth;
          final itemWidth =
              (contentWidth - horizontalPadding * 2 - gap * (columns - 1)) /
                  columns;

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              0,
              horizontalPadding,
              28,
            ),
            children: [
              if (_tab == AdminContentTab.basicWords &&
                  _selectedBasicWordCategory != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _selectedBasicWordCategory = null),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(_selectedBasicWordCategory!),
                      style: TextButton.styleFrom(
                        foregroundColor: kVividBlue,
                        textStyle: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Wrap(
                    spacing: gap,
                    runSpacing: 18,
                    children: items.map((item) {
                      final selected = _selectedIds.contains(item.id);
                      return SizedBox(
                        width: itemWidth,
                        child: _AdminSignCard(
                          item: item,
                          selected: selected,
                          selectable: _tab == AdminContentTab.basicWords,
                          onSelected: (value) {
                            setState(() {
                              if (value) {
                                _selectedIds.add(item.id);
                              } else {
                                _selectedIds.remove(item.id);
                              }
                            });
                          },
                          onEdit: () => _openEditor(item),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBasicWordCategoryGrid() {
    final categories = _items
        .map((item) => item.category.trim())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900
        ? 4
        : width >= 600
            ? 3
            : 2;
    final padding = width < 520 ? 16.0 : 28.0;
    final contentWidth = width > 980 ? 980.0 : width;
    const gap = 14.0;
    final cardWidth =
        (contentWidth - padding * 2 - gap * (columns - 1)) / columns;

    if (categories.isEmpty) {
      return _AdminStateMessage(
        message: 'No user-visible basic words with tutorial videos yet.',
        actionLabel: 'Add item',
        onAction: () => _openEditor(),
      );
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(padding, 0, padding, 28),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: categories.map((category) {
                final count =
                    _items.where((item) => item.category == category).length;
                return SizedBox(
                  width: cardWidth,
                  child: InkWell(
                    onTap: () =>
                        setState(() => _selectedBasicWordCategory = category),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 106,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFB8DFF5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.category_outlined,
                              color: kVividBlue, size: 26),
                          const Spacer(),
                          Text(
                            category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: kVividBlue,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '$count words',
                            style: const TextStyle(
                              color: Color(0xFF5E6F7F),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  final TextEditingController controller;
  final AdminContentTab tab;
  final int selectedCount;
  final bool saving;
  final bool canManage;
  final VoidCallback onAdd;
  final VoidCallback? onDelete;

  const _Toolbar({
    required this.controller,
    required this.tab,
    required this.selectedCount,
    required this.saving,
    required this.canManage,
    required this.onAdd,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final search = _SearchField(controller: controller);
    final actions = canManage
        ? Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.end,
            children: [
              _AdminButton(
                icon: Icons.add_rounded,
                label: 'Add ${tab.shortLabel}',
                color: const Color(0xFF28D944),
                onTap: saving ? null : onAdd,
              ),
              _AdminButton(
                icon: Icons.delete_rounded,
                label: selectedCount == 0 ? 'Delete' : 'Delete $selectedCount',
                color: const Color(0xFFFF3B3B),
                onTap: saving ? null : onDelete,
              ),
            ],
          )
        : const SizedBox.shrink();

    if (compact) {
      return Column(
        children: [
          search,
          const SizedBox(height: 12),
          actions,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: search),
        if (canManage) ...[
          const SizedBox(width: 16),
          actions,
        ],
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;

  const _SearchField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.black, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Search...',
                hintStyle: TextStyle(color: Color(0xFF9DA4AD)),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
            ),
          ),
          Container(
            width: 68,
            alignment: Alignment.center,
            color: const Color(0xFF62D9D8),
            child: const Icon(Icons.search_rounded, color: Colors.black),
          ),
        ],
      ),
    );
  }
}

class _AdminButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _AdminButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled ? color : const Color(0xFFB9C2CC),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black, width: 1.4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.black, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminSignCard extends StatelessWidget {
  final AdminSignItem item;
  final bool selected;
  final bool selectable;
  final ValueChanged<bool> onSelected;
  final VoidCallback onEdit;

  const _AdminSignCard({
    required this.item,
    required this.selected,
    required this.selectable,
    required this.onSelected,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 176,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFC8F4F8) : const Color(0xFFEAF9FB),
        border: Border.all(
          color: selected ? const Color(0xFF28D944) : Colors.black,
          width: selected ? 2 : 1.2,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          if (selectable)
            Row(
              children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: Checkbox(
                    value: selected,
                    onChanged: (value) => onSelected(value ?? false),
                    activeColor: const Color(0xFF28D944),
                    checkColor: Colors.black,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                if (!item.isActive)
                  const Icon(Icons.visibility_off_rounded,
                      color: Colors.black54, size: 18),
              ],
            )
          else if (!item.isActive)
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.visibility_off_rounded,
                  color: Colors.black54, size: 18),
            ),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(4),
              child: _SignImage(item: item),
            ),
          ),
          Container(
            width: double.infinity,
            height: 48,
            color: const Color(0xFF078FA5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Material(
                  color: const Color(0xFF28D944),
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    onTap: onEdit,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 58,
                      height: 18,
                      alignment: Alignment.center,
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SignImage extends StatelessWidget {
  final AdminSignItem item;

  const _SignImage({required this.item});

  @override
  Widget build(BuildContext context) {
    if (item.imageUrl.isNotEmpty) {
      return Image.network(
        item.imageUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _ImageFallback(label: item.label),
      );
    }

    if (item.imageAsset.isNotEmpty) {
      return Image.asset(
        item.imageAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _ImageFallback(label: item.label),
      );
    }

    return _ImageFallback(label: item.label);
  }
}

class _ImageFallback extends StatelessWidget {
  final String label;

  const _ImageFallback({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 34,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SignEditorDialog extends StatefulWidget {
  final AdminContentTab tab;
  final AdminSignItem? item;
  final AdminUploadService uploadService;
  final Future<void> Function(Map<String, dynamic> payload) onSave;

  const _SignEditorDialog({
    required this.tab,
    required this.item,
    required this.uploadService,
    required this.onSave,
  });

  @override
  State<_SignEditorDialog> createState() => _SignEditorDialogState();
}

class _SignEditorDialogState extends State<_SignEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _keyController;
  late final TextEditingController _titleController;
  late final TextEditingController _categoryController;
  late final TextEditingController _imageAssetController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _videoAssetController;
  late final TextEditingController _videoUrlController;
  late final TextEditingController _frontVideoUrlController;
  late final TextEditingController _leftVideoUrlController;
  late final TextEditingController _rightVideoUrlController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _sortOrderController;
  bool _active = true;
  bool _saving = false;
  bool _uploadingImage = false;
  bool _uploadingVideo = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    const nextSort = '1';
    _keyController = TextEditingController(text: item?.label ?? '');
    _titleController = TextEditingController(text: item?.title ?? '');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _imageAssetController = TextEditingController(
      text: item?.imageAsset ?? _defaultImageAsset(),
    );
    _imageUrlController = TextEditingController(text: item?.imageUrl ?? '');
    _videoAssetController = TextEditingController(
      text: item?.videoAsset ?? _defaultVideoAsset(),
    );
    _videoUrlController = TextEditingController(text: item?.videoUrl ?? '');
    _frontVideoUrlController =
        TextEditingController(text: item?.frontVideoUrl ?? '');
    _leftVideoUrlController =
        TextEditingController(text: item?.leftVideoUrl ?? '');
    _rightVideoUrlController =
        TextEditingController(text: item?.rightVideoUrl ?? '');
    _descriptionController =
        TextEditingController(text: item?.description ?? '');
    _sortOrderController =
        TextEditingController(text: item?.sortOrder.toString() ?? nextSort);
    _active = item?.isActive ?? true;
  }

  @override
  void dispose() {
    _keyController.dispose();
    _titleController.dispose();
    _categoryController.dispose();
    _imageAssetController.dispose();
    _imageUrlController.dispose();
    _videoAssetController.dispose();
    _videoUrlController.dispose();
    _frontVideoUrlController.dispose();
    _leftVideoUrlController.dispose();
    _rightVideoUrlController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  String _defaultImageAsset() {
    return widget.tab == AdminContentTab.alphabets
        ? 'assets/images/alphabets/A.png'
        : widget.tab == AdminContentTab.numbers
            ? 'assets/images/numbers/1.png'
            : '';
  }

  String _defaultVideoAsset() {
    return '';
  }

  Future<void> _pickAndUpload({required bool image}) async {
    setState(() {
      if (image) {
        _uploadingImage = true;
      } else {
        _uploadingVideo = true;
      }
    });

    try {
      final picker = ImagePicker();
      final file = image
          ? await picker.pickImage(source: ImageSource.gallery)
          : await picker.pickVideo(source: ImageSource.gallery);
      if (file == null) return;

      final url = await widget.uploadService.uploadFile(file.path);
      setState(() {
        if (image) {
          _imageUrlController.text = url;
        } else {
          _videoUrlController.text = url;
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFor(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
          _uploadingVideo = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (widget.tab == AdminContentTab.basicWords &&
        _videoAssetController.text.trim().isEmpty &&
        _videoUrlController.text.trim().isEmpty &&
        _frontVideoUrlController.text.trim().isEmpty &&
        _leftVideoUrlController.text.trim().isEmpty &&
        _rightVideoUrlController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add at least one sign video before saving.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave(_payload());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_messageFor(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateBasicWordCategory(String? value) {
    final category = value?.trim() ?? '';
    if (category.isEmpty) return 'Required';
    final normalized = category.toLowerCase();
    if (normalized == 'alphabet' ||
        normalized == 'number' ||
        normalized == 'numbers') {
      return 'Use a word category, not Alphabet or Number.';
    }
    return null;
  }

  Map<String, dynamic> _payload() {
    final sortOrder = int.parse(_sortOrderController.text.trim());
    final common = {
      'title': _titleController.text.trim(),
      'image_asset': _imageAssetController.text.trim(),
      'image_url': _imageUrlController.text.trim(),
      'video_asset': _videoAssetController.text.trim(),
      'video_url': _videoUrlController.text.trim(),
      'description': _descriptionController.text.trim(),
      'sort_order': sortOrder,
      'is_active': _active,
    };

    switch (widget.tab) {
      case AdminContentTab.alphabets:
        return {
          ...common,
          'letter': _keyController.text.trim().toUpperCase(),
        };
      case AdminContentTab.numbers:
        return {
          ...common,
          'number': int.parse(_keyController.text.trim()),
        };
      case AdminContentTab.basicWords:
        return {
          ...common,
          'key': _keyController.text.trim().toLowerCase(),
          'category': _categoryController.text.trim(),
          'front_video_url': _frontVideoUrlController.text.trim(),
          'left_video_url': _leftVideoUrlController.text.trim(),
          'right_video_url': _rightVideoUrlController.text.trim(),
        };
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.item == null ? 'Add' : 'Edit';
    final keyLabel = widget.tab.keyLabel;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kAccent, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                color: const Color(0xFF11B7CB),
                child: Row(
                  children: [
                    Text(
                      '$title $keyLabel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _DialogField(
                              controller: _keyController,
                              label: keyLabel,
                              validator: (value) => _validateKey(value),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _DialogField(
                              controller: _sortOrderController,
                              label: 'Sort order',
                              keyboardType: TextInputType.number,
                              validator: (value) =>
                                  int.tryParse(value?.trim() ?? '') == null
                                      ? 'Required number'
                                      : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _DialogField(
                        controller: _titleController,
                        label: 'Title',
                        validator: _required,
                      ),
                      if (widget.tab == AdminContentTab.basicWords) ...[
                        const SizedBox(height: 12),
                        _DialogField(
                          controller: _categoryController,
                          label: 'Category',
                          validator: _validateBasicWordCategory,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _DialogField(
                        controller: _descriptionController,
                        label: 'Instructions / description',
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      _DialogField(
                        controller: _imageAssetController,
                        label: 'Image asset path',
                        validator: widget.tab == AdminContentTab.basicWords
                            ? null
                            : _required,
                      ),
                      const SizedBox(height: 12),
                      _UploadRow(
                        controller: _imageUrlController,
                        label: 'Image URL',
                        uploading: _uploadingImage,
                        onUpload: () => _pickAndUpload(image: true),
                      ),
                      const SizedBox(height: 12),
                      _DialogField(
                        controller: _videoAssetController,
                        label: 'Video asset path',
                      ),
                      const SizedBox(height: 12),
                      _UploadRow(
                        controller: _videoUrlController,
                        label: 'Video URL',
                        uploading: _uploadingVideo,
                        onUpload: () => _pickAndUpload(image: false),
                      ),
                      if (widget.tab == AdminContentTab.basicWords) ...[
                        const SizedBox(height: 12),
                        _DialogField(
                          controller: _frontVideoUrlController,
                          label: 'Front video URL (optional)',
                        ),
                        const SizedBox(height: 12),
                        _DialogField(
                          controller: _leftVideoUrlController,
                          label: 'Left video URL (optional)',
                        ),
                        const SizedBox(height: 12),
                        _DialogField(
                          controller: _rightVideoUrlController,
                          label: 'Right video URL (optional)',
                        ),
                      ],
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _active,
                        activeThumbColor: const Color(0xFF28D944),
                        title: const Text(
                          'Visible on user page',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onChanged: (value) => setState(() => _active = value),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _DialogButton(
                      label: 'Cancel',
                      color: Colors.white,
                      onTap: _saving ? null : () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 10),
                    _DialogButton(
                      label: _saving ? 'Saving...' : 'Submit',
                      color: const Color(0xFF28D944),
                      onTap: _saving ? null : _submit,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateKey(String? value) {
    final text = value?.trim() ?? '';
    if (widget.tab == AdminContentTab.alphabets) {
      return RegExp(r'^[A-Za-z]$').hasMatch(text) ? null : 'Use A-Z';
    }
    if (widget.tab == AdminContentTab.basicWords) {
      return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(text)
          ? null
          : 'Use letters, numbers, _ or -';
    }
    final number = int.tryParse(text);
    return number != null && number >= 0 && number <= 999 ? null : 'Use 0-999';
  }

  String? _required(String? value) {
    return (value?.trim().isEmpty ?? true) ? 'Required' : null;
  }
}

class _UploadRow extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool uploading;
  final VoidCallback onUpload;

  const _UploadRow({
    required this.controller,
    required this.label,
    required this.uploading,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _DialogField(
            controller: controller,
            label: label,
          ),
        ),
        const SizedBox(width: 10),
        Padding(
          padding: const EdgeInsets.only(top: 23),
          child: _DialogButton(
            label: uploading ? 'Uploading...' : 'Upload',
            color: const Color(0xFF31A8E8),
            onTap: uploading ? null : onUpload,
          ),
        ),
      ],
    );
  }
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _DialogField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF546070)),
        filled: true,
        fillColor: const Color(0xFFF4F7FA),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF11B7CB), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFFFF3B3B)),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _DialogButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? const Color(0xFFB9C2CC) : color,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.black, width: 1.2),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteDialog extends StatelessWidget {
  final String title;
  final String message;
  final String details;

  const _DeleteDialog({
    required this.title,
    required this.message,
    required this.details,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF2177E8), width: 8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFF62D9D8),
              alignment: Alignment.center,
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    details,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black87),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _DialogButton(
                    label: 'Cancel',
                    color: Colors.white,
                    onTap: () => Navigator.of(context).pop(false),
                  ),
                  const SizedBox(width: 10),
                  _DialogButton(
                    label: 'Delete',
                    color: const Color(0xFFFF3B3B),
                    onTap: () => Navigator.of(context).pop(true),
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

class _AdminStateMessage extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _AdminStateMessage({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _AdminButton(
              icon: Icons.refresh_rounded,
              label: actionLabel,
              color: const Color(0xFF62D9D8),
              onTap: onAction,
            ),
          ],
        ),
      ),
    );
  }
}

class AdminSignItem {
  final String id;
  final String label;
  final String title;
  final String imageAsset;
  final String imageUrl;
  final String videoAsset;
  final String videoUrl;
  final String frontVideoUrl;
  final String leftVideoUrl;
  final String rightVideoUrl;
  final String category;
  final String description;
  final int sortOrder;
  final bool isActive;

  const AdminSignItem({
    required this.id,
    required this.label,
    required this.title,
    required this.imageAsset,
    required this.imageUrl,
    required this.videoAsset,
    required this.videoUrl,
    this.frontVideoUrl = '',
    this.leftVideoUrl = '',
    this.rightVideoUrl = '',
    required this.category,
    required this.description,
    required this.sortOrder,
    required this.isActive,
  });

  factory AdminSignItem.fromAlphabet(AlphabetSign sign) {
    return AdminSignItem(
      id: sign.id,
      label: sign.letter,
      title: sign.title,
      imageAsset: sign.imageAsset,
      imageUrl: sign.imageUrl,
      videoAsset: sign.videoAsset,
      videoUrl: sign.videoUrl,
      category: '',
      description: sign.description,
      sortOrder: sign.sortOrder,
      isActive: sign.isActive,
    );
  }

  factory AdminSignItem.fromNumber(NumberSign sign) {
    return AdminSignItem(
      id: sign.id,
      label: sign.number.toString(),
      title: sign.title,
      imageAsset: sign.imageAsset,
      imageUrl: sign.imageUrl,
      videoAsset: sign.videoAsset,
      videoUrl: sign.videoUrl,
      category: '',
      description: sign.description,
      sortOrder: sign.sortOrder,
      isActive: sign.isActive,
    );
  }

  factory AdminSignItem.fromBasicWord(BasicWord word) {
    return AdminSignItem(
      id: word.id,
      label: word.key,
      title: word.title,
      imageAsset: word.imageAsset,
      imageUrl: word.imageUrl,
      videoAsset: word.videoAsset,
      videoUrl: word.videoUrl,
      frontVideoUrl: word.frontVideoUrl,
      leftVideoUrl: word.leftVideoUrl,
      rightVideoUrl: word.rightVideoUrl,
      category: word.category,
      description: word.description,
      sortOrder: word.sortOrder,
      isActive: word.isActive,
    );
  }
}

String _messageFor(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return error.message ?? 'Request failed.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}
