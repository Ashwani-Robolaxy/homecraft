import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../auth/presentation/widgets/custom_text_field.dart';
import '../../domain/models/project_category.dart';
import '../../domain/repositories/project_repository.dart';
import '../providers/project_provider.dart';

import '../../../../core/widgets/common_app_bar.dart';

class CreateProjectScreen extends ConsumerStatefulWidget {
  const CreateProjectScreen({super.key});

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
  bool _isSubmitting = false;
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ref.read(projectRepositoryProvider).getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
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
      appBar: CommonAppBar(title: tr('projects.form.title')),
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
            CustomTextField(hintText: tr('projects.form.location_hint'), controller: _locationController, prefixIcon: LucideIcons.mapPin),
            const SizedBox(height: 20),

            _buildLabel(tr('projects.form.date_label')),
            CustomTextField(hintText: tr('projects.form.date_hint'), controller: _dateController, suffixIcon: LucideIcons.calendar, readOnly: true, onTap: () => _selectDate(context)),
            const SizedBox(height: 20),

            _buildLabel(tr('projects.form.budget_label')),
            CustomTextField(hintText: '0.00', controller: _budgetController, prefixText: '€', keyboardType: TextInputType.number),
            const SizedBox(height: 40),

            PrimaryGradientButton(
              text: tr('projects.form.submit'),
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
            Text(
              _isLoadingCategories ? 'Loading categories...' : (categoryName ?? tr('projects.form.category_hint')),
              style: TextStyle(color: categoryName != null ? AppColors.textMain : AppColors.textSecondary, fontSize: 14),
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
                    final iconOptions = [
                      LucideIcons.hammer,
                      LucideIcons.paintbrush,
                      LucideIcons.layoutGrid,
                      LucideIcons.chefHat,
                      LucideIcons.waves,
                      LucideIcons.compass,
                    ];
                    final icon = iconOptions[index % iconOptions.length];

                    return ListTile(
                      onTap: () {
                        setState(() => _selectedCategory = cat);
                        Navigator.pop(context);
                      },
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.primaryRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, size: 20, color: AppColors.primaryRed),
                      ),
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
    return InkWell(
      onTap: _pickAttachment,
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
            const Icon(LucideIcons.uploadCloud, color: AppColors.primaryRed, size: 20),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                _attachmentName ?? tr('projects.form.attachment_button'),
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
    final file = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'zip'],
    );
    if (!mounted || file == null || file.files.isEmpty) return;
    setState(() {
      _attachmentPath = file.files.first.path;
      _attachmentName = file.files.first.name;
    });
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
        _dateController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();
    final budget = _budgetController.text.trim();
    if (title.isEmpty || description.isEmpty || location.isEmpty || _dateController.text.trim().isEmpty || _selectedCategory == null) {
      AppToast.error('Please fill all required fields.');
      return;
    }

    String desiredDate;
    try {
      final parsed = DateFormat('MM/dd/yyyy').parseStrict(_dateController.text.trim());
      desiredDate = DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {
      AppToast.error('Please choose a valid desired date.');
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await ref.read(projectRepositoryProvider).createProject(
          CreateProjectInput(
            title: title,
            description: description,
            categoryId: _selectedCategory!.id,
            location: location,
            desiredDate: desiredDate,
            budget: budget.isEmpty ? null : budget,
            attachmentPath: _attachmentPath,
          ),
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result.errorMessage != null) {
      AppToast.error(result.errorMessage!);
      return;
    }
    AppToast.success('Project created successfully');
    context.pop(true);
  }
}
