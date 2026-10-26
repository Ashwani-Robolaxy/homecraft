import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/services/google_places_service.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/app_toast.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/booking_remote_datasource.dart';
import '../../../professionals/domain/models/calendar_day_status.dart';
import '../../../professionals/domain/models/professional_month_availability.dart';
import '../widgets/booking_calendar_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Args
// ─────────────────────────────────────────────────────────────────────────────

class CreateBookingArgs {
  const CreateBookingArgs({required this.professionalId, required this.professionalName, this.professionalPhoto, this.professionalProfession});

  final String professionalId;
  final String professionalName;
  final String? professionalPhoto;
  final String? professionalProfession;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class CreateBookingScreen extends ConsumerStatefulWidget {
  const CreateBookingScreen({super.key, required this.args});
  final CreateBookingArgs args;

  @override
  ConsumerState<CreateBookingScreen> createState() => _CreateBookingScreenState();
}

class _CreateBookingScreenState extends ConsumerState<CreateBookingScreen> {
  final _notesCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _ds = BookingRemoteDatasource();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  AvailabilityTimeSlot? _selectedSlot;
  final Map<DateTime, ProfessionalDayAvailability> _availabilityByDate = {};
  bool _availabilityLoading = true;
  String? _availabilityError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill location from user profile if available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(authStateNotifierProvider).currentUser;
      if (user != null && user.city != null && user.city!.isNotEmpty) {
        setState(() {
          _locationCtrl.text = user.city!;
        });
      }
    });
    _loadAvailabilityWindow();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _locationCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _monthKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

  Future<void> _loadAvailabilityWindow() async {
    setState(() {
      _availabilityLoading = true;
      _availabilityError = null;
    });
    try {
      final now = DateTime.now();
      final months = List.generate(
        6,
        (i) => DateTime(now.year, now.month + i, 1),
      );
      final responses = await Future.wait(
        months.map(
          (m) => _ds.fetchProfessionalAvailabilityMonth(
            professionalId: widget.args.professionalId,
            monthYm: _monthKey(m),
          ),
        ),
      );
      _availabilityByDate.clear();
      for (final month in responses) {
        for (final d in month.days) {
          _availabilityByDate[_dateOnly(d.date)] = d;
        }
      }
      if (!mounted) return;
      setState(() => _availabilityLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _availabilityLoading = false;
        _availabilityError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  bool _isSelectableDate(DateTime d) {
    final day = _availabilityByDate[_dateOnly(d)];
    if (day == null) return false;
    return day.status == CalendarDayStatus.available ||
        day.status == CalendarDayStatus.hourAvailable;
  }

  ProfessionalDayAvailability? _selectedDayAvailability() {
    final d = _selectedDate;
    if (d == null) return null;
    return _availabilityByDate[_dateOnly(d)];
  }

  // ── Date picker ───────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    if (_availabilityLoading) {
      AppToast.info('Loading availability...');
      return;
    }
    if (_availabilityError != null) {
      AppToast.error('Could not load availability. Pull to retry.');
      return;
    }
    final now = DateTime.now();
    final first = _dateOnly(now);
    final lastDate = now.add(const Duration(days: 180));
    
    DateTime? initialCandidate;
    if (_selectedDate != null && !_selectedDate!.isBefore(first) && _isSelectableDate(_selectedDate!)) {
      initialCandidate = _selectedDate!;
    } else {
      for (var d = first; !d.isAfter(lastDate); d = d.add(const Duration(days: 1))) {
        if (_isSelectableDate(d)) {
          initialCandidate = d;
          break;
        }
      }
    }

    if (initialCandidate == null) {
      AppToast.info('No available dates found for this professional.');
      return;
    }

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) => BookingCalendarDialog(
        initialDate: initialCandidate!,
        firstDate: first,
        lastDate: lastDate,
        availabilityByDate: _availabilityByDate,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _selectedSlot = null;
        _startTime = null;
        _endTime = null;
      });
    }
  }

  // ── Time pickers ──────────────────────────────────────────────────────────

  Future<void> _pickStart() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0), builder: (ctx, child) => _timeTheme(ctx, child));
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? (_startTime?.replacing(hour: _startTime!.hour + 1) ?? const TimeOfDay(hour: 10, minute: 0)),
      builder: (ctx, child) => _timeTheme(ctx, child),
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  Widget _timeTheme(BuildContext ctx, Widget? child) => MediaQuery(
    data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
    child: Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: const ColorScheme.light(primary: AppColors.primaryRed, onPrimary: Colors.white),
      ),
      child: child!,
    ),
  );

  String _fmtTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_selectedDate == null) {
      AppToast.error('booking.toast_select_date'.tr());
      return;
    }
    final location = _locationCtrl.text.trim();
    if (location.isEmpty) {
      AppToast.error('booking.toast_provide_location'.tr());
      return;
    }
    final day = _selectedDayAvailability();
    if (day == null || !_isSelectableDate(_selectedDate!)) {
      AppToast.error('booking.toast_date_unavailable'.tr());
      return;
    }
    if (day.slots.isNotEmpty && _selectedSlot == null) {
      AppToast.error('booking.toast_select_slot'.tr());
      return;
    }
    if (day.slots.isEmpty) {
      if (_startTime != null && _endTime == null) {
        AppToast.error('booking.toast_select_end_time'.tr());
        return;
      }
      if (_startTime == null && _endTime != null) {
        AppToast.error('booking.toast_select_start_time'.tr());
        return;
      }
      if (_startTime != null && _endTime != null) {
        final startMin = _startTime!.hour * 60 + _startTime!.minute;
        final endMin = _endTime!.hour * 60 + _endTime!.minute;
        if (startMin >= endMin) {
          AppToast.error('booking.toast_end_after_start'.tr());
          return;
        }
      }
    }

    setState(() => _saving = true);
    try {
      final slotStart = _selectedSlot?.startTime ??
          (_startTime != null ? _fmtTime(_startTime!) : null);
      final slotEnd = _selectedSlot?.endTime ??
          (_endTime != null ? _fmtTime(_endTime!) : null);
      await _ds.createBooking(
        professionalId: widget.args.professionalId,
        customerLocation: location,
        date: DateFormat('yyyy-MM-dd').format(_selectedDate!),
        slotStart: slotStart,
        slotEnd: slotEnd,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        budget: _budgetCtrl.text.trim().isEmpty ? null : _budgetCtrl.text.trim(),
      );
      if (!mounted) return;
      AppToast.success('booking.toast_request_sent'.tr());
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    return Scaffold(
      backgroundColor: const Color(0xFFFDF9F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'booking.title'.tr(),
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEEEEEE), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Professional Card
            _ProfessionalCard(args: args),
            const SizedBox(height: 24),

            // Date selector
            _SectionLabel(label: 'booking.select_date'.tr(), icon: LucideIcons.calendarDays),
            const SizedBox(height: 10),
            _SelectTile(
              label: _availabilityLoading
                  ? 'booking.loading_dates'.tr()
                  : _selectedDate != null
                      ? DateFormat('EEE, MMM d, yyyy').format(_selectedDate!)
                      : (_availabilityError != null
                          ? 'Could not load availability'
                          : 'booking.choose_date'.tr()),
              hasValue: _selectedDate != null,
              onTap: _pickDate,
            ),
            if (_availabilityError != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _loadAvailabilityWindow,
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: Text('booking.retry_availability'.tr()),
              ),
            ],
            const SizedBox(height: 20),

            // Location
            _SectionLabel(label: 'booking.your_location'.tr(), icon: LucideIcons.mapPin),
            const SizedBox(height: 10),
            _GooglePlacesField(controller: _locationCtrl, hint: 'booking.location_hint'.tr()),
            const SizedBox(height: 20),

            // Budget
            _SectionLabel(label: 'booking.budget'.tr(), icon: LucideIcons.wallet),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _budgetCtrl,
              hint: 'booking.budget_hint'.tr(),
            ),
            const SizedBox(height: 20),

            // Time slot
            _SectionLabel(label: 'booking.time_slot'.tr(), icon: LucideIcons.clock),
            const SizedBox(height: 10),
            Builder(
              builder: (context) {
                final day = _selectedDayAvailability();
                if (_selectedDate == null) {
                  return _HintBox(
                    text: 'booking.pick_date_hint'.tr(),
                  );
                }
                if (day == null || !_isSelectableDate(_selectedDate!)) {
                  return _HintBox(
                    text: 'booking.day_unavailable'.tr(),
                  );
                }
                if (day.slots.isNotEmpty) {
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: day.slots.map((s) {
                      final selected =
                          _selectedSlot?.startTime == s.startTime &&
                              _selectedSlot?.endTime == s.endTime;
                      final label = '${s.startTime} - ${s.endTime}';
                      return ChoiceChip(
                        selected: selected,
                        label: Text(label),
                        onSelected: (_) => setState(() => _selectedSlot = s),
                        selectedColor:
                            AppColors.primaryRed.withValues(alpha: 0.15),
                        labelStyle: GoogleFonts.outfit(
                          color: selected
                              ? AppColors.primaryRed
                              : AppColors.textMain,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  );
                }
                // Full-day available with no explicit slots: fallback to manual optional times.
                return Row(
                  children: [
                    Expanded(
                      child: _SelectTile(
                        label: _startTime != null ? _fmtTime(_startTime!) : 'booking.start_time'.tr(),
                        hasValue: _startTime != null,
                        onTap: _pickStart,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(LucideIcons.arrowRight,
                        size: 18, color: Colors.black38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SelectTile(
                        label: _endTime != null ? _fmtTime(_endTime!) : 'booking.end_time'.tr(),
                        hasValue: _endTime != null,
                        onTap: _pickEnd,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Notes
            _SectionLabel(label: 'booking.notes'.tr(), icon: LucideIcons.fileText),
            const SizedBox(height: 10),
            _buildTextField(controller: _notesCtrl, hint: 'booking.notes_hint'.tr(), maxLines: 4),
            const SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              child: _saving ? const Center(child: CircularProgressIndicator(color: AppColors.primaryRed)) : PrimaryGradientButton(text: 'booking.send_request'.tr(), height: 52, onPressed: _submit),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'booking.submission_info'.tr(),
                style: GoogleFonts.outfit(fontSize: 12, color: Colors.black38, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(color: Colors.black38, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _ProfessionalCard extends StatelessWidget {
  const _ProfessionalCard({required this.args});
  final CreateBookingArgs args;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: SizedBox(
              width: 56,
              height: 56,
              child: (args.professionalPhoto != null && args.professionalPhoto!.startsWith('http'))
                  ? Image.network(args.professionalPhoto!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatar())
                  : _avatar(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  args.professionalName,
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black),
                ),
                if (args.professionalProfession != null && args.professionalProfession!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(args.professionalProfession!, style: GoogleFonts.outfit(fontSize: 13, color: AppColors.primaryRed)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar() => Image.asset(
        AppAssets.profilePlaceholder,
        fit: BoxFit.cover,
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryRed),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ],
    );
  }
}

class _SelectTile extends StatelessWidget {
  const _SelectTile({required this.label, required this.hasValue, required this.onTap});
  final String label;
  final bool hasValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hasValue ? AppColors.primaryRed : const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(label, style: GoogleFonts.outfit(fontSize: 14, color: hasValue ? Colors.black87 : Colors.black38)),
            ),
            Icon(LucideIcons.chevronDown, size: 16, color: hasValue ? AppColors.primaryRed : Colors.black38),
          ],
        ),
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 13, color: Colors.black54),
      ),
    );
  }
}

class _GooglePlacesField extends StatefulWidget {
  const _GooglePlacesField({required this.controller, this.hint = 'Address'});

  final TextEditingController controller;
  final String hint;

  @override
  State<_GooglePlacesField> createState() => _GooglePlacesFieldState();
}

class _GooglePlacesFieldState extends State<_GooglePlacesField> {
  final _layerLink = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  final String _sessionToken = DateTime.now().millisecondsSinceEpoch.toString();

  Timer? _debounce;
  OverlayEntry? _overlay;
  List<String> _suggestions = const [];
  bool _loading = false;
  bool _suppress = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _removeOverlay();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (_suppress) return;
    _debounce?.cancel();
    final text = widget.controller.text.trim();
    if (text.length < 2) {
      _clearSuggestions();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetch(text));
  }

  Future<void> _fetch(String input) async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/place/autocomplete/json',
        {
          'input': input,
          'types': 'geocode',
          'language': 'fr',
          'components': 'country:fr',
          'sessiontoken': _sessionToken,
          'key': kGoogleMapsPlacesApiKey,
        },
      );
      final res = await http.get(uri);
      if (!mounted) return;
      final map = res.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(res.body) as Map<String, dynamic>;
      final status = (map['status'] ?? '').toString();
      if (status != 'OK' && status != 'ZERO_RESULTS') {
        _clearSuggestions();
        return;
      }
      final predictions = map['predictions'];
      if (predictions is! List) {
        _clearSuggestions();
        return;
      }
      final results = predictions
          .whereType<Map>()
          .map((e) => (e['description'] ?? '').toString())
          .where((d) => d.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _loading = false;
        _suggestions = results;
      });
      _showOverlay();
    } catch (_) {
      if (mounted) _clearSuggestions();
    }
  }

  void _clearSuggestions() {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _suggestions = const [];
    });
    _removeOverlay();
  }

  void _select(String place) {
    _suppress = true;
    widget.controller.text = place;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: place.length),
    );
    _clearSuggestions();
    FocusScope.of(context).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _suppress = false);
  }

  void _showOverlay() {
    if (_suggestions.isEmpty) {
      _removeOverlay();
      return;
    }
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    _overlay = OverlayEntry(builder: (_) => _buildOverlay());
    Overlay.of(context, rootOverlay: true).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Widget _buildOverlay() {
    final box = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    final width = box?.size.width ?? 300;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _clearSuggestions,
          ),
          CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: const Offset(0, 4),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              shadowColor: Colors.black12,
              child: SizedBox(
                width: width,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 44),
                    itemBuilder: (_, i) {
                      final s = _suggestions[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primaryRed.withValues(alpha: 0.09),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.mapPin,
                            size: 14,
                            color: AppColors.primaryRed,
                          ),
                        ),
                        title: Text(
                          s,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _select(s),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        key: _fieldKey,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: TextField(
          controller: widget.controller,
          style: GoogleFonts.outfit(fontSize: 14, color: Colors.black87),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: GoogleFonts.outfit(color: Colors.black38, fontSize: 13),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryRed,
                      ),
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}
