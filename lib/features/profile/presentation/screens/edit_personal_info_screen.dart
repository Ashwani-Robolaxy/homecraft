import 'dart:io';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/services/google_places_service.dart';
import '../../../../core/storage/session_storage.dart';
import '../../../../core/widgets/service_area_search_field.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../auth/domain/models/provider_profile.dart';
import '../../../auth/domain/models/service_area_location.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../projects/domain/models/project_category.dart';
import '../../../projects/presentation/providers/project_provider.dart';

class EditPersonalInfoScreen extends ConsumerStatefulWidget {
  const EditPersonalInfoScreen({super.key});

  @override
  ConsumerState<EditPersonalInfoScreen> createState() =>
      _EditPersonalInfoScreenState();
}

class _EditPersonalInfoScreenState extends ConsumerState<EditPersonalInfoScreen> {
  final _userNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _contactMailController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _siretController = TextEditingController();
  final _websiteController = TextEditingController();
  final _socialInstagramController = TextEditingController();
  final _socialFacebookController = TextEditingController();
  final _socialTwitterController = TextEditingController();
  final _socialLinkedinController = TextEditingController();
  List<ServiceAreaLocation> _serviceAreas = [];
  final List<String> _uploadedProjects = [];
  final List<String> _uploadedCerts = [];
  String? _selectedSpecialty;
  int? _selectedCategoryId;
  bool _specialtyLocked = false;
  bool _siretLocked = false;
  List<ProjectCategory> _specialties = const [];
  bool _loadingSpecialties = true;
  bool _dataLoaded = false;
  bool _saving = false;
  bool _pickingKbis = false;
  String? _kbisFile;
  /// Local path for a KBIS file picked in this session (preview before/after upload).
  String? _kbisLocalPickPath;
  String? _pendingPhotoPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSpecialties());
  }

  Future<void> _loadSpecialties() async {
    try {
      final categories = await ref.read(projectRepositoryProvider).getCategories();
      if (!mounted) return;
      setState(() {
        _specialties = categories;
        if ((_selectedSpecialty == null || _selectedSpecialty!.trim().isEmpty) &&
            _selectedCategoryId != null &&
            _selectedCategoryId! > 0) {
          final matchedById = categories.cast<ProjectCategory?>().firstWhere(
            (c) => c?.id == _selectedCategoryId,
            orElse: () => null,
          );
          _selectedSpecialty = matchedById?.name;
        }
        if ((_selectedCategoryId == null || _selectedCategoryId! <= 0) &&
            _selectedSpecialty != null &&
            _selectedSpecialty!.trim().isNotEmpty) {
          final matched = categories.cast<ProjectCategory?>().firstWhere(
            (c) => c?.name == _selectedSpecialty,
            orElse: () => null,
          );
          _selectedCategoryId = matched?.id;
        }
      });
    } catch (_) {
      if (!mounted) return;
      AppToast.error('provider.profile.loading_categories_error'.tr());
    } finally {
      if (mounted) setState(() => _loadingSpecialties = false);
    }
  }

  @override
  void dispose() {
    _userNameController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    _companyNameController.dispose();
    _contactMailController.dispose();
    _companyAddressController.dispose();
    _postalCodeController.dispose();
    _siretController.dispose();
    _websiteController.dispose();
    _socialInstagramController.dispose();
    _socialFacebookController.dispose();
    _socialTwitterController.dispose();
    _socialLinkedinController.dispose();
    super.dispose();
  }

  void _loadUserData() {
    if (_dataLoaded) return;
    _dataLoaded = true;
    final user = ref.read(authStateNotifierProvider).currentUser;
    if (user != null) {
      _userNameController.text = user.displayName;
      _phoneController.text = user.phone ?? '';
      _contactMailController.text = user.email;
      final p = user.providerProfile;
      if (p != null) {
        _descriptionController.text = p.description ?? '';
        _selectedSpecialty = p.specialty;
        _selectedCategoryId = p.categoryId;
        _companyNameController.text = p.companyName ?? '';
        _contactMailController.text = p.contactMail?.isNotEmpty == true
            ? p.contactMail!
            : user.email;
        _companyAddressController.text = p.companyAddress ?? '';
        _postalCodeController.text = p.postalCode ?? '';
        _siretController.text = p.siret ?? '';
        _specialtyLocked = (p.specialty?.trim().isNotEmpty == true) ||
            (p.categoryId != null && p.categoryId! > 0);
        final siretTrim = (p.siret ?? '').trim();
        _siretLocked = siretTrim.isNotEmpty && siretTrim != '-';
        _serviceAreas = List.from(p.serviceAreas);
        _websiteController.text = p.website ?? '';
        _socialInstagramController.text = p.socialInstagram ?? '';
        _socialFacebookController.text = p.socialFacebook ?? '';
        _socialTwitterController.text = p.socialTwitter ?? '';
        _socialLinkedinController.text = p.socialLinkedin ?? '';
        _uploadedProjects
          ..clear()
          ..addAll(p.projectUploads);
        _uploadedCerts
          ..clear()
          ..addAll(p.certificateUploads);
        _kbisFile = p.kbisExtractUrl;
        _kbisLocalPickPath = null;
      }
    }
  }

  static String _displayFileLabel(String f) =>
      Uri.tryParse(f)?.pathSegments.lastOrNull ?? f.split('/').last;

  static bool _looksLikeImage(String pathOrUrl) {
    final lower = pathOrUrl.split('?').first.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  Future<void> _openKbisEntry() async {
    final v = _kbisFile;
    if (v == null || v.isEmpty) return;
    final label = _displayFileLabel(v);
    if (_kbisLocalPickPath != null && _kbisLocalPickPath!.isNotEmpty) {
      final file = File(_kbisLocalPickPath!);
      if (await file.exists()) {
        if (!mounted) return;
        await _previewDocument(source: _kbisLocalPickPath!, title: label, isFile: true);
        return;
      }
    }
    if (v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('/')) {
      if (!mounted) return;
      await _previewDocument(source: v, title: label, isFile: false);
      return;
    }
    if (await File(v).exists()) {
      if (!mounted) return;
      await _previewDocument(source: v, title: label, isFile: true);
      return;
    }
    if (mounted) {
      AppToast.info('provider.profile.preview_unavailable'.tr());
    }
  }

  Future<Uint8List> _fetchDocumentBytesWithSession(String urlOrPath) async {
    final token = await SessionStorage().getToken();
    final effectiveToken = _shouldAttachAuthForBinaryUrl(urlOrPath) ? token : null;
    return ApiClient().getBytes(urlOrPath, token: effectiveToken);
  }

  bool _shouldAttachAuthForBinaryUrl(String urlOrPath) {
    final raw = urlOrPath.trim();
    final uri = Uri.tryParse(raw);
    if (uri == null) return true;
    final isAbsolute = uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    if (!isAbsolute) return true;
    final apiHost = Uri.parse(ApiConfig.baseUrl).host.toLowerCase();
    return uri.host.toLowerCase() == apiHost;
  }

  Future<void> _previewDocument({
    required String source,
    required String title,
    required bool isFile,
  }) async {
    final showImage = _looksLikeImage(title) || _looksLikeImage(source);
    if (showImage) {
      if (!mounted) return;
      final future = isFile
          ? File(source).readAsBytes()
          : _fetchDocumentBytesWithSession(source);
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black87,
        builder: (ctx) {
          final h = MediaQuery.sizeOf(ctx).height * 0.72;
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
            backgroundColor: Colors.black,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 15),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: h,
                  width: double.maxFinite,
                  child: FutureBuilder<Uint8List>(
                    future: future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white70,
                            ),
                          ),
                        );
                      }
                      if (snapshot.hasError || snapshot.data == null) {
                        final resolved = ApiClient.resolveBinaryUri(source);
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'provider.profile.load_image_error'.tr(),
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 15,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                if (!isFile) ...[
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () async {
                                      try {
                                        if (await canLaunchUrl(resolved)) {
                                          await launchUrl(
                                            resolved,
                                            mode: LaunchMode.externalApplication,
                                          );
                                        }
                                      } catch (_) {}
                                    },
                                    child: Text(
                                      'provider.profile.open_externally'.tr(),
                                      style: GoogleFonts.outfit(
                                        color: AppColors.primaryRed,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }
                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4,
                        child: Image.memory(
                          snapshot.data!,
                          fit: BoxFit.contain,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
      return;
    }
    if (!isFile) {
      final uri = Uri.tryParse(source);
      if (uri != null) {
        try {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (!ok && mounted) {
            AppToast.error('provider.profile.open_link_error'.tr());
          }
        } catch (_) {
          if (mounted) AppToast.error('provider.profile.open_link_error'.tr());
        }
      }
      return;
    }
    if (mounted) {
      AppToast.info('provider.profile.open_file_manager_info'.tr());
    }
  }

  Future<void> _saveProfile() async {
    final displayName = _userNameController.text.trim();
    if (displayName.isEmpty) {
      if (mounted) {
        AppToast.error('auth.validation.username_required'.tr());
      }
      return;
    }
    if (!_serviceAreas.any((e) => e.isValidForApi)) {
      AppToast.error(
        'provider.profile.toast_add_area'.tr(),
      );
      return;
    }
    if (!_specialtyLocked) {
      if (_selectedSpecialty == null || _selectedSpecialty!.trim().isEmpty) {
        AppToast.error('provider.profile.toast_choose_specialty'.tr());
        return;
      }
    }
    if (!_siretLocked) {
      final siretTrim = _siretController.text.trim();
      if (siretTrim.isEmpty || siretTrim == '-') {
        AppToast.error('provider.profile.toast_enter_siret'.tr());
        return;
      }
    }
    var resolvedCategoryId = _selectedCategoryId;
    if ((resolvedCategoryId == null || resolvedCategoryId <= 0) &&
        _selectedSpecialty != null &&
        _selectedSpecialty!.trim().isNotEmpty) {
      resolvedCategoryId = await _resolveCategoryIdForSpecialty(_selectedSpecialty!);
    }
    setState(() => _saving = true);
    final profile = ProviderProfile(
      displayName: displayName,
      phone: _phoneController.text.trim(),
      address: _companyAddressController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      specialty: _selectedSpecialty,
      categoryId: resolvedCategoryId,
      companyName: _companyNameController.text.trim().isEmpty
          ? null
          : _companyNameController.text.trim(),
      contactMail: _contactMailController.text.trim().isEmpty
          ? null
          : _contactMailController.text.trim(),
      companyAddress: _companyAddressController.text.trim().isEmpty
          ? null
          : _companyAddressController.text.trim(),
      postalCode: _postalCodeController.text.trim().isEmpty
          ? null
          : _postalCodeController.text.trim(),
      siret: _siretController.text.trim().isEmpty
          ? null
          : _siretController.text.trim(),
      serviceAreas: _serviceAreas,
      website: _websiteController.text.trim().isEmpty
          ? null
          : _websiteController.text.trim(),
      socialInstagram: _socialInstagramController.text.trim().isEmpty
          ? null
          : _socialInstagramController.text.trim(),
      socialFacebook: _socialFacebookController.text.trim().isEmpty
          ? null
          : _socialFacebookController.text.trim(),
      socialTwitter: _socialTwitterController.text.trim().isEmpty
          ? null
          : _socialTwitterController.text.trim(),
      socialLinkedin: _socialLinkedinController.text.trim().isEmpty
          ? null
          : _socialLinkedinController.text.trim(),
      kbisExtractUrl: _kbisFile,
      projectUploads: _uploadedProjects,
      certificateUploads: _uploadedCerts,
    );
    final result = await ref
        .read(authRepositoryProvider)
        .updateProviderProfile(profile);
    if (!mounted) return;
    if (result.errorMessage != null) {
      setState(() => _saving = false);
      final msg = result.errorMessage!;
      _showSystematicError(msg.startsWith('auth.') ? msg.tr() : msg);
      return;
    }

    // Geocode and update primary map pin with professional company address
    final companyAddr = _companyAddressController.text.trim();
    if (companyAddr.isNotEmpty) {
      try {
        final resolved = await GooglePlacesService.geocodeWithGoogleGeocodingApi(companyAddr);
        if (resolved != null && resolved.isValidForApi) {
          final token = await SessionStorage().getToken();
          if (token != null && token.isNotEmpty) {
            await ApiClient().put(
              '/professionals/location',
              body: {
                'latitude': resolved.latitude,
                'longitude': resolved.longitude,
              },
              token: token,
            );
          }
        }
      } catch (e) {
        debugPrint('[EditPersonalInfo] Failed to update map pin location: $e');
      }
    }

    if (_pendingPhotoPath != null) {
      final photoResult = await ref
          .read(authRepositoryProvider)
          .updateProviderProfilePhoto(_pendingPhotoPath!);
      if (!mounted) return;
      if (photoResult.errorMessage != null) {
        setState(() => _saving = false);
        final msg = photoResult.errorMessage!;
        _showSystematicError(msg.startsWith('auth.') ? msg.tr() : msg);
        return;
      }
      _pendingPhotoPath = null;
      await SessionStorage().clearLocalProfilePhotoPath();
    }

    setState(() => _saving = false);
    await ref.read(authStateNotifierProvider).refresh();
    if (!mounted) return;
    ref.read(profileRefreshTriggerProvider.notifier).trigger();
    AppToast.success('provider.profile.toast_profile_updated'.tr());
    ref.read(providerTabIndexProvider.notifier).setIndex(3);
    context.go('/provider-home');
  }

  Future<void> _pickProviderPhoto() async {
    if (_saving) return;
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (!mounted) return;
      if (picked == null || picked.files.isEmpty) return;
      final path = picked.files.single.path;
      if (path == null || path.isEmpty) {
        AppToast.error('provider.profile.read_image_error'.tr());
        return;
      }

      setState(() => _pendingPhotoPath = path);
    } catch (e) {
      debugPrint('[EditPersonalInfo] Error picking photo: $e');
    }
  }

  Future<int?> _resolveCategoryIdForSpecialty(String specialty) async {
    try {
      final categories = await ref.read(projectRepositoryProvider).getCategories();
      final normalized = specialty.trim().toLowerCase();
      for (final category in categories) {
        if (category.name.trim().toLowerCase() == normalized) {
          return category.id;
        }
      }
    } catch (_) {}
    return null;
  }

  void _showSystematicError(String message) {
    final rawLines = message
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final lines = <String>[];
    for (var l in rawLines) {
      var clean = l;
      if (clean.startsWith('- ') || clean.startsWith('* ')) {
        clean = clean.substring(2).trim();
      }
      final lower = clean.toLowerCase();
      if (lower == 'validation failed' ||
          lower == 'validation failed.' ||
          lower == 'validation failed:' ||
          lower == 'validation error' ||
          lower == 'validation error:' ||
          lower == 'error: validation failed') {
        continue;
      }
      if (clean.isNotEmpty) {
        lines.add(AppToast.localizeBackendMessage(clean, context));
      }
    }

    if (lines.isEmpty) return;
    if (lines.length == 1) {
      AppToast.error(lines.first);
      return;
    }
    showDialog<void>(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppColors.primaryRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.alertTriangle,
                color: AppColors.primaryRed,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'provider.profile.systematic_error_title'.tr(),
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: lines
                  .map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '- ',
                            style: TextStyle(
                              color: AppColors.textMain,
                              fontSize: 17,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              l,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                height: 1.3,
                                color: AppColors.textMain,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'OK',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _loadUserData();
    final user = ref.watch(authStateNotifierProvider).currentUser;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: CommonAppBar(
        title: 'provider.profile.edit_personal_info'.tr(),
        showNotification: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: _buildProfilePictureEditor(user)),
            const SizedBox(height: 16),
            _sectionTitle('provider.profile.personal_info_section'.tr()),
            const SizedBox(height: 12),
            _input(
              controller: _userNameController,
              hint: 'provider.profile.username_hint'.tr(),
              icon: LucideIcons.user,
            ),
            const SizedBox(height: 12),
            _input(
              controller: _phoneController,
              hint: 'provider.profile.phone_hint'.tr(),
              icon: LucideIcons.phone,
            ),
            const SizedBox(height: 12),
            Text(
              'provider.profile.description_label'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'provider.profile.description_hint'.tr(),
                hintStyle: GoogleFonts.outfit(
                  color: Colors.black38,
                  fontSize: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.borderLight),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('provider.profile.choose_specialty'.tr()),
            const SizedBox(height: 8),
            if (_specialtyLocked)
              _readonlyBox(
                value: _selectedSpecialty?.trim().isNotEmpty == true
                    ? _selectedSpecialty!
                    : 'provider.profile.specialty_not_set'.tr(),
              )
            else
              _buildSpecialtyDropdown(),
            const SizedBox(height: 24),
            _sectionTitle('provider.profile.company_info_section'.tr()),
            const SizedBox(height: 12),
            _labeledInput(
              label: 'provider.profile.company_name'.tr(),
              controller: _companyNameController,
            ),
            const SizedBox(height: 12),
            _labeledInput(
              label: 'provider.profile.contact_mail'.tr(),
              controller: _contactMailController,
              readOnly: true,
            ),
            const SizedBox(height: 12),
            _input(
              controller: _companyAddressController,
              hint: 'provider.profile.address_hint'.tr(),
              icon: LucideIcons.mapPin,
            ),
            const SizedBox(height: 12),
            _labeledInput(
              label: 'provider.profile.postal_code'.tr(),
              controller: _postalCodeController,
            ),
            const SizedBox(height: 12),
            _labeledInput(
              label: 'provider.profile.siret_number_label'.tr(),
              controller: _siretController,
              readOnly: _siretLocked,
            ),
            const SizedBox(height: 12),
            Text(
              'provider.profile.upload_kbis'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textMain,
              ),
            ),
            if (_kbisFile != null && _kbisFile!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _openKbisEntry,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                          child: Row(
                            children: [
                              const Icon(LucideIcons.fileText, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _displayFileLabel(_kbisFile!),
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    color: AppColors.primaryRed,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.primaryRed.withValues(alpha: 0.5),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        LucideIcons.trash2,
                        color: AppColors.primaryRed,
                        size: 20,
                      ),
                      onPressed: () => setState(() {
                        _kbisFile = null;
                        _kbisLocalPickPath = null;
                      }),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            _uploadButton(
              isLoading: _pickingKbis,
              onPressed: _pickingKbis ? null : () async {
                setState(() => _pickingKbis = true);
                try {
                  final result = await FilePicker.platform.pickFiles(
                    allowMultiple: false,
                  );
                  if (!mounted) return;
                  if (result == null || result.files.isEmpty) return;
                  final pf = result.files.first;
                  final path = pf.path;
                  if (path == null || path.isEmpty) {
                    AppToast.error('provider.profile.toast_file_error'.tr());
                    return;
                  }
                  setState(() {
                    _kbisFile = path;
                    _kbisLocalPickPath = path;
                  });
                } finally {
                  if (mounted) setState(() => _pickingKbis = false);
                }
              },
            ),
            const SizedBox(height: 24),
            _sectionTitle('provider.profile.services_area'.tr()),
            const SizedBox(height: 8),
            Text(
              'provider.profile.services_area'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _serviceAreas.map((area) {
                return Chip(
                  label: Text(
                    area.displayLabel,
                    style: GoogleFonts.outfit(fontSize: 12),
                  ),
                  deleteIcon: const Icon(LucideIcons.x, size: 14),
                  onDeleted: () => setState(() {
                    _serviceAreas.removeWhere((x) => identical(x, area));
                  }),
                  backgroundColor: Colors.grey[200],
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            ServiceAreaSearchBlock(
              onAreaAdded: (loc) {
                if (!loc.isValidForApi) return;
                if (_serviceAreas.any(
                  (e) => e.isValidForApi && e.isSameLocation(loc),
                )) {
                  AppToast.info('provider.profile.toast_area_exists'.tr());
                  return;
                }
                setState(() => _serviceAreas = [..._serviceAreas, loc]);
              },
            ),
            const SizedBox(height: 16),
            Text(
              'provider.profile.website_url'.tr(),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textMain,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _websiteController,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(
                        'provider.profile.save_change'.tr(),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureEditor(user) {
    final photo = user?.profilePhotoUrl?.toString().trim();
    final hasRemote = photo != null && photo.isNotEmpty;
    final hasLocal = _pendingPhotoPath != null && _pendingPhotoPath!.isNotEmpty;

    final avatar = hasLocal
        ? ClipOval(
            child: Image.file(
              File(_pendingPhotoPath!),
              width: 112,
              height: 112,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const CircleAvatar(
                radius: 56,
                backgroundImage: AssetImage(AppAssets.profilePlaceholder),
              ),
            ),
          )
        : hasRemote
            ? ClipOval(
                child: Image.network(
                  photo,
                  width: 112,
                  height: 112,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const CircleAvatar(
                    radius: 56,
                    backgroundImage: AssetImage(AppAssets.profilePlaceholder),
                  ),
                ),
              )
            : const CircleAvatar(
                radius: 56,
                backgroundImage: AssetImage(AppAssets.profilePlaceholder),
              );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primaryRed, width: 2),
          ),
          child: avatar,
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: GestureDetector(
            onTap: _saving ? null : _pickProviderPhoto,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: const Icon(LucideIcons.pencil, size: 18, color: AppColors.textMain),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.outfit(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textMain,
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppColors.primaryRed),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _labeledInput({
    required String label,
    required TextEditingController controller,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textMain,
          ),
        ),
        const SizedBox(height: 6),
        if (readOnly)
          InputDecorator(
            decoration: InputDecoration(
              fillColor: Colors.grey.shade100,
              filled: true,
              suffixIcon: const Icon(
                LucideIcons.lock,
                size: 18,
                color: AppColors.textSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
            child: Text(
              controller.text.trim().isEmpty ? '-' : controller.text,
              style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain),
            ),
          )
        else
          TextField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.borderLight),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSpecialtyDropdown() {
    final items = [..._specialties];
    if (_selectedSpecialty != null &&
        _selectedSpecialty!.trim().isNotEmpty &&
        !items.any((e) => e.name == _selectedSpecialty)) {
      items.insert(
        0,
        ProjectCategory(
          id: _selectedCategoryId ?? -1,
          name: _selectedSpecialty!,
          slug: _selectedSpecialty!.toLowerCase().replaceAll(' ', '-'),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSpecialty?.trim().isNotEmpty == true
              ? _selectedSpecialty
              : null,
          hint: Text(
            _loadingSpecialties ? 'provider.profile.loading_categories'.tr() : 'provider.profile.dropdown_select'.tr(),
            style: GoogleFonts.outfit(color: Colors.black38, fontSize: 14),
          ),
          isExpanded: true,
          icon: const Icon(
            LucideIcons.chevronDown,
            size: 20,
            color: Colors.black45,
          ),
          items: items.map((specialty) {
            return DropdownMenuItem<String>(
              value: specialty.name,
              child: Row(
                children: [
                  _buildCategoryVisual(specialty, size: 20),
                  const SizedBox(width: 12),
                  Text(specialty.name, style: GoogleFonts.outfit(fontSize: 14)),
                ],
              ),
            );
          }).toList(),
          onChanged: _loadingSpecialties
              ? null
              : (value) => setState(() {
                    _selectedSpecialty = value;
                    final selected = _specialties.cast<ProjectCategory?>().firstWhere(
                          (c) => c?.name == value,
                          orElse: () => null,
                        );
                    _selectedCategoryId = selected?.id;
                  }),
        ),
      ),
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
          errorBuilder: (_, __, ___) => Icon(
            _categoryIcon(category),
            color: AppColors.primaryRed,
            size: size,
          ),
        ),
      );
    }
    return Icon(
      _categoryIcon(category),
      color: AppColors.primaryRed,
      size: size,
    );
  }

  IconData _categoryIcon(ProjectCategory category) {
    final key = '${category.slug} ${category.name}'.toLowerCase();
    if (key.contains('plumb')) return LucideIcons.wrench;
    if (key.contains('paint')) return LucideIcons.palette;
    if (key.contains('tile')) return LucideIcons.layoutGrid;
    if (key.contains('kitchen')) return LucideIcons.utensilsCrossed;
    if (key.contains('pool') || key.contains('pisc')) return LucideIcons.waves;
    if (key.contains('exterior') || key.contains('architect')) {
      return LucideIcons.home;
    }
    if (key.contains('carpent') || key.contains('wood')) {
      return LucideIcons.hammer;
    }
    if (key.contains('clean')) return LucideIcons.sparkles;
    if (key.contains('electric')) return LucideIcons.zap;
    return LucideIcons.briefcase;
  }

  Widget _readonlyBox({required String value}) {
    return InputDecorator(
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.grey.shade100,
        suffixIcon: const Icon(
          LucideIcons.lock,
          size: 18,
          color: AppColors.textSecondary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      child: Text(
        value,
        style: GoogleFonts.outfit(fontSize: 14, color: AppColors.textMain),
      ),
    );
  }

  Widget _uploadButton({required VoidCallback? onPressed, bool isLoading = false}) {
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.primaryRed),
        backgroundColor: AppColors.primaryRed.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primaryRed,
              ),
            )
          else
            const Icon(LucideIcons.upload, size: 18, color: AppColors.primaryRed),
          const SizedBox(width: 8),
          Text(
            isLoading ? 'provider.profile.upload_loading'.tr() : 'provider.profile.upload_button'.tr(),
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryRed,
            ),
          ),
        ],
      ),
    );
  }}
