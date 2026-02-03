import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/constants.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  Map<String, dynamic>? _statistics;
  List<dynamic>? _users;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statsResult = await _supabaseService.adminGetStatistics();
      final usersResult = await _supabaseService.adminListUsers();

      if (statsResult['success'] == true && usersResult['success'] == true) {
        setState(() {
          _statistics = statsResult;
          _users = usersResult['users'] as List<dynamic>?;
        });
      } else {
        setState(() {
          _error = statsResult['error'] ?? usersResult['error'] ?? 'Fehler beim Laden';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Fehler: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _changeUserTier(String userId, String currentTier) async {
    final tiers = ['free', 'pro', 'ultimate', 'friends', 'admin'];

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Tier aendern', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: tiers.map((tier) => ListTile(
            title: Text(
              _getTierDisplayName(tier),
              style: TextStyle(
                color: tier == currentTier ? AppColors.primary : AppColors.textPrimary,
                fontWeight: tier == currentTier ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            leading: Icon(
              _getTierIcon(tier),
              color: _getTierColor(tier),
            ),
            trailing: tier == currentTier
                ? const Icon(Icons.check, color: AppColors.primary)
                : null,
            onTap: () => Navigator.of(context).pop(tier),
          )).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
        ],
      ),
    );

    if (result != null && result != currentTier) {
      final response = await _supabaseService.adminSetUserTier(userId, result);
      if (response['success'] == true) {
        _showSnackBar('Tier erfolgreich geaendert', isError: false);
        _loadData();
      } else {
        _showSnackBar(response['error'] ?? 'Fehler', isError: true);
      }
    }
  }

  Future<void> _resetUserAnalyses(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Analysen zuruecksetzen?', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Analysen-Zaehler fuer $email auf 0 zuruecksetzen?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Zuruecksetzen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _supabaseService.adminResetUserAnalyses(userId);
      if (response['success'] == true) {
        _showSnackBar('Analysen zurueckgesetzt', isError: false);
        _loadData();
      } else {
        _showSnackBar(response['error'] ?? 'Fehler', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.loss : AppColors.profit,
      ),
    );
  }

  String _getTierDisplayName(String tier) {
    switch (tier) {
      case 'pro': return 'Pro';
      case 'ultimate': return 'Ultimate';
      case 'friends': return 'Friends';
      case 'admin': return 'Administrator';
      default: return 'Free';
    }
  }

  IconData _getTierIcon(String tier) {
    switch (tier) {
      case 'pro': return Icons.workspace_premium;
      case 'ultimate': return Icons.diamond;
      case 'friends': return Icons.favorite;
      case 'admin': return Icons.admin_panel_settings;
      default: return Icons.account_circle;
    }
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'pro': return AppColors.primary;
      case 'ultimate': return Colors.amber;
      case 'friends': return Colors.teal;
      case 'admin': return Colors.purple;
      default: return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.purple),
            SizedBox(width: 8),
            Text('Admin Panel', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textPrimary),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppColors.loss),
                      const SizedBox(height: 16),
                      Text(_error!, style: const TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatisticsCard(),
                        const SizedBox(height: 16),
                        _buildUsersCard(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildStatisticsCard() {
    final stats = _statistics;
    if (stats == null) return const SizedBox.shrink();

    final usersByTier = stats['users_by_tier'] as Map<String, dynamic>? ?? {};

    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.purple, size: 24),
                SizedBox(width: 8),
                Text(
                  'Statistiken',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildStatItem('Benutzer', '${stats['total_users'] ?? 0}', Icons.people)),
                Expanded(child: _buildStatItem('Analysen (Monat)', '${stats['total_analyses_this_month'] ?? 0}', Icons.psychology)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildStatItem('Watchlist', '${stats['active_watchlist_items'] ?? 0}', Icons.bookmark)),
                Expanded(child: _buildStatItem('Portfolios', '${stats['portfolio_positions'] ?? 0}', Icons.account_balance_wallet)),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: AppColors.cardLight),
            const SizedBox(height: 12),
            const Text(
              'Benutzer nach Tier',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: ['free', 'pro', 'ultimate', 'friends', 'admin'].map((tier) {
                final count = usersByTier[tier] ?? 0;
                return Chip(
                  avatar: Icon(_getTierIcon(tier), size: 18, color: _getTierColor(tier)),
                  label: Text(
                    '${_getTierDisplayName(tier)}: $count',
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                  ),
                  backgroundColor: AppColors.cardLight,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersCard() {
    final users = _users;
    if (users == null || users.isEmpty) {
      return const Card(
        color: AppColors.card,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: Text('Keine Benutzer gefunden', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      );
    }

    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.people, color: Colors.purple, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Benutzer',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${users.length} gesamt',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...users.map((user) => _buildUserTile(user as Map<String, dynamic>)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final tier = user['subscription_tier'] as String? ?? 'free';
    final email = user['email'] as String? ?? 'Unbekannt';
    final displayName = user['display_name'] as String?;
    final analysesUsed = user['ai_analyses_used'] as int? ?? 0;
    final userId = user['id'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: tier == 'admin' ? Colors.purple.withValues(alpha: 0.5) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTierColor(tier).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(_getTierIcon(tier), color: _getTierColor(tier), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName ?? email.split('@').first,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  email,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getTierColor(tier).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTierDisplayName(tier),
                        style: TextStyle(color: _getTierColor(tier), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$analysesUsed Analysen',
                      style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.card,
            onSelected: (action) {
              if (action == 'tier') {
                _changeUserTier(userId, tier);
              } else if (action == 'reset') {
                _resetUserAnalyses(userId, email);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'tier',
                child: Row(
                  children: [
                    Icon(Icons.swap_horiz, color: AppColors.textPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Tier aendern', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: AppColors.textPrimary, size: 20),
                    SizedBox(width: 8),
                    Text('Analysen zuruecksetzen', style: TextStyle(color: AppColors.textPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
