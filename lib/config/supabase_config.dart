import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  static String get url => dotenv.env['SUPABASE_URL'] ?? 'http://192.168.1.231:8000';
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  static const Map<String, int> analysisLimits = {
    'free': 5,
    'pro': 100,
    'ultimate': -1,
  };

  static int getAnalysisLimit(String tier) {
    return analysisLimits[tier] ?? 5;
  }

  static bool isUnlimited(String tier) {
    return tier == 'ultimate';
  }

  static String getTierDisplayName(String tier) {
    switch (tier) {
      case 'pro':
        return 'Pro';
      case 'ultimate':
        return 'Ultimate';
      default:
        return 'Free';
    }
  }
}
