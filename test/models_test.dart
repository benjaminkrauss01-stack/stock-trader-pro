import 'package:flutter_test/flutter_test.dart';
import 'package:stock_trader_pro/models/user_profile.dart';

void main() {
  group('UserProfile Model Tests', () {
    test('UserProfile creation - free tier', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: '123',
        email: 'test@example.com',
        displayName: 'Test User',
        subscriptionTier: 'free',
        aiAnalysesUsed: 3,
        aiAnalysesResetAt: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );

      expect(profile.id, equals('123'));
      expect(profile.email, equals('test@example.com'));
      expect(profile.subscriptionTier, equals('free'));
      expect(profile.aiAnalysesUsed, equals(3));
      print('✓ Free tier profile: ${profile.subscriptionTier}');
    });

    test('UserProfile - analysis limit (free tier)', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: '123',
        email: 'test@example.com',
        displayName: 'Test User',
        subscriptionTier: 'free',
        aiAnalysesUsed: 5, // Max is 5 for free
        aiAnalysesResetAt: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );

      expect(profile.analysisLimit, equals(5));
      expect(profile.remainingAnalyses, equals(0));
      expect(profile.canPerformAnalysis, isFalse);
      print('✓ Free tier limit: ${profile.analysisLimit}, remaining: ${profile.remainingAnalyses}');
    });

    test('UserProfile - analysis limit (pro tier)', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: '123',
        email: 'test@example.com',
        displayName: 'Test User',
        subscriptionTier: 'pro',
        aiAnalysesUsed: 50,
        aiAnalysesResetAt: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );

      expect(profile.analysisLimit, equals(100));
      expect(profile.remainingAnalyses, equals(50));
      expect(profile.canPerformAnalysis, isTrue);
      print('✓ Pro tier limit: ${profile.analysisLimit}, remaining: ${profile.remainingAnalyses}');
    });

    test('UserProfile - analysis limit (ultimate tier)', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: '123',
        email: 'test@example.com',
        displayName: 'Test User',
        subscriptionTier: 'ultimate',
        aiAnalysesUsed: 999,
        aiAnalysesResetAt: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );

      expect(profile.analysisLimit, equals(-1)); // -1 means unlimited
      expect(profile.canPerformAnalysis, isTrue);
      print('✓ Ultimate tier: unlimited analyses');
    });

    test('UserProfile JSON serialization', () {
      final now = DateTime.now();
      final json = {
        'id': '123',
        'email': 'test@example.com',
        'display_name': 'Test User',
        'subscription_tier': 'free',
        'ai_analyses_used': 2,
        'ai_analyses_reset_at': now.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.id, equals('123'));
      expect(profile.subscriptionTier, equals('free'));
      expect(profile.aiAnalysesUsed, equals(2));
      print('✓ JSON deserialization successful');
    });
  });
}
