import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'screens/chat_room_screen.dart';
import 'utils/deep_link_handler.dart';
import 'dart:io' show Platform;
import 'package:google_fonts/google_fonts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // تهيئة البيانات المحلية للغة العربية
  await initializeDateFormatting('ar', null);

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late AppLinks _appLinks;
  late DeepLinkHandler _deepLinkHandler;

  @override
  void initState() {
    super.initState();
    _appLinks = AppLinks();
    _deepLinkHandler = DeepLinkHandler();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    // معالجة الرابط الأولي (عند فتح التطبيق من رابط)
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleDeepLink(uri);
      }
    } catch (e) {
      debugPrint('خطأ في معالجة الرابط الأولي: $e');
    }

    // الاستماع للروابط الجديدة (أثناء عمل التطبيق)
    _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('خطأ في stream الروابط: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    if (DeepLinkHandler.isValidDeepLink(uri)) {
      // انتظر حتى يصبح BuildContext متاحاً
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _navigatorKey.currentContext;
        if (context != null) {
          _deepLinkHandler.handleDeepLink(context, uri);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isIOS = Platform.isIOS;
    // Zaffa unified maroon theme
    const Color zaffaPrimary = Color(0xFF6E1229); // Dark Maroon (new color)
    const Color zaffaSecondary = Color(0xFFA62B2B); // Accent Maroon
    const Color zaffaSurface = Color(0xFFFFFFFF); // Cards, sheets
    const Color zaffaBackgroundLight = Color(
      0xFFF9FAFB,
    ); // Content background (for surfaces)

    final ColorScheme zaffaScheme = ColorScheme(
      brightness: Brightness.light,
      primary: zaffaPrimary,
      onPrimary: Colors.white,
      secondary: zaffaSecondary,
      onSecondary: Colors.white,
      error: const Color(0xFFEF4444),
      onError: Colors.white,
      surface: zaffaSurface,
      onSurface: const Color(0xFF1F2937),
    );

    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: zaffaScheme,
      // خلفية الصفحات تعود للون الفاتح لضمان تباين البطاقات
      scaffoldBackgroundColor: zaffaBackgroundLight,
      appBarTheme: const AppBarTheme(
        backgroundColor: zaffaPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.white),
      ),
      cardTheme: const CardThemeData(
        color: zaffaSurface,
        elevation: 3,
        margin: EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      dividerColor: Color(0xFFE5E7EB),
      iconTheme: const IconThemeData(color: Color(0xFF1F2937)),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: Color(0xFF1F2937),
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: Color(0xFF1F2937)),
        bodySmall: TextStyle(color: Color(0xFF6B7280)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: zaffaPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: zaffaPrimary,
          side: const BorderSide(color: zaffaPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
    final baseText = baseTheme.textTheme;

    final textTheme = isIOS
        ? _iosTextTheme(baseText)
        : _androidTextTheme(baseText);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'زفـة',
      theme: baseTheme.copyWith(textTheme: textTheme),
      locale: const Locale('ar', 'SA'),
      supportedLocales: const [Locale('ar', 'SA'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
      routes: {
        '/chat': (context) {
          final args =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;

          // تحديد الاسم المعروض
          final otherUserId = args['receiverId'] ?? '';
          String otherUserName = args['otherUserName'] ?? 'مستخدم';

          // إذا كان المستخدم الآخر هو المالك، يظهر باسم "الدعم الفني"
          if (otherUserId == '07721874360') {
            otherUserName = 'الدعم الفني';
          }

          return ChatRoomScreen(
            chatId: args['chatId'] ?? '',
            otherUserId: otherUserId,
            otherUserName: otherUserName,
            currentUserId: args['currentUserId'],
          );
        },
      },
    );
  }
}

TextTheme _androidTextTheme(TextTheme base) {
  final inter = GoogleFonts.interTextTheme(base);
  const height = 1.25;
  const fallbacks = ['Noto Naskh Arabic', 'Cairo', 'Dubai', 'Arial'];
  return inter.copyWith(
    displayLarge: inter.displayLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    displayMedium: inter.displayMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    displaySmall: inter.displaySmall?.copyWith(
      fontWeight: FontWeight.w600,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    headlineLarge: inter.headlineLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    headlineMedium: inter.headlineMedium?.copyWith(
      fontWeight: FontWeight.w600,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    headlineSmall: inter.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    titleLarge: inter.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    titleMedium: inter.titleMedium?.copyWith(
      fontWeight: FontWeight.w500,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    titleSmall: inter.titleSmall?.copyWith(
      fontWeight: FontWeight.w500,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    bodyLarge: inter.bodyLarge?.copyWith(
      fontWeight: FontWeight.w400,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    bodyMedium: inter.bodyMedium?.copyWith(
      fontWeight: FontWeight.w400,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    bodySmall: inter.bodySmall?.copyWith(
      fontWeight: FontWeight.w400,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    labelLarge: inter.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    labelMedium: inter.labelMedium?.copyWith(
      fontWeight: FontWeight.w500,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    labelSmall: inter.labelSmall?.copyWith(
      fontWeight: FontWeight.w500,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
  );
}

TextTheme _iosTextTheme(TextTheme base) {
  const height = 1.22;
  const fallbacks = ['Noto Naskh Arabic', 'Cairo', 'Dubai', 'Arial'];
  return base.copyWith(
    displayLarge: base.displayLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontWeight: FontWeight.w700,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    displaySmall: base.displaySmall?.copyWith(
      fontWeight: FontWeight.w600,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontWeight: FontWeight.w700,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    headlineMedium: base.headlineMedium?.copyWith(
      fontWeight: FontWeight.w600,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontWeight: FontWeight.w600,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    titleMedium: base.titleMedium?.copyWith(
      fontWeight: FontWeight.w500,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontWeight: FontWeight.w500,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    bodyLarge: base.bodyLarge?.copyWith(
      fontWeight: FontWeight.w400,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    bodyMedium: base.bodyMedium?.copyWith(
      fontWeight: FontWeight.w400,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    bodySmall: base.bodySmall?.copyWith(
      fontWeight: FontWeight.w400,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontWeight: FontWeight.w600,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontWeight: FontWeight.w500,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontWeight: FontWeight.w500,
      height: height,
      fontFamilyFallback: fallbacks,
    ),
  );
}
