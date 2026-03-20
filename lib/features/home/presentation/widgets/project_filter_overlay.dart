import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';

class ProjectFilterOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onViewMap;

  const ProjectFilterOverlay({
    super.key,
    required this.onClose,
    required this.onViewMap,
  });

  @override
  State<ProjectFilterOverlay> createState() => _ProjectFilterOverlayState();
}

class _ProjectFilterOverlayState extends State<ProjectFilterOverlay> {
  double _distance = 4.0;
  double _budget = 56.0;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: widget.onClose,
        child: Container(
          color: Colors.black.withValues(alpha: 0.3),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {}, // Prevent tap through
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.xCircle, color: Colors.red),
                        onPressed: widget.onClose,
                      ),
                      Text(
                        'Filter',
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 48), // Placeholder for symmetry
                    ],
                  ),
                  const SizedBox(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Kilometres From Me',
                      style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: AppColors.primaryRed,
                      inactiveTrackColor: Colors.black12,
                      thumbColor: Colors.red,
                      overlayColor: Colors.red.withValues(alpha: 0.1),
                      trackHeight: 6,
                    ),
                    child: Slider(
                      value: _distance,
                      min: 0,
                      max: 20,
                      onChanged: (val) => setState(() => _distance = val),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_distance.toInt()} KM',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 30),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Maximum Budget (€)',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8EDED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: AppColors.primaryRed,
                            inactiveTrackColor: Colors.black12,
                            thumbColor: Colors.white,
                            overlayColor: Colors.red.withValues(alpha: 0.1),
                            trackHeight: 8,
                          ),
                          child: Slider(
                            value: _budget,
                            min: 0,
                            max: 5000,
                            onChanged: (val) => setState(() => _budget = val),
                          ),
                        ),
                      ),
                      Positioned(
                        top: -30,
                        left: (_budget / 5000) * (MediaQuery.of(context).size.width * 0.7) + 10,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primaryRed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '\$${_budget.toInt()}',
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: AppColors.primaryRed, size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      '1900 (€)',
                      style: GoogleFonts.outfit(fontSize: 14, color: AppColors.primaryRed),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onViewMap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 0,
                      ),
                      child: Text(
                        'View Map',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
