import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'providers/stock_provider.dart';
import 'providers/analysis_provider.dart';
import 'providers/auth_provider.dart';
import 'widgets/auth_wrapper.dart';
import 'config/supabase_config.dart';
import 'utils/constants.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    // .env file might not exist in web builds
  }

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const StockTraderApp());
}

class StockTraderApp extends StatelessWidget {
  const StockTraderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => StockProvider()),
        ChangeNotifierProvider(create: (_) => AnalysisProvider()),
      ],
      child: MaterialApp(
        title: 'Stock Trader Pro',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.surface,
            error: AppColors.loss,
          ),
          scaffoldBackgroundColor: AppColors.background,
          cardTheme: CardThemeData(
            color: AppColors.card,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.background,
            elevation: 0,
            centerTitle: false,
            iconTheme: IconThemeData(color: AppColors.textPrimary),
            titleTextStyle: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          textTheme: GoogleFonts.interTextTheme(
            ThemeData.dark().textTheme,
          ).apply(
            bodyColor: AppColors.textPrimary,
            displayColor: AppColors.textPrimary,
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: AppColors.surface,
            indicatorColor: AppColors.primary.withValues(alpha: 0.2),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  color: AppColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                );
              }
              return const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: AppColors.primary);
              }
              return const IconThemeData(color: AppColors.textSecondary);
            }),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            hintStyle: const TextStyle(color: AppColors.textHint),
            labelStyle: const TextStyle(color: AppColors.textSecondary),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            backgroundColor: AppColors.surface,
            contentTextStyle: const TextStyle(color: AppColors.textPrimary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}
