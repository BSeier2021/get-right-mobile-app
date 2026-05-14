import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_right/theme/app_theme.dart';
import 'package:get_right/routes/app_pages.dart';
import 'package:get_right/routes/app_route_observer.dart';
import 'package:get_right/services/storage_service.dart';
import 'package:get_right/controllers/auth_controller.dart';
import 'package:get_right/theme/color_constants.dart';

// 1. DEFINE THE STYLE FOR LIGHT SCREENS (DARK ICONS)
// Updated for Steel Grey background - dark icons for visibility
const SystemUiOverlayStyle lightSystemOverlay = SystemUiOverlayStyle(
  // Make status bar background transparent
  statusBarColor: Colors.transparent,

  // *** THIS IS THE CRUCIAL LINE for Android/General ***
  // Brightness.dark makes the icons/text dark for visibility against a light background.
  statusBarIconBrightness: Brightness.dark,

  // *** THIS IS THE CRUCIAL LINE for iOS ***
  // Brightness.light tells iOS the background is light, so it should use dark foreground elements.
  statusBarBrightness: Brightness.light,

  // Ensure navigation bar (Android bottom bar) icons are also dark if visible
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarColor: AppColors.primary, // Steel Grey
);

// Stub for Firebase Messaging background handler (to prevent errors if Firebase tries to initialize)
@pragma('vm:entry-point')
void _firebaseMessagingBackgroundHandler(dynamic message) async {
  // This is a stub to prevent Firebase initialization errors
  // Firebase is not currently used in this app
}

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Remove SystemChrome.setSystemUIOverlayStyle from here,
  // as it's less reliable than using AnnotatedRegion in the widget tree.

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);

  // Initialize services
  await initServices();

  runApp(const GetRightApp());
}

/// Initialize all required services
Future<void> initServices() async {
  await GetStorage.init();

  // Initialize StorageService
  final storageService = await StorageService.getInstance();
  Get.put(storageService);

  // Initialize AuthController (single instance for the app lifecycle)
  Get.put(AuthController(storageService), permanent: true);
}

class GetRightApp extends StatelessWidget {
  const GetRightApp({super.key});
  @override
  Widget build(BuildContext context) {
    // 2. WRAP the entire app in AnnotatedRegio
    // Updated for Steel Grey background with dark icons
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightSystemOverlay,
      child: ScreenUtilInit(
        designSize: const Size(375, 812), // iPhone X design size (standard)
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) {
          return GetMaterialApp(
            title: 'Get Right',
            debugShowCheckedModeBanner: false,

            // Apply App Theme with Google Fonts fallback for Inter
            theme: AppTheme.lightTheme.copyWith(textTheme: GoogleFonts.interTextTheme(AppTheme.lightTheme.textTheme)),

            // GetX Routing
            initialRoute: AppPages.initial,
            getPages: AppPages.routes,
            navigatorObservers: [appRouteObserver],

            // Default transition
            defaultTransition: Transition.cupertino,
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
    );
  }
}
