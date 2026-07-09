import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'dart:async';
import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:htoochoon_flutter/Live-Session/features/whiteboard/whiteboard_window.dart';
import 'package:htoochoon_flutter/Live-Session/features/notes/notes_window.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/socket_service.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/courses_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/dashboard_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/live_sessions_provider.dart';
import 'package:htoochoon_flutter/Providers/notification_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/subscription_provider.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/programs_provider.dart';
import 'package:htoochoon_flutter/Providers/assignment_provider.dart';
import 'package:htoochoon_flutter/Providers/material_provider.dart';
import 'package:htoochoon_flutter/Providers/chat_provider.dart';
import 'package:htoochoon_flutter/Providers/discussion_provider.dart';
import 'package:htoochoon_flutter/Providers/course_chat_provider.dart';
import 'package:htoochoon_flutter/Providers/submission_notes_provider.dart';
import 'package:htoochoon_flutter/Providers/insights_provider.dart';
import 'package:htoochoon_flutter/Providers/search_provider.dart';
import 'package:htoochoon_flutter/Providers/locale_provider.dart';
import 'package:htoochoon_flutter/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:htoochoon_flutter/Providers/class_provider.dart';
import 'package:htoochoon_flutter/Providers/enrollment_provider.dart';
import 'package:htoochoon_flutter/Providers/invitation_provider.dart';

import 'package:htoochoon_flutter/Providers/org_provider.dart';
import 'package:htoochoon_flutter/Providers/user_provider.dart';
import 'package:htoochoon_flutter/Providers/structure_provider.dart';

import 'package:htoochoon_flutter/Providers/theme_provider.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/admin_shell.dart';
import 'package:htoochoon_flutter/Screens/AuthScreens/login_screen.dart';
import 'package:htoochoon_flutter/Screens/AuthScreens/otp_screen.dart';
import 'package:htoochoon_flutter/Screens/Home/home_tab.dart';
import 'package:htoochoon_flutter/Screens/MainLayout/main_scaffold.dart';
import 'package:htoochoon_flutter/Screens/Onboarding/onboarding_screen.dart';
import 'package:htoochoon_flutter/Providers/auth_provider.dart';
import 'package:htoochoon_flutter/Screens/Teacher/Home/teacher_dashboard_screen.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/services/activity_pinger.dart';
import 'package:htoochoon_flutter/services/update_gate.dart';
import 'package:htoochoon_flutter/proctoring/network_lockdown.dart';
import 'package:htoochoon_flutter/services/deep_link_service.dart';
import 'package:htoochoon_flutter/services/notification_router.dart';
import 'package:htoochoon_flutter/utils/platform_support.dart';
import 'package:htoochoon_flutter/core/global.dart';
import 'package:htoochoon_flutter/core/token_manager.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/local_notification_service.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/push_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:htoochoon_flutter/firebase_options.dart';
import 'package:htoochoon_flutter/lms_demo/demo_services.dart'; // DEMO MODE
import 'package:htoochoon_flutter/lms/forms/screens/lms_home_screen.dart';

import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Detached whiteboard OS window (desktop only). It runs in its own engine, so
  // branch here BEFORE the heavy app bootstrap (Firebase/providers/Dio) — it
  // only needs SharedPreferences + tokens to open its own socket to the room.
  if (args.isNotEmpty && args.first == 'multi_window') {
    final windowId = int.parse(args[1]);
    final payload = (args.length > 2 && args[2].isNotEmpty)
        ? jsonDecode(args[2]) as Map<String, dynamic>
        : <String, dynamic>{};
    await SharedPreferences.getInstance();
    await TokenManager().init();
    // windowType selects which detached surface to boot. Default whiteboard for
    // backward compatibility with existing launches.
    final windowType = (payload['windowType'] ?? 'whiteboard').toString();
    if (windowType == 'notes') {
      runApp(NotesWindowApp(
        windowController: WindowController.fromWindowId(windowId),
        args: payload,
      ));
    } else {
      runApp(WhiteboardWindowApp(
        windowController: WindowController.fromWindowId(windowId),
        args: payload,
      ));
    }
    return;
  }

  // Crash-safety: if a previous EXTREME exam died mid-session and left the
  // hosts-file network block in place, strip it now (no-op + no prompt unless a
  // stale block is actually present). Desktop only; fire-and-forget.
  unawaited(NetworkLockdown.sweepStale());

  // Firebase core + FCM have no Linux implementation (and FCM none on Windows).
  // Guard each init so desktop startup never crashes — the app runs fine
  // without push; tokens simply aren't registered there.
  if (PlatformSupport.supportsFirebaseCore) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      logD('⚠️ Firebase init skipped: $e');
    }
  }
  // FirebaseFirestore.instance.settings = const Settings(
  //   persistenceEnabled: true,
  // );
  await SharedPreferences.getInstance();

  // System-tray / heads-up notifications (in-app + local).
  try {
    await LocalNotificationService.instance.init();
  } catch (e) {
    logD('⚠️ Local notifications init skipped: $e');
  }

  // Background/terminated push: register the FCM background isolate handler and
  // foreground/token listeners. The device token is registered after login.
  if (PlatformSupport.supportsPushMessaging) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      await PushService.instance.initListeners();
    } catch (e) {
      logD('⚠️ Push messaging init skipped: $e');
    }
  }

  final tokenManager = TokenManager();

  final userManager = UserSessionManager();
  await tokenManager.init();

  // FIX 5: single navigatorKey used by BOTH the interceptor and MaterialApp
  final navigatorKey = GlobalKey<NavigatorState>();

  final dio = Dio(
    BaseOptions(
      baseUrl: "https://backend.htoochoon.com/",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
      },
      responseType: ResponseType.json,
    ),
  );
  // Let the push service reuse this authenticated Dio for device-token register/unregister.
  PushService.instance.attachDio(dio);
  Future<String?> refreshAccessToken(String userId) async {
    try {
      final refreshToken = await tokenManager.getRefreshToken();

      logD(
        "🔄 Refresh token retrieved: ${refreshToken?.isNotEmpty == true ? '***' + refreshToken!.substring(refreshToken.length - 4) : 'NULL'}",
      );
      logD("👤 User ID: $userId");

      if (refreshToken == null || userId.isEmpty) {
        logD("❌ No refresh token or user ID found");
        return null;
      }
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: "https://backend.htoochoon.com/",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
        ),
      );
      refreshDio.interceptors.clear();

      logD("📡 Calling refresh endpoint: /auth/refresh");

      final response = await refreshDio.post(
        "/auth/refresh",
        options: Options(headers: {"X-Refresh-Token": refreshToken}),
        // rust reads snake_case; this Dio has no case-converting interceptor.
        data: {"refreshToken": refreshToken, "userId": userId},
      );

      logD("✅ Refresh response status: ${response.statusCode}");
      logD("✅ Refresh response data: ${response.data}");

      final newAccessToken = response.data["accessToken"] as String?;
      final newRefreshToken = response.data["refreshToken"] as String?;

      if (newAccessToken == null) {
        logD("❌ No access_token in refresh response");
        return null;
      }

      await tokenManager.setToken(newAccessToken);
      if (newRefreshToken != null) {
        logD("🔄 New refresh token received, saving...");
        await tokenManager.setRefreshToken(newRefreshToken);
      }

      return newAccessToken;
    } catch (e, stack) {
      logD("❌ Refresh failed: $e");
      logD("📋 Stack: $stack");
      await tokenManager.clearToken();
      return null;
    }
  }

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final accessToken = await tokenManager.getToken();

        logI("→ ${options.method} ${options.uri}");
        logD(
          "🔑 token: ${accessToken?.isNotEmpty == true ? '***${accessToken!.substring(accessToken.length - 6)}' : 'NONE'}",
        );
        if (options.data != null) logD("📦 req body: ${options.data}");

        // ✅ Only add Authorization header for access token
        if (accessToken != null && accessToken.isNotEmpty) {
          options.headers["Authorization"] = "Bearer $accessToken";
        }

        return handler.next(options);
      },

      onResponse: (response, handler) {
        logI("← ${response.statusCode} ${response.requestOptions.uri}");
        logD("📥 res body: ${response.data}");
        return handler.next(response);
      },

      onError: (error, handler) async {
        final path = error.requestOptions.path;

        if (path.contains('/auth/refresh')) {
          logW("✗ refresh failed [${error.response?.statusCode}] ${error.requestOptions.uri}");
          return handler.next(error);
        }

        logE(
          "✗ ${error.response?.statusCode ?? error.type} ${error.requestOptions.method} ${error.requestOptions.uri} :: ${error.message} :: body=${error.response?.data}",
          error,
          error.stackTrace,
        );

        if (error.response?.statusCode == 401 && !tokenManager.isRefreshing) {
          // HARD GUARD: no stored access token = we're on the login screen (or
          // truly logged out). A stray 401 from a background/heartbeat request
          // must NOT trigger refresh-then-push, which rebuilds the login screen
          // and wipes the email/password the user is typing. Bail immediately.
          final existingToken = await tokenManager.getToken();
          if (existingToken == null || existingToken.isEmpty) {
            return handler.next(error);
          }

          final userId = UserSessionManager.userId;

          // if (userId == null || userId.isEmpty) {
          //   logD("❌ No userId available for refresh");
          //   await tokenManager.clearToken();
          //   navigatorKey.currentState?.pushAndRemoveUntil(
          //     MaterialPageRoute(builder: (_) => const PremiumLoginScreen()),
          //     (route) => false,
          //   );
          //   return handler.next(error);
          // }

          // Not signed in (e.g. user is on the login page) — a stray 401 from a
          // public/background/heartbeat request must NOT push a fresh login
          // screen, which would wipe whatever the user is currently typing.
          final hasSession =
              userId != null && userId.toString().trim().isNotEmpty;
          if (!hasSession) {
            return handler.next(error);
          }

          tokenManager.setRefreshing(true);
          final newToken = await refreshAccessToken(userId.toString());
          tokenManager.setRefreshing(false);
          tokenManager.setPendingToken(newToken);

          if (newToken != null) {
            try {
              // Retry the original request with new token
              final opts = error.requestOptions;
              opts.headers["Authorization"] = "Bearer $newToken";
              final response = await dio.fetch(opts);
              return handler.resolve(response);
            } catch (retryError) {
              logD("⚠️ Retry failed: $retryError");
              // Fall through to logout
            }
          }

          // Refresh failed — clear tokens and redirect to login
          await tokenManager.clearToken();
          navigatorKey.currentState?.pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const PremiumLoginScreen()),
            (route) => false,
          );
        }

        return handler.next(error);
      },
    ),
  );

  final apiService = ApiService(dio);

  // 📈 Start the learning-time heartbeat (no-ops/ignored until authenticated).
  ActivityPinger.instance.start(apiService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AssignmentProvider(apiService)),
        ChangeNotifierProvider(create: (_) => MaterialProvider(dio)),
        ChangeNotifierProvider(create: (_) => ChatProvider(dio)),
        ChangeNotifierProvider(create: (_) => DiscussionProvider(dio)),
        ChangeNotifierProvider(create: (_) => CourseChatProvider(dio)),
        ChangeNotifierProvider(create: (_) => SubmissionNotesProvider(dio)),
        ChangeNotifierProvider(create: (_) => InsightsProvider(dio)),
        ChangeNotifierProvider(create: (_) => SearchProvider(dio)),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => EnrollmentProvider(apiService)),
        ChangeNotifierProvider(create: (_) => DashboardProvider(apiService)),
        ChangeNotifierProvider(create: (_) => OrganizationProvider(apiService)),
        ChangeNotifierProvider(create: (_) => CoursesProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ProgramsProvider(apiService)),
        ChangeNotifierProvider(create: (_) => ClassProvider(apiService)),
        ChangeNotifierProvider(create: (_) => LiveSessionProvider(apiService, dio)),
        ChangeNotifierProvider(create: (_) => StructureProvider(apiService)),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService, dio)),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider(apiService)),
        ChangeNotifierProvider(create: (_) => InvitationProvider(apiService)),
        ChangeNotifierProvider(create: (_) => DemoServices(dio)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),

        Provider<ApiService>.value(value: apiService),
        Provider<SocketService>(create: (_) => SocketService()),
        ChangeNotifierProxyProvider<SocketService, NotificationProvider>(
          create: (_) => NotificationProvider(dio),
          update: (_, socket, notif) => notif!..bindSocket(socket),
        ),
        // ProxyProvider<SocketService, WebRTCService>(
        //   update: (_, socket, __) => WebRTCService(socket),
        // ),
      ],
      // FIX 5: pass the single navigatorKey into MyApp
      child: MyApp(navigatorKey: navigatorKey),
    ),
  );
}

// FIX 5: MyApp accepts the navigatorKey instead of creating its own.
// StatefulWidget so it can observe app lifecycle and re-establish the shared
// socket on resume (only when authenticated — never opens an unauth handshake).
class MyApp extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;

  const MyApp({super.key, required this.navigatorKey});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Route incoming join deep links (cold start + warm) to the join screen.
    DeepLinkService.instance.init(widget.navigatorKey);
    // Notification taps (FCM + local) deep-link through here.
    NotificationRouter.instance.attach(widget.navigatorKey);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Reconnect the shared socket on resume — but only if we're logged in.
      // No disconnect on pause: that would drop an in-progress live call.
      () async {
        final token = await TokenManager().getToken();
        if (token != null && token.isNotEmpty && !SocketService().isConnected) {
          await SocketService().initSocket();
        }
      }();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: context.watch<LocaleProvider>().locale,
          navigatorKey: widget.navigatorKey, // ← same key the interceptor uses
          scaffoldMessengerKey: scaffoldMessengerKey,
          debugShowCheckedModeBanner: false,
          title: 'HtooChoon',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.isDarkMode
              ? ThemeMode.dark
              : ThemeMode.light,
          home: AuthWrapper(),
        );
      },
    );
  }
}
// class MyApp extends StatelessWidget {
//   MyApp({super.key});
//
//   final navigatorKey = GlobalKey<NavigatorState>();
//
//   @override
//   Widget build(BuildContext context) {
//     return Consumer<ThemeProvider>(
//       builder: (context, themeProvider, child) {
//         return MaterialApp(
//           localizationsDelegates: const [
//             quill.FlutterQuillLocalizations.delegate,
//             // GlobalMaterialLocalizations.delegate,
//             // GlobalWidgetsLocalizations.delegate,
//             // GlobalCupertinoLocalizations.delegate,
//           ],
//           navigatorKey: navigatorKey,
//           scaffoldMessengerKey: scaffoldMessengerKey,
//           debugShowCheckedModeBanner: false,
//           title: 'HtooChoon',
//           theme: AppTheme.lightTheme,
//           darkTheme: AppTheme.darkTheme,
//           themeMode: themeProvider.isDarkMode
//               ? ThemeMode.dark
//               : ThemeMode.light,
//           home: AuthWrapper(),
//         );
//       },
//     );
//   }
// }

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});
  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Mandatory-update gate: check on launch + on every resume.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateGate.check(context);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      UpdateGate.check(context);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.initialized) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Do NOT swap the whole tree out on `isLoading`. Doing so destroys the
        // login form's State (its TextEditingControllers) every time a sign-in
        // attempt OR a resume-triggered auth refresh toggles isLoading — which
        // wiped the user's typed email/password on app-switch. The login screen
        // shows its own inline (button) progress instead.

        switch (authProvider.status) {
          case AuthStatus.authenticated:
            return const MainScaffold();

          case AuthStatus.needsOtp:
            return OtpScreen(
              email: authProvider.otpEmail ?? "",
              isRegister: true,
            );

          case AuthStatus.unauthenticated:
          default:
            return const PremiumLoginScreen();
        }
      },
    );
  }
}
