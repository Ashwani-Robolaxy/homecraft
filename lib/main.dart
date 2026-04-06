import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'core/router/app_router.dart' show appRouterProvider;
import 'core/theme/app_theme.dart';
import 'core/constants/app_assets.dart';
import 'core/services/app_toast.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Stripe: publishable key is set dynamically per-payment from the server.
  // We set a placeholder here so the SDK initialises; it's always overridden
  // by StripePaymentService before presenting the sheet.
  Stripe.publishableKey = 'pk_test_placeholder';
  await Stripe.instance.applySettings();

  runApp(
    ProviderScope(
      child: EasyLocalization(supportedLocales: const [Locale('en'), Locale('fr')], path: AppAssets.translationsPath, fallbackLocale: const Locale('en'), child: const MyApp()),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return ScreenUtilInit(
      designSize: const Size(393, 852),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: 'HomeCraft Services',
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          theme: AppTheme.lightTheme,
          scaffoldMessengerKey: AppToast.messengerKey,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          // Inject 24-hour format INSIDE MaterialApp so the MediaQuery
          // remains reactive to keyboard / window changes.
          builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
        );
      },
    );
  }
}



/* 

@/Users/Jairaj/Downloads/FLUTTER_CHAT_INTEGRATION.md professional should be able to send the message to client...i have provided you the chat integration doc so that you can implement that easily
Change password
Hide profile'
Delete account
Contact support
Report



*24 March 2026*
1. PROFESSIONAL REGISTRATIONs
-> There will be the separate section for portfolio management
-> Portfolio project will have info including Cost of project, Date of completion, Title, Location, Description and Image
-> Google places api will be used to fetch the professional's service location to show them further on client's map search result
-> Social links and website is for the admin view only

2. There will be three filters for map search result i.e Distance , Service type and Location
3. Client can book the professional by clicking on the professional's card and then clicking on the book appointment button mentioning the project details
4. Client can also create a project and then list it at the professional feed where he can accept or reject the project
5. Client will finalise the professionals out of many just by confirming the booking
6. Show red gradient line above the bottom nav bar (As shown in the figma)
7. Create separate section for Projects where three sections will be shown in the forms of tabs i.e All Projects, Accepted Projects and Rejected Projects
8. By default all the dates will be marked as Unavailable in the professional's calendar to avoid accidental booking from the client side
9. Relevant message will be shown to the client when confirming the unavailable dates and time slot.
10. Change the logo
11. One Reviews per user will be provided when completing the project
12. Under recommendation section, there are two pictures shown side by side, one is the portfolio picture and other is the profile picture






1. Two way to book
  -> Search and book
  -> Create project -> List project at

Portfolio | Profile Picture

1. Cost, date of completion, Title, description and image  in separate section
2. Gradient line..
 */