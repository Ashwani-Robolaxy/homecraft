// App Router Module
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_state_notifier.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/onboarding/presentation/screens/splash_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/terms_of_service_screen.dart';
import '../../features/auth/presentation/screens/privacy_policy_screen.dart';
import '../../features/home/presentation/screens/main_screen.dart';
import '../../features/home/presentation/screens/provider_main_screen.dart';
import '../../features/home/presentation/screens/edit_calendar_screen.dart';
import '../../features/projects/presentation/screens/project_list_screen.dart';
import '../../features/projects/presentation/screens/create_project_screen.dart';
import '../../features/projects/presentation/screens/project_details_screen.dart';
import '../../features/projects/presentation/screens/service_details_screen.dart';
import '../../features/home/presentation/screens/professional_results_screen.dart';
import '../../features/home/presentation/screens/map_screen.dart';
import '../../features/home/presentation/screens/take_action_screen.dart';
import '../../features/home/presentation/screens/chat_screen.dart';
import '../../features/home/presentation/screens/media_screen.dart';
import '../../features/auth/presentation/screens/professional_setup_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart' as profile;
import '../../features/profile/presentation/screens/personal_info_screen.dart' as profile;
import '../../features/profile/presentation/screens/settings_screen.dart' as profile;
import '../../features/profile/presentation/screens/contact_support_screen.dart' as profile;
import '../../features/profile/presentation/screens/reset_password_screen.dart' as profile;
import '../../features/profile/presentation/screens/privacy_policy_screen.dart' as profile;
import '../../features/profile/presentation/screens/terms_of_services_screen.dart' as profile;
import '../../features/profile/presentation/screens/about_us_screen.dart' as profile;
import '../../features/profile/presentation/screens/provider_profile_info_screen.dart';
import '../../features/profile/presentation/screens/edit_personal_info_screen.dart';
import '../../features/profile/presentation/screens/notification_preference_screen.dart';
import '../../features/profile/presentation/screens/accepted_projects_screen.dart';
import '../../features/profile/presentation/screens/provider_favorites_screen.dart';
import '../../features/profile/presentation/screens/subscription_plans_screen.dart';
import '../../features/projects/domain/models/project.dart';

const _publicPaths = ['/splash', '/onboarding', '/login', '/register', '/forgot-password', '/terms', '/privacy', '/verify-otp', '/reset-password'];

GoRouter _createRouter(AuthStateNotifier authNotifier) {
  return GoRouter(
    refreshListenable: authNotifier,
    initialLocation: '/splash',
    redirect: (context, state) {
      final user = authNotifier.currentUser;
      final path = state.uri.path;
      final isPublic = _publicPaths.contains(path);
      if (user != null && (path == '/login' || path == '/register')) {
        return user.isProvider ? '/provider-home' : '/home';
      }
      if (user == null && !isPublic) return '/login';
      return null;
    },
    routes: _routes,
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(authStateNotifierProvider);
  return _createRouter(notifier);
});

final List<RouteBase> _routes = [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(path: '/forgot-password', builder: (context, state) => const ForgotPasswordScreen()),
    GoRoute(path: '/verify-otp', builder: (context, state) => const OtpVerificationScreen()),
    GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordScreen()),
    GoRoute(path: '/terms', builder: (context, state) => const TermsOfServiceScreen()),
    GoRoute(path: '/privacy', builder: (context, state) => const PrivacyPolicyScreen()),
    GoRoute(path: '/home', builder: (context, state) => const MainScreen()),
    GoRoute(path: '/projects', builder: (context, state) => const ProjectListScreen()),
    GoRoute(path: '/create-project', builder: (context, state) => const CreateProjectScreen()),
    GoRoute(
      path: '/project-details',
      builder: (context, state) {
        final project = state.extra as Project;
        return ProjectDetailsScreen(project: project);
      },
    ),
    GoRoute(path: '/service-details', builder: (context, state) => const ServiceDetailsScreen()),
    GoRoute(path: '/professional-results', builder: (context, state) => const ProfessionalResultsScreen()),
    GoRoute(path: '/map', builder: (context, state) => const MapScreen()),
    GoRoute(path: '/take-action', builder: (context, state) => const TakeActionScreen()),
    GoRoute(path: '/chat', builder: (context, state) => const ChatScreen()),
    GoRoute(path: '/media', builder: (context, state) => const MediaScreen()),
    GoRoute(path: '/professional-setup', builder: (context, state) => const ProfessionalSetupScreen()),
    GoRoute(path: '/provider-home', builder: (context, state) => const ProviderMainScreen()),
    GoRoute(path: '/edit-calendar', builder: (context, state) => const EditCalendarScreen()),
    GoRoute(path: '/profile', builder: (context, state) => const profile.ProfileScreen()),
    GoRoute(path: '/personal-info', builder: (context, state) => const profile.PersonalInfoScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const profile.SettingsScreen()),
    GoRoute(path: '/contact-support', builder: (context, state) => const profile.ContactSupportScreen()),
    GoRoute(path: '/reset-password-profile', builder: (context, state) => const profile.ResetPasswordScreen()),
    GoRoute(path: '/privacy-policy', builder: (context, state) => const profile.PrivacyPolicyScreen()),
    GoRoute(path: '/terms-of-service', builder: (context, state) => const profile.TermsOfServiceScreen()),
    GoRoute(path: '/about-us', builder: (context, state) => const profile.AboutUsScreen()),
    GoRoute(path: '/provider-profile-info', builder: (context, state) => const ProviderProfileInfoScreen()),
    GoRoute(path: '/edit-personal-info', builder: (context, state) => const EditPersonalInfoScreen()),
    GoRoute(path: '/notification-preference', builder: (context, state) => const NotificationPreferenceScreen()),
    GoRoute(path: '/accepted-projects', builder: (context, state) => const AcceptedProjectsScreen()),
    GoRoute(path: '/provider-favorites', builder: (context, state) => const ProviderFavoritesScreen()),
    GoRoute(path: '/subscription-plans', builder: (context, state) => const SubscriptionPlansScreen()),
  ];
