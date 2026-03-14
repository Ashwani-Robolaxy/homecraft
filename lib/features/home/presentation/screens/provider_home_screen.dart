import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/constants/app_colors.dart';
import 'projects_screen.dart';

class ProviderHomeScreen extends StatefulWidget {
  const ProviderHomeScreen({super.key});

  @override
  State<ProviderHomeScreen> createState() => _ProviderHomeScreenState();
}

class _ProviderHomeScreenState extends State<ProviderHomeScreen> {
  bool _isSearchActive = false;
  late ScrollController _dateScrollController;
  double _scrollProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _dateScrollController = ScrollController();
    _dateScrollController.addListener(() {
      if (_dateScrollController.hasClients) {
        setState(() {
          _scrollProgress = (_dateScrollController.offset / _dateScrollController.position.maxScrollExtent).clamp(0.0, 1.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('provider.home.recommendations'.tr(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('provider.home.limitation'.tr(namedArgs: {'current': '3', 'max': '4'}), style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildJobCard(
                        context,
                        title: 'provider.home.card_title_example'.tr(),
                        price: '€ 200',
                        location: 'provider.home.card_location_example'.tr(),
                        date: 'provider.home.card_date_example'.tr(),
                        description: 'provider.home.card_description_example'.tr(),
                      ),
                      const SizedBox(height: 20),
                      _buildJobCard(
                        context,
                        title: 'provider.home.card_title_example'.tr(),
                        price: '€ 200',
                        location: 'provider.home.card_location_example'.tr(),
                        date: 'provider.home.card_date_example'.tr(),
                        description: 'provider.home.card_description_example'.tr(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isSearchActive) _buildSearchOverlay(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 480, // Increased height to match screenshot proportion
          width: double.infinity,
          decoration: const BoxDecoration(
            image: DecorationImage(image: AssetImage('assets/images/house_interior.png'), fit: BoxFit.cover),
          ),
          child: Container(
            color: Colors.black.withValues(alpha: 0.2), // Subtle overlay
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
              children: [
                Image.asset(
                  'assets/images/logo_white.png', // AppAssets.logoHorizontalWhite
                  height: 60,
                  errorBuilder: (context, error, stackTrace) => Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'H/',
                        style: GoogleFonts.playfairDisplay(fontSize: 48, color: Colors.white, fontWeight: FontWeight.normal),
                      ),
                      Text(
                        'omeCraft',
                        style: GoogleFonts.playfairDisplay(fontSize: 42, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: TextField(
                    readOnly: true,
                    onTap: () {
                      setState(() {
                        _isSearchActive = true;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'provider.home.search_hint'.tr(),
                      hintStyle: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w300),
                      prefixIcon: const Icon(LucideIcons.search, color: Colors.white, size: 22),
                      suffixIcon: const Icon(LucideIcons.x, color: Colors.white, size: 22),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.1), // Semi-transparent background
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                        borderSide: const BorderSide(color: Colors.white, width: 2), // White outline
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                        borderSide: const BorderSide(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJobCard(BuildContext context, {required String title, required String price, required String location, required String date, required String description}) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ProjectsScreen()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.asset(
                    'assets/images/garden.png',
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.grey[300]!, Colors.grey[100]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.image, size: 40, color: Colors.black12),
                            const SizedBox(height: 8),
                            Text('provider.home.image_not_available'.tr(), style: GoogleFonts.outfit(fontSize: 12, color: Colors.black26)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Column(children: [_buildCircularIcon(LucideIcons.heart, AppColors.primaryRed), const SizedBox(height: 8), _buildCircularIcon(LucideIcons.messageCircle, Colors.black87)]),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(
                        price,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(location, style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54)),
                      const SizedBox(width: 8),
                      Text(date, style: GoogleFonts.outfit(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: GoogleFonts.outfit(fontSize: 14, color: Colors.black54, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF800000),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('provider.home.reject'.tr(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF238E10),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('provider.home.accept'.tr(), style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.1),
      child: Stack(
        children: [
          Positioned(
            top: 180, // Positioned below the logo area
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('provider.home.location'.tr(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'provider.home.search_hint'.tr(),
                      hintStyle: GoogleFonts.outfit(color: Colors.black26),
                      prefixIcon: const Icon(LucideIcons.search, color: Colors.black26, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.black, size: 20),
                        onPressed: () {
                          setState(() {
                            _isSearchActive = false;
                          });
                        },
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Color(0xFF7A0000), width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: Color(0xFF7A0000), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Color(0xFF7A0000), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Text('Paris', style: GoogleFonts.outfit(fontSize: 16, color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text('provider.home.date_of_intervention'.tr(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    controller: _dateScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        10, // Increased to ensure scrollability
                        (index) => Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(color: const Color(0xFFF8EDED), borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            children: [
                              Text(
                                'Fri',
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7A0000)),
                              ),
                              Text(
                                '30',
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF7A0000)),
                              ),
                              Text(
                                'May',
                                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF7A0000)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(LucideIcons.chevronLeft, color: Colors.black87, size: 20),
                      Expanded(
                        child: Container(
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(color: const Color(0xFFE5B9B9), borderRadius: BorderRadius.circular(4)),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final double barWidth = 80;
                              final double maxScrollableWidth = constraints.maxWidth - barWidth;
                              return Stack(
                                children: [
                                  Positioned(
                                    left: _scrollProgress * maxScrollableWidth,
                                    child: Container(
                                      width: barWidth,
                                      height: 8,
                                      decoration: BoxDecoration(color: const Color(0xFF7A0000), borderRadius: BorderRadius.circular(4)),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                      Icon(LucideIcons.chevronRight, color: Colors.black87, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _isSearchActive = false;
              });
            },
            child: Container(width: double.infinity, height: double.infinity, color: Colors.transparent),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularIcon(IconData icon, Color color) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
