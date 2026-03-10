import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class FilterDrawer extends StatefulWidget {
  const FilterDrawer({super.key});

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer> {
  double _distance = 4.0;
  final List<bool> _availability = [false, false, false];
  int _selectedRating = -1;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.xCircle, color: AppColors.primaryRed, size: 30),
                  ),
                  Text(
                    tr('filter.title'),
                    style: const TextStyle(fontFamily: 'Outfit', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain),
                  ),
                  const SizedBox(width: 48), // Spacer to balance icons
                ],
              ),
              const SizedBox(height: 30),

              // Distance
              Text(
                tr('filter.distance_label'),
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(activeTrackColor: AppColors.primaryRed, inactiveTrackColor: const Color(0xFFF0E6E6), thumbColor: AppColors.primaryRed, trackHeight: 6),
                child: Slider(value: _distance, min: 0, max: 20, onChanged: (val) => setState(() => _distance = val)),
              ),
              Center(
                child: Column(
                  children: [
                    Text(
                      tr('filter.maximum'),
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF828282)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.textMain),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_distance.toInt()} KM',
                        style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Availability
              Text(
                tr('filter.availability_label'),
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF0E6E6)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(children: [_buildCheckbox(0, tr('filter.today')), _buildCheckbox(1, tr('filter.within_week')), _buildCheckbox(2, tr('filter.next_week'))]),
              ),
              const SizedBox(height: 30),

              // Top Rated
              Text(
                tr('filter.top_rated'),
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFF0E6E6)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(children: [_buildRatingOption(0, 3), _buildRatingOption(1, 4), _buildRatingOption(2, 5)]),
              ),
              const SizedBox(height: 40),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D8000),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    tr('filter.see_results'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    // If we are already on map, just close. If not, go to map.
                    if (GoRouterState.of(context).uri.toString() != '/map') {
                      context.push('/map');
                    }
                  },
                  child: Text(
                    tr('filter.view_map'),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(int index, String label) {
    return InkWell(
      onTap: () => setState(() => _availability[index] = !_availability[index]),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(_availability[index] ? LucideIcons.checkSquare : LucideIcons.square, color: _availability[index] ? AppColors.primaryRed : const Color(0xFFBDBDBD)),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(fontFamily: 'Outfit', fontSize: 16, color: Color(0xFF828282)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingOption(int index, int stars) {
    return InkWell(
      onTap: () => setState(() => _selectedRating = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(_selectedRating == index ? LucideIcons.circleDot : LucideIcons.circle, color: _selectedRating == index ? AppColors.primaryRed : const Color(0xFFBDBDBD)),
            const SizedBox(width: 12),
            Row(children: List.generate(stars, (i) => const Icon(LucideIcons.star, color: AppColors.primaryRed, size: 20))),
          ],
        ),
      ),
    );
  }
}
