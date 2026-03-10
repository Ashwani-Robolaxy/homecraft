import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/common_app_bar.dart';
import '../../../../core/widgets/primary_gradient_button.dart';
import '../widgets/appointment_card.dart';

class AppointmentScreen extends StatefulWidget {
  const AppointmentScreen({super.key});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: CommonAppBar(
        title: 'My Appointment',
        showBackButton: false,
        showLogo: true,
        showNotification: true,
        notificationCount: 1,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryRed,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryRed,
              indicatorWeight: 3,
              labelStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Current Appointment'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(controller: _tabController, children: [_buildCurrentAppointments(), _buildHistoryAppointments()]),
    );
  }

  Widget _buildCurrentAppointments() {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: [
        AppointmentCard(
          profImage: 'assets/images/prof_1.png',
          profName: 'Cuisiniste',
          clientName: 'Luck Mac',
          status: AppointmentStatus.current,
          onActionPressed: () => _showCancelBookingDialog(context),
        ),
        AppointmentCard(
          profImage: 'assets/images/prof_2.png',
          profName: 'Cuisiniste',
          clientName: 'Luck Mac',
          status: AppointmentStatus.accepted,
          initiallyExpanded: true,
          onActionPressed: () => _showCompleteWorkDialog(context),
        ),
        const AppointmentCard(profImage: 'assets/images/prof_3.png', profName: 'Cuisiniste', clientName: 'Luck Mac', status: AppointmentStatus.current),
      ],
    );
  }

  Widget _buildHistoryAppointments() {
    return ListView(
      padding: const EdgeInsets.only(top: 16),
      children: const [AppointmentCard(profImage: 'assets/images/prof_1.png', profName: 'Cuisiniste', clientName: 'Luck Mac', status: AppointmentStatus.complete)],
    );
  }

  void _showCancelBookingDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ),
              Text(
                'Cancel  Booking',
                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
              ),
              const SizedBox(height: 16),
              Text(
                "Can't cancel 24h before the appointment",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.black),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/take-action');
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD0D0D0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          backgroundColor: const Color(0xFFF5E9E9),
                        ),
                        child: Text(
                          'Go Back',
                          style: GoogleFonts.outfit(color: AppColors.primaryRed, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryGradientButton(text: 'Chat', height: 50, onPressed: () {}),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompleteWorkDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Complete  Work',
                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.primaryRed),
              ),
              const SizedBox(height: 16),
              const Text(
                'Is your task complete? If not, take action. If yes, click \'Complete\'',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFD0D0D0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          backgroundColor: const Color(0xFFF5E9E9),
                        ),
                        child: Text(
                          'Take Action',
                          style: GoogleFonts.outfit(color: AppColors.primaryRed, fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: PrimaryGradientButton(text: 'Complete', height: 50, onPressed: () => Navigator.pop(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
