import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:get_right/theme/app_theme.dart';
import 'package:get_right/routes/app_pages.dart';
import 'package:get_right/routes/app_route_observer.dart';
import 'package:get_right/routes/app_routes.dart';
import 'package:get_right/services/feed_playback_coordinator.dart';
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

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    var client = MyHttpClient(super.createHttpClient(context));
    return client;
  }
}

class MyHttpClient implements HttpClient {
  MyHttpClient(this._inner) {
    _inner.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }

  final HttpClient _inner;

  @override
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port)? callback) => _inner.badCertificateCallback = callback;

  @override
  set connectionFactory(Future<ConnectionTask<Socket>> Function(Uri url, String? proxyHost, int? proxyPort)? f) => _inner.connectionFactory = f;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;

  @override
  set connectionTimeout(Duration? connectionTimeout) => _inner.connectionTimeout = connectionTimeout;

  @override
  Duration get idleTimeout => _inner.idleTimeout;

  @override
  set idleTimeout(Duration idleTimeout) => _inner.idleTimeout = idleTimeout;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? maxConnectionsPerHost) => _inner.maxConnectionsPerHost = maxConnectionsPerHost;

  @override
  bool get autoUncompress => _inner.autoUncompress;

  @override
  set autoUncompress(bool autoUncompress) => _inner.autoUncompress = autoUncompress;

  @override
  String? get userAgent => _inner.userAgent;

  @override
  set userAgent(String? userAgent) => _inner.userAgent = userAgent;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) => _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(Future<bool> Function(Uri url, String scheme, String? realm)? f) => _inner.authenticate = f;

  @override
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String? realm)? f) => _inner.authenticateProxy = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) => _inner.delete(host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _inner.deleteUrl(url);

  @override
  Future<HttpClientRequest> get(String host, int port, String path) => _inner.get(host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _inner.getUrl(url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) => _inner.head(host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _inner.headUrl(url);

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) => _inner.open(method, host, port, path);

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) => _inner.openUrl(method, url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) => _inner.patch(host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _inner.patchUrl(url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) => _inner.post(host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _inner.postUrl(url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) => _inner.put(host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _inner.putUrl(url);
}

void main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  HttpOverrides.global = MyHttpOverrides();

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
    // ScreenUtilInit must wrap GetMaterialApp so .sp/.w/.h are ready on first build.
    // Snackbars use a safe fallback in AuthController when Overlay isn't available yet.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: lightSystemOverlay,
      child: ScreenUtilInit(
        designSize: const Size(375, 812),
        minTextAdapt: true,
        splitScreenMode: true,
        ensureScreenSize: true,
        builder: (context, child) {
          return GetMaterialApp(
            title: 'Get Right',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme.copyWith(textTheme: GoogleFonts.interTextTheme(AppTheme.lightTheme.textTheme)),
            initialRoute: AppPages.initial,
            getPages: AppPages.routes,
            navigatorObservers: [appRouteObserver],
            routingCallback: (routing) {
              final current = routing?.current ?? '';
              if (current != AppRoutes.home) {
                FeedPlaybackCoordinator.instance.requestPause();
              }
            },
            defaultTransition: Transition.cupertino,
            transitionDuration: const Duration(milliseconds: 300),
          );
        },
      ),
    );
  }
}
