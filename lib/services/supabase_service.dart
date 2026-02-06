import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_profile.dart';
import '../models/stock.dart';
import '../models/analysis.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  String? get userId => _client.auth.currentUser?.id;

  // Profile Operations
  Future<UserProfile?> getProfile() async {
    if (userId == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId!)
        .single();

    return UserProfile.fromJson(response);
  }

  Future<void> updateProfile({String? displayName}) async {
    if (userId == null) return;

    await _client.from('profiles').update({
      'display_name': displayName,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId!);
  }

  // Analysis Limit Operations
  Future<Map<String, dynamic>> checkAnalysisLimit() async {
    if (userId == null) {
      return {'allowed': false, 'tier': 'free', 'used': 0, 'limit': 5};
    }

    final response = await _client.rpc('check_analysis_limit', params: {
      'p_user_id': userId,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> incrementAnalysisCount() async {
    if (userId == null) return;

    await _client.rpc('increment_analysis_count', params: {
      'p_user_id': userId,
    });
  }

  // Portfolio Operations
  Future<List<PortfolioPosition>> getPortfolio() async {
    if (userId == null) return [];

    final response = await _client
        .from('portfolio_positions')
        .select()
        .eq('user_id', userId!)
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      return PortfolioPosition(
        symbol: json['symbol'] as String,
        name: json['name'] as String,
        shares: (json['shares'] as num).toInt(),
        avgPrice: (json['avg_price'] as num).toDouble(),
        currentPrice: 0,
        purchaseDate: DateTime.parse(json['purchase_date'] as String),
      );
    }).toList();
  }

  Future<void> addPortfolioPosition(PortfolioPosition position) async {
    if (userId == null) return;

    await _client.from('portfolio_positions').upsert({
      'user_id': userId,
      'symbol': position.symbol,
      'name': position.name,
      'shares': position.shares,
      'avg_price': position.avgPrice,
      'purchase_date': position.purchaseDate.toIso8601String(),
    });
  }

  Future<void> updatePortfolioPosition(String symbol, {int? shares, double? avgPrice}) async {
    if (userId == null) return;

    final updates = <String, dynamic>{};
    if (shares != null) updates['shares'] = shares;
    if (avgPrice != null) updates['avg_price'] = avgPrice;

    await _client
        .from('portfolio_positions')
        .update(updates)
        .eq('user_id', userId!)
        .eq('symbol', symbol);
  }

  Future<void> removePortfolioPosition(String symbol) async {
    if (userId == null) return;

    await _client
        .from('portfolio_positions')
        .delete()
        .eq('user_id', userId!)
        .eq('symbol', symbol);
  }

  // Watchlist Operations
  Future<List<String>> getWatchlist() async {
    if (userId == null) return [];

    final response = await _client
        .from('watchlist')
        .select('symbol')
        .eq('user_id', userId!)
        .order('added_at', ascending: false);

    return (response as List).map((item) => item['symbol'] as String).toList();
  }

  Future<void> addToWatchlist(String symbol, {String assetType = 'Stock'}) async {
    if (userId == null) return;

    await _client.from('watchlist').upsert({
      'user_id': userId,
      'symbol': symbol,
      'asset_type': assetType,
    });
  }

  Future<void> removeFromWatchlist(String symbol) async {
    if (userId == null) return;

    await _client
        .from('watchlist')
        .delete()
        .eq('user_id', userId!)
        .eq('symbol', symbol);
  }

  // Saved Analyses Operations
  Future<List<MarketAnalysis>> getSavedAnalyses() async {
    if (userId == null) return [];

    final response = await _client
        .from('saved_analyses')
        .select()
        .eq('user_id', userId!)
        .order('analyzed_at', ascending: false)
        .limit(100);

    return (response as List).map((json) {
      final directionStr = json['direction'] as String;
      final direction = AnalysisDirection.values.firstWhere(
        (e) => e.name == directionStr,
        orElse: () => AnalysisDirection.neutral,
      );

      return MarketAnalysis(
        symbol: json['symbol'] as String,
        assetType: json['asset_type'] as String,
        analyzedAt: DateTime.parse(json['analyzed_at'] as String),
        direction: direction,
        confidence: (json['confidence'] as num).toDouble(),
        probabilitySignificantMove: 0,
        expectedMovePercent: (json['expected_move_percent'] as num).toDouble(),
        timeframeDays: 30,
        keyTriggers: List<String>.from(json['key_triggers'] ?? []),
        historicalPatterns: [],
        newsCorrelations: [],
        newsPatterns: [],
        riskFactors: List<String>.from(json['risk_factors'] ?? []),
        recommendation: json['recommendation'] as String,
        summary: json['summary'] as String,
      );
    }).toList();
  }

  Future<void> saveAnalysis(MarketAnalysis analysis) async {
    if (userId == null) return;

    await _client.from('saved_analyses').upsert({
      'user_id': userId,
      'symbol': analysis.symbol,
      'asset_type': analysis.assetType,
      'direction': analysis.direction.name,
      'confidence': analysis.confidence,
      'expected_move_percent': analysis.expectedMovePercent,
      'key_triggers': analysis.keyTriggers,
      'risk_factors': analysis.riskFactors,
      'recommendation': analysis.recommendation,
      'summary': analysis.summary,
      'analyzed_at': analysis.analyzedAt.toIso8601String(),
    }, onConflict: 'user_id,symbol,analyzed_at');
  }

  Future<void> deleteAnalysis(String analysisId) async {
    if (userId == null) return;

    await _client
        .from('saved_analyses')
        .delete()
        .eq('id', analysisId)
        .eq('user_id', userId!);
  }

  // ========== ADMIN OPERATIONS ==========

  /// Get list of all users (admin only)
  Future<Map<String, dynamic>> adminListUsers() async {
    if (userId == null) {
      return {'success': false, 'error': 'Nicht eingeloggt'};
    }

    final response = await _client.rpc('admin_list_users', params: {
      'p_admin_id': userId,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  /// Get system statistics (admin only)
  Future<Map<String, dynamic>> adminGetStatistics() async {
    if (userId == null) {
      return {'success': false, 'error': 'Nicht eingeloggt'};
    }

    final response = await _client.rpc('admin_get_statistics', params: {
      'p_admin_id': userId,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  /// Set user subscription tier (admin only)
  Future<Map<String, dynamic>> adminSetUserTier(String targetUserId, String newTier) async {
    if (userId == null) {
      return {'success': false, 'error': 'Nicht eingeloggt'};
    }

    final response = await _client.rpc('set_user_tier', params: {
      'p_admin_id': userId,
      'p_target_user_id': targetUserId,
      'p_new_tier': newTier,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  /// Reset user analysis count (admin only)
  Future<Map<String, dynamic>> adminResetUserAnalyses(String targetUserId) async {
    if (userId == null) {
      return {'success': false, 'error': 'Nicht eingeloggt'};
    }

    final response = await _client.rpc('admin_reset_user_analyses', params: {
      'p_admin_id': userId,
      'p_target_user_id': targetUserId,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  /// Get tier definitions for display
  Future<List<Map<String, dynamic>>> getTierDefinitions() async {
    final response = await _client.rpc('get_tier_definitions');

    if (response == null) return [];
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Toggle user active status (admin only)
  Future<Map<String, dynamic>> adminToggleUserActive(String targetUserId) async {
    if (userId == null) {
      return {'success': false, 'error': 'Nicht eingeloggt'};
    }

    final response = await _client.rpc('admin_toggle_user_active', params: {
      'p_admin_id': userId,
      'p_target_user_id': targetUserId,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  /// Delete user permanently (admin only)
  Future<Map<String, dynamic>> adminDeleteUser(String targetUserId) async {
    if (userId == null) {
      return {'success': false, 'error': 'Nicht eingeloggt'};
    }

    final response = await _client.rpc('admin_delete_user', params: {
      'p_admin_id': userId,
      'p_target_user_id': targetUserId,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  /// Get analyses for a specific user (admin only)
  Future<Map<String, dynamic>> adminGetUserAnalyses(String targetUserId) async {
    if (userId == null) {
      return {'success': false, 'error': 'Nicht eingeloggt'};
    }

    final response = await _client.rpc('admin_get_user_analyses', params: {
      'p_admin_id': userId,
      'p_target_user_id': targetUserId,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  // ========== AI PROMPT OPERATIONS ==========

  /// Get AI analysis prompt from database
  Future<String?> getAiPrompt() async {
    try {
      final response = await _client.rpc('get_ai_prompt');
      return response as String?;
    } catch (e) {
      return null;
    }
  }

  /// Set AI analysis prompt (admin only)
  Future<Map<String, dynamic>> adminSetAiPrompt(String prompt) async {
    if (userId == null) {
      return {'success': false, 'error': 'Nicht eingeloggt'};
    }

    final response = await _client.rpc('admin_set_ai_prompt', params: {
      'p_admin_id': userId,
      'p_prompt': prompt,
    });

    return Map<String, dynamic>.from(response as Map);
  }

  // ========== ANALYSIS CACHE OPERATIONS ==========

  /// Get cached analysis for a symbol (if < 1 hour old)
  Future<Map<String, dynamic>?> getCachedAnalysis(String symbol) async {
    debugPrint('🔍 getCachedAnalysis called for: $symbol');
    try {
      final response = await _client.rpc('get_cached_analysis', params: {
        'p_symbol': symbol.toUpperCase(),
      });
      debugPrint('🔍 getCachedAnalysis response: $response');

      final result = Map<String, dynamic>.from(response as Map);
      if (result['found'] == true) {
        debugPrint('📦 Cache HIT for $symbol');
        return result;
      }
      debugPrint('📭 Cache MISS for $symbol');
      return null;
    } catch (e) {
      debugPrint('❌ getCachedAnalysis error: $e');
      return null;
    }
  }

  /// Save analysis to cache
  Future<bool> saveCachedAnalysis({
    required String symbol,
    required String assetType,
    required String direction,
    required double confidence,
    required double probabilitySignificantMove,
    required double expectedMovePercent,
    required int timeframeDays,
    required List<String> keyTriggers,
    required List<Map<String, dynamic>> historicalPatterns,
    required List<Map<String, dynamic>> newsCorrelations,
    required List<Map<String, dynamic>> newsPatterns,
    required List<String> riskFactors,
    required String recommendation,
    required String summary,
    required DateTime analyzedAt,
  }) async {
    debugPrint('💾 saveCachedAnalysis called for: $symbol');
    try {
      final response = await _client.rpc('save_cached_analysis', params: {
        'p_symbol': symbol.toUpperCase(),
        'p_asset_type': assetType,
        'p_direction': direction,
        'p_confidence': confidence,
        'p_probability_significant_move': probabilitySignificantMove,
        'p_expected_move_percent': expectedMovePercent,
        'p_timeframe_days': timeframeDays,
        'p_key_triggers': keyTriggers,
        'p_historical_patterns': historicalPatterns,
        'p_news_correlations': newsCorrelations,
        'p_news_patterns': newsPatterns,
        'p_risk_factors': riskFactors,
        'p_recommendation': recommendation,
        'p_summary': summary,
        'p_analyzed_at': analyzedAt.toIso8601String(),
      });

      final result = Map<String, dynamic>.from(response as Map);
      debugPrint('💾 saveCachedAnalysis result: $result');
      return result['success'] == true;
    } catch (e) {
      debugPrint('❌ saveCachedAnalysis error: $e');
      return false;
    }
  }

  /// Get cache statistics (for admin)
  Future<Map<String, dynamic>> getCacheStatistics() async {
    try {
      final response = await _client.rpc('get_cache_statistics');
      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      return {'total_cached': 0, 'fresh_count': 0, 'expired_count': 0};
    }
  }
}
