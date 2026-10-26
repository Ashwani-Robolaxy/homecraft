import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/google_places_service.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../auth/domain/models/service_area_location.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../../domain/models/project.dart';
import '../../domain/models/project_category.dart';
import '../../domain/repositories/project_repository.dart';
import '../providers/project_provider.dart';

import '../../../../core/widgets/common_app_bar.dart';

class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key, this.initialProject});

  final Project? initialProject;

  @override
  ConsumerState<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _budgetController = TextEditingController();
  List<ProjectCategory> _categories = const [];
  ProjectCategory? _selectedCategory;
  String? _attachmentPath;
  String? _attachmentName;
  ServiceAreaLocation? _resolvedLocation;
  bool _isSubmitting = false;
  bool _isLoadingCategories = true;
  bool _isPickingPhoto = false;
  late final GooglePlacesService _places = GooglePlacesService(
    sessionToken: DateTime.now().microsecondsSinceEpoch.toString(),
  );
  Timer? _locationDebounce;
  List<PlaceAutocompleteSuggestion> _locationSuggestions = const [];
  bool _isLocationLoading = false;
  bool _isResolvingLocation = false;
  bool _suppressLocationSearch = false;

  bool get _isEditMode => widget.initialProject != null;

  @override
  void initState() {
    super.initState();
    _locationController.addListener(_onLocationTextChanged);
    _applyInitialProjectValues();
    _loadCategories();
  }

  void _onLocationTextChanged() {
    if (_suppressLocationSearch) return;
    if (_resolvedLocation != null) {
      setState(() => _resolvedLocation = null);
    }
    final query = _locationController.text.trim();
    _locationDebounce?.cancel();
    if (query.length < 2) {
      if (_locationSuggestions.isNotEmpty || _isLocationLoading) {
        setState(() {
          _locationSuggestions = const [];
          _isLocationLoading = false;
        });
      }
      return;
    }
    _locationDebounce = Timer(const Duration(milliseconds: 350), () => _fetchLocationSuggestions(query));
  }

  Future<void> _fetchLocationSuggestions(String query) async {
    if (!mounted) return;
    setState(() => _isLocationLoading = true);
    try {
      final suggestions = await _places.autocomplete(query, types: '(cities)');
      if (!mounted) return;
      setState(() {
        _locationSuggestions = suggestions;
        _isLocationLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locationSuggestions = const [];
        _isLocationLoading = false;
      });
    }
  }

  Future<void> _selectLocationSuggestion(PlaceAutocompleteSuggestion suggestion) async {
    setState(() => _isResolvingLocation = true);
    try {
      final loc = await _places.placeDetails(suggestion.placeId);
      if (!mounted) return;
      if (loc == null || !loc.isValidForApi) {
        AppToast.error('Could not load that place. Try another.');
        return;
      }
      final label = (loc.label ?? '').trim().isNotEmpty ? loc.label!.trim() : suggestion.description;
      _suppressLocationSearch = true;
      _locationController.value = TextEditingValue(
        text: label,
        selection: TextSelection.collapsed(offset: label.length),
      );
      setState(() {
        _resolvedLocation = loc;
        _locationSuggestions = const [];
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _suppressLocationSearch = false;
      });
      FocusScope.of(context).unfocus();
    } finally {
      if (mounted) {
        setState(() => _isResolvingLocation = false);
      }
    }
  }

  void _applyInitialProjectValues() {
    final project = widget.initialProject;
    if (project == null) return;
    _titleController.text = project.title;
    _descriptionController.text = project.description;
    final normalizedLocation = _normalizeLocationText(project.location);
    _locationController.value = TextEditingValue(
      text: normalizedLocation,
      selection: TextSelection.collapsed(offset: normalizedLocation.length),
    );
    _dateController.text = _toFormDate(project.date);
    if (project.budgetAmount != null) {
      final amount = project.budgetAmount!;
      _budgetController.text = amount % 1 == 0 ? amount.toInt().toString() : amount.toString();
    }
    if (project.latitude != null && project.longitude != null) {
      _resolvedLocation = ServiceAreaLocation(
        latitude: project.latitude,
        longitude: project.longitude,
        label: project.location,
      );
    }
    if (project.imageUrl != null && project.imageUrl!.isNotEmpty) {
      final uri = Uri.tryParse(project.imageUrl!);
      _attachmentName = uri != null && uri.pathSegments.isNotEmpty
          ? uri.pathSegments.last
          : 'Attachment';
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ref.read(projectRepositoryProvider).getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        if (_isEditMode) {
          final project = widget.initialProject!;
          _selectedCategory = _findCategoryById(categories, project.categoryId);
          _selectedCategory ??= _findCategoryByName(categories, project.serviceType);
        }
      });
    } catch (_) {
      if (!mounted) return;
      AppToast.error('Unable to load categories. Please try again.');
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void dispose() {
    _locationController.removeListener(_onLocationTextChanged);
    _locationDebounce?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _dateController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      appBar: CommonAppBar(title: _isEditMode ? 'Edit Project' : tr('projects.form.title')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(tr('projects.form.project_title_label')),
            CustomTextField(hintText: tr('projects.form.project_title_hint'), controller: _titleController),
            const SizedBox(height: 20),

            _buildLabel(tr('projects.form.category_label')),
            _buildDropdown(),
            const SizedBox(height: 20),

            Row(
              children: [
                _buildLabel(tr('projects.form.description_label')),
                const SizedBox(width: 8),
                const Icon(LucideIcons.alertCircle, size: 16, color: AppColors.primaryRed),
              ],
            ),
            _buildDescriptionField(),
            const SizedBox(height: 20),

            _buildLabel(tr('projects.form.attachment_label')),
            _buildAttachmentButton(),
            const SizedBox(height: 20),

            _buildLabel(tr('projects.form.location_label')),
            CustomTextField(
              controller: _locationController,
              hintText: tr('projects.form.location_hint'),
            ),
            if (_isLocationLoading)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: LinearProgressIndicator(minHeight: 2, color: AppColors.primaryRed),
              ),
            if (_locationSuggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _locationSuggestions.length > 4 ? 4 : _locationSuggestions.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 44),
                  itemBuilder: (context, index) {
                    final s = _locationSuggestions[index];
                    return ListTile(
                      dense: true,
                      leading: const Icon(LucideIcons.mapPin, size: 16, color: AppColors.primaryRed),
                      title: Text(
                        s.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(fontSize: 13, color: AppColors.textMain),
                      ),
                      onTap: _isResolvingLocation ? null : () => _selectLocationSuggestion(s),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),

            _buildLabel(tr('projects.form.date_label')),
            CustomTextField(hintText: tr('projects.form.date_hint'), controller: _dateController, suffixIcon: LucideIcons.calendar, readOnly: true, onTap: () => _selectDate(context)),
            const SizedBox(height: 20),

            _buildLabel(tr('projects.form.budget_label')),
            CustomTextField(hintText: '0.00', controller: _budgetController, prefixText: '€', keyboardType: TextInputType.number),
            const SizedBox(height: 40),

            PrimaryGradientButton(
              text: _isEditMode ? 'Update Project' : tr('projects.form.submit'),
              isLoading: _isSubmitting,
              onPressed: () => _submit(),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textMain),
      ),
    );
  }

  Widget _buildDropdown() {
    final categoryName = _selectedCategory?.name;

    return InkWell(
      onTap: _isLoadingCategories ? null : _showCategoryPicker,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  if (_selectedCategory != null) ...[
                    _buildCategoryVisual(_selectedCategory!, size: 20),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      _isLoadingCategories ? 'Loading categories...' : (categoryName ?? tr('projects.form.category_hint')),
                      style: TextStyle(color: categoryName != null ? AppColors.textMain : AppColors.textSecondary, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronDown, size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker() {
    if (_categories.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
              ),
              Text(
                tr('projects.form.category_label'),
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain),
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final cat = _categories[index];
                    final isSelected = _selectedCategory?.id == cat.id;
                    return ListTile(
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        Navigator.pop(context);
                      },
                      leading: _buildCategoryLeading(cat),
                      title: Text(cat.name, style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: AppColors.textMain)),
                      trailing: isSelected ? const Icon(LucideIcons.check, color: AppColors.primaryRed, size: 20) : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoryVisual(ProjectCategory category, {double size = 20}) {
    final imageUrl = category.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            LucideIcons.layoutGrid,
            size: 20,
            color: AppColors.primaryRed,
          ),
        ),
      );
    }
    return const Icon(LucideIcons.layoutGrid, size: 20, color: AppColors.primaryRed);
  }

  Widget _buildCategoryLeading(ProjectCategory category, {double size = 36}) {
    final imageUrl = category.imageUrl?.trim();
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.primaryRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(LucideIcons.layoutGrid, size: size * 0.5, color: AppColors.primaryRed),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primaryRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(LucideIcons.layoutGrid, size: size * 0.5, color: AppColors.primaryRed),
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: AppColors.textMain),
          decoration: InputDecoration(
            hintText: tr('projects.form.description_hint'),
            hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 4),
        Text('${_descriptionController.text.length}/240 caracteres', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildAttachmentButton() {
    final hasAttachment = _attachmentName != null && _attachmentName!.isNotEmpty;

    if (hasAttachment && !_isPickingPhoto) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            const Icon(LucideIcons.image, color: AppColors.primaryRed, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: _pickAttachment,
                child: Text(
                  _attachmentName!,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                setState(() {
                  _attachmentPath = null;
                  _attachmentName = null;
                });
              },
              icon: const Icon(LucideIcons.x, color: AppColors.textSecondary, size: 18),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _isPickingPhoto ? null : _pickAttachment,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryRed.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isPickingPhoto)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryRed,
                ),
              )
            else
              const Icon(LucideIcons.image, color: AppColors.primaryRed, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _isPickingPhoto
                    ? tr('common.loading')
                    : tr('projects.form.attachment_button'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAttachment() async {
    setState(() => _isPickingPhoto = true);
    try {
      final file = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (!mounted || file == null || file.files.isEmpty) return;
      setState(() {
        _attachmentPath = file.files.first.path;
        _attachmentName = file.files.first.name;
      });
    } finally {
      if (mounted) {
        setState(() => _isPickingPhoto = false);
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primaryRed, onPrimary: Colors.white, onSurface: AppColors.textMain),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryRed,
                textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final budget = _budgetController.text.trim();
    if (title.isEmpty || description.isEmpty || _dateController.text.trim().isEmpty || _selectedCategory == null) {
      AppToast.error('Please fill all required fields.');
      return;
    }
    final locationText = _locationController.text.trim();
    if (locationText.isEmpty) {
      AppToast.error('Please provide a location.');
      return;
    }
    final loc = _resolvedLocation;
    final locLabel = loc?.label?.trim();
    final locationLabel = (locLabel != null && locLabel.isNotEmpty) ? locLabel : locationText;

    String desiredDate;
    try {
      final parsed = DateFormat('dd/MM/yyyy').parseStrict(_dateController.text.trim());
      desiredDate = DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {
      AppToast.error('Please choose a valid desired date.');
      return;
    }

    setState(() => _isSubmitting = true);
    final input = CreateProjectInput(
      title: title,
      description: description,
      categoryId: _selectedCategory!.id,
      location: locationLabel,
      desiredDate: desiredDate,
      budget: budget.isEmpty ? null : budget,
      attachmentPath: _attachmentPath,
      latitude: loc?.isValidForApi == true ? loc!.latitude : null,
      longitude: loc?.isValidForApi == true ? loc!.longitude : null,
    );
    final result = _isEditMode
        ? await ref.read(projectRepositoryProvider).updateProject(widget.initialProject!.id, input)
        : await ref.read(projectRepositoryProvider).createProject(input);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.errorMessage != null) {
      AppToast.error(result.errorMessage!);
      return;
    }
    AppToast.success(_isEditMode ? 'Project updated successfully' : 'Project created successfully');
    context.pop(true);
  }

  String _toFormDate(String dateText) {
    final trimmed = dateText.trim();
    if (trimmed.isEmpty) return '';
    
    // Try to parse dd/MM/yyyy
    final fromSlashDMY = DateFormat('dd/MM/yyyy').tryParse(trimmed);
    if (fromSlashDMY != null) return DateFormat('dd/MM/yyyy').format(fromSlashDMY);
    
    // Try to parse dd-MM-yyyy
    final fromDashDMY = DateFormat('dd-MM-yyyy').tryParse(trimmed);
    if (fromDashDMY != null) return DateFormat('dd/MM/yyyy').format(fromDashDMY);

    // Try to parse MM-dd-yyyy (legacy support)
    final fromDashMDY = DateFormat('MM-dd-yyyy').tryParse(trimmed);
    if (fromDashMDY != null) return DateFormat('dd/MM/yyyy').format(fromDashMDY);

    // Try to parse MM/dd/yyyy (legacy support)
    final fromSlashMDY = DateFormat('MM/dd/yyyy').tryParse(trimmed);
    if (fromSlashMDY != null) return DateFormat('dd/MM/yyyy').format(fromSlashMDY);

    // Try to parse API format yyyy-MM-dd
    final fromApi = DateFormat('yyyy-MM-dd').tryParse(trimmed);
    if (fromApi != null) return DateFormat('dd/MM/yyyy').format(fromApi);

    return trimmed;
  }

  String _normalizeLocationText(String raw) {
    final collapsed = raw
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return collapsed;
  }

  ProjectCategory? _findCategoryById(List<ProjectCategory> categories, int? id) {
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  ProjectCategory? _findCategoryByName(List<ProjectCategory> categories, String? name) {
    final normalized = (name ?? '').trim().toLowerCase();
    if (normalized.isEmpty) return null;
    for (final category in categories) {
      if (category.name.trim().toLowerCase() == normalized) {
        return category;
      }
    }
    return null;
  }
}
