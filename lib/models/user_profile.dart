class UserProfile {
  final String id;
  final String email;
  final String? displayName;
  final String subscriptionTier;
  final int aiAnalysesUsed;
  final DateTime aiAnalysesResetAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.email,
    this.displayName,
    required this.subscriptionTier,
    required this.aiAnalysesUsed,
    required this.aiAnalysesResetAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: json['display_name'] as String?,
      subscriptionTier: json['subscription_tier'] as String? ?? 'free',
      aiAnalysesUsed: json['ai_analyses_used'] as int? ?? 0,
      aiAnalysesResetAt: DateTime.parse(json['ai_analyses_reset_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'subscription_tier': subscriptionTier,
      'ai_analyses_used': aiAnalysesUsed,
      'ai_analyses_reset_at': aiAnalysesResetAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  int get analysisLimit {
    switch (subscriptionTier) {
      case 'pro':
        return 100;
      case 'ultimate':
      case 'admin':
        return -1; // Unlimited
      default:
        return 5;
    }
  }

  int get remainingAnalyses {
    if (subscriptionTier == 'ultimate' || subscriptionTier == 'admin') return -1;
    return analysisLimit - aiAnalysesUsed;
  }

  bool get canPerformAnalysis {
    if (subscriptionTier == 'ultimate' || subscriptionTier == 'admin') return true;
    return aiAnalysesUsed < analysisLimit;
  }

  bool get isAdmin => subscriptionTier == 'admin';

  String get tierDisplayName {
    switch (subscriptionTier) {
      case 'pro':
        return 'Pro';
      case 'ultimate':
        return 'Ultimate';
      case 'admin':
        return 'Administrator';
      default:
        return 'Free';
    }
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? subscriptionTier,
    int? aiAnalysesUsed,
    DateTime? aiAnalysesResetAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      subscriptionTier: subscriptionTier ?? this.subscriptionTier,
      aiAnalysesUsed: aiAnalysesUsed ?? this.aiAnalysesUsed,
      aiAnalysesResetAt: aiAnalysesResetAt ?? this.aiAnalysesResetAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
