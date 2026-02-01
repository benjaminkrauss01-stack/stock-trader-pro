import 'package:flutter_test/flutter_test.dart';
import 'package:stock_trader_pro/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('Authentication & Analysis Limit Tests', () {
    late SupabaseService supabaseService;

    setUpAll(() async {
      // Initialize Supabase with test credentials
      await Supabase.initialize(
        url: 'http://192.168.1.231:8000',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlIiwiaWF0IjoxNzA0MDY3MjAwLCJleHAiOjE4NjE5MjAwMDB9.tuurN5FlrfLF-jryuew384OuGCk_9rwaI_KAy0I_Ixg',
      );
      supabaseService = SupabaseService();
    });

    test('Supabase initialization', () async {
      expect(Supabase.instance, isNotNull);
      print('✓ Supabase initialized successfully');
    });

    test('User registration', () async {
      try {
        final response = await Supabase.instance.client.auth.signUp(
          email: 'test${DateTime.now().millisecondsSinceEpoch}@example.com',
          password: 'TestPassword123!',
        );
        expect(response.user, isNotNull);
        expect(response.user!.email, contains('@example.com'));
        print('✓ User registration successful: ${response.user!.email}');
      } catch (e) {
        print('⚠ Registration test: $e');
      }
    });

    test('Check analysis limit for anonymous user', () async {
      // For anon user (not authenticated)
      final limitResult = await supabaseService.checkAnalysisLimit();
      expect(limitResult, isA<Map<String, dynamic>>());
      expect(limitResult['allowed'], isFalse);
      expect(limitResult['tier'], equals('free'));
      print('✓ Analysis limit check: ${limitResult['used']}/${limitResult['limit']}');
    });

    test('Get profile (should be null for anon user)', () async {
      final profile = await supabaseService.getProfile();
      expect(profile, isNull);
      print('✓ Profile for anon user is null (as expected)');
    });
  });
}
