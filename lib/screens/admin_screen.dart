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
  final TextEditingController _promptController = TextEditingController();

  Map<String, dynamic>? _statistics;
  List<dynamic>? _users;
  bool _isLoading = true;
  String? _error;

  // Pagination
  int _currentPage = 0;
  static const int _usersPerPage = 20;

  // Expandable user analyses
  String? _expandedUserId;
  final Map<String, List<dynamic>> _userAnalyses = {};
  final Set<String> _loadingAnalyses = {};

  // AI Prompt state
  String? _originalPrompt;
  bool _isPromptLoading = false;
  bool _isPromptSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadAiPrompt();
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _loadAiPrompt() async {
    setState(() => _isPromptLoading = true);
    try {
      final prompt = await _supabaseService.getAiPrompt();
      if (prompt != null) {
        _originalPrompt = prompt;
        _promptController.text = prompt;
      }
    } catch (e) {
      debugPrint('Error loading AI prompt: $e');
    } finally {
      setState(() => _isPromptLoading = false);
    }
  }

  Future<void> _saveAiPrompt() async {
    setState(() => _isPromptSaving = true);
    try {
      final response = await _supabaseService.adminSetAiPrompt(_promptController.text);
      if (response['success'] == true) {
        _originalPrompt = _promptController.text;
        _showSnackBar('Prompt erfolgreich gespeichert', isError: false);
      } else {
        _showSnackBar(response['error'] ?? 'Fehler beim Speichern', isError: true);
      }
    } catch (e) {
      _showSnackBar('Fehler: $e', isError: true);
    } finally {
      setState(() => _isPromptSaving = false);
    }
  }

  void _resetPrompt() {
    if (_originalPrompt != null) {
      _promptController.text = _originalPrompt!;
      setState(() {});
    }
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

  Future<void> _toggleUserActive(String userId, String email, bool isCurrentlyActive) async {
    final action = isCurrentlyActive ? 'deaktivieren' : 'aktivieren';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          'Benutzer $action?',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moechten Sie den Benutzer "$email" wirklich $action?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (isCurrentlyActive)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Deaktivierte Benutzer koennen sich nicht mehr einloggen.',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isCurrentlyActive ? Colors.orange : AppColors.profit,
            ),
            child: Text(isCurrentlyActive ? 'Deaktivieren' : 'Aktivieren'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _supabaseService.adminToggleUserActive(userId);
      if (response['success'] == true) {
        final newStatus = response['is_active'] == true ? 'aktiviert' : 'deaktiviert';
        _showSnackBar('Benutzer $newStatus', isError: false);
        _loadData();
      } else {
        _showSnackBar(response['error'] ?? 'Fehler', isError: true);
      }
    }
  }

  Future<void> _deleteUser(String userId, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Benutzer loeschen?',
          style: TextStyle(color: AppColors.loss),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Moechten Sie den Benutzer "$email" wirklich DAUERHAFT loeschen?',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.loss.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.loss.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: AppColors.loss, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Diese Aktion kann NICHT rueckgaengig gemacht werden! Alle Daten des Benutzers werden geloescht.',
                      style: TextStyle(color: AppColors.loss, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.loss),
            child: const Text('Endgueltig loeschen'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await _supabaseService.adminDeleteUser(userId);
      if (response['success'] == true) {
        _showSnackBar('Benutzer geloescht', isError: false);
        _loadData();
      } else {
        _showSnackBar(response['error'] ?? 'Fehler', isError: true);
      }
    }
  }

  Future<void> _loadUserAnalyses(String userId) async {
    if (_loadingAnalyses.contains(userId)) return;

    setState(() => _loadingAnalyses.add(userId));
    try {
      final response = await _supabaseService.adminGetUserAnalyses(userId);
      if (response['success'] == true) {
        setState(() {
          _userAnalyses[userId] = response['analyses'] as List<dynamic>? ?? [];
        });
      }
    } catch (e) {
      debugPrint('Error loading user analyses: $e');
    } finally {
      setState(() => _loadingAnalyses.remove(userId));
    }
  }

  void _toggleUserExpanded(String userId) {
    setState(() {
      if (_expandedUserId == userId) {
        _expandedUserId = null;
      } else {
        _expandedUserId = userId;
        if (!_userAnalyses.containsKey(userId)) {
          _loadUserAnalyses(userId);
        }
      }
    });
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
                        _buildPromptCard(),
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

  Widget _buildPromptCard() {
    final hasChanges = _promptController.text != (_originalPrompt ?? '');

    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.psychology, color: Colors.purple, size: 24),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'KI-Analyse Prompt',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (_isPromptLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Verfuegbare Platzhalter: {symbol}, {assetType}, {priceData}, {newsData}, {movesWithPrecedingNews}',
              style: TextStyle(color: AppColors.textHint, fontSize: 11),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: TextField(
                controller: _promptController,
                maxLines: 12,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(12),
                  border: InputBorder.none,
                  hintText: 'KI-Analyse Prompt eingeben...',
                  hintStyle: TextStyle(color: AppColors.textHint),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasChanges) ...[
                  TextButton.icon(
                    onPressed: _resetPrompt,
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Zuruecksetzen'),
                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                  ),
                  const SizedBox(width: 12),
                ],
                ElevatedButton.icon(
                  onPressed: _isPromptSaving || !hasChanges ? null : _saveAiPrompt,
                  icon: _isPromptSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save, size: 18),
                  label: Text(_isPromptSaving ? 'Speichern...' : 'Speichern'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasChanges ? AppColors.primary : AppColors.cardLight,
                    foregroundColor: hasChanges ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
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

    final totalPages = (users.length / _usersPerPage).ceil();
    final startIndex = _currentPage * _usersPerPage;
    final endIndex = (startIndex + _usersPerPage).clamp(0, users.length);
    final pageUsers = users.sublist(startIndex, endIndex);

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
            ...pageUsers.map((user) => _buildUserTile(user as Map<String, dynamic>)),
            // Pagination
            if (totalPages > 1) ...[
              const SizedBox(height: 16),
              const Divider(color: AppColors.cardLight),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _currentPage > 0
                        ? () => setState(() => _currentPage--)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    color: AppColors.primary,
                    disabledColor: AppColors.textHint,
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(totalPages, (index) {
                    final isActive = index == _currentPage;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: InkWell(
                        onTap: () => setState(() => _currentPage = index),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: isActive ? Colors.white : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _currentPage < totalPages - 1
                        ? () => setState(() => _currentPage++)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    color: AppColors.primary,
                    disabledColor: AppColors.textHint,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  '${startIndex + 1}-$endIndex von ${users.length}',
                  style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                ),
              ),
            ],
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
    final isActive = user['is_active'] as bool? ?? true;
    final isExpanded = _expandedUserId == userId;
    final analyses = _userAnalyses[userId];
    final isLoadingAnalyses = _loadingAnalyses.contains(userId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isActive ? AppColors.cardLight : AppColors.cardLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: !isActive
              ? AppColors.loss.withValues(alpha: 0.5)
              : tier == 'admin'
                  ? Colors.purple.withValues(alpha: 0.5)
                  : isExpanded
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : Colors.transparent,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // User header row
          Padding(
            padding: const EdgeInsets.all(12),
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
                          if (!isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.loss.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'INAKTIV',
                                style: TextStyle(color: AppColors.loss, fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Expand analyses button
                IconButton(
                  onPressed: () => _toggleUserExpanded(userId),
                  icon: Icon(
                    isExpanded ? Icons.expand_less : Icons.analytics_outlined,
                    color: isExpanded ? AppColors.primary : AppColors.textSecondary,
                    size: 22,
                  ),
                  tooltip: 'Analysen anzeigen',
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  color: AppColors.card,
                  onSelected: (action) {
                    if (action == 'tier') {
                      _changeUserTier(userId, tier);
                    } else if (action == 'reset') {
                      _resetUserAnalyses(userId, email);
                    } else if (action == 'toggle_active') {
                      _toggleUserActive(userId, email, isActive);
                    } else if (action == 'delete') {
                      _deleteUser(userId, email);
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
                    PopupMenuItem(
                      value: 'toggle_active',
                      child: Row(
                        children: [
                          Icon(
                            isActive ? Icons.block : Icons.check_circle,
                            color: isActive ? Colors.orange : AppColors.profit,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isActive ? 'Deaktivieren' : 'Aktivieren',
                            style: TextStyle(color: isActive ? Colors.orange : AppColors.profit),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, color: AppColors.loss, size: 20),
                          SizedBox(width: 8),
                          Text('Loeschen', style: TextStyle(color: AppColors.loss)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Expandable analyses section
          if (isExpanded) ...[
            const Divider(color: AppColors.cardLight, height: 1),
            if (isLoadingAnalyses)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                ),
              )
            else if (analyses == null || analyses.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'Keine Analysen vorhanden',
                    style: TextStyle(color: AppColors.textHint, fontSize: 12),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '${analyses.length} Analysen',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ),
                    ...analyses.map((a) {
                      final analysis = a as Map<String, dynamic>;
                      return _buildAnalysisRow(analysis);
                    }),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(Map<String, dynamic> analysis) {
    final symbol = analysis['symbol'] as String? ?? '';
    final direction = analysis['direction'] as String? ?? 'neutral';
    final confidence = (analysis['confidence'] as num?)?.toDouble() ?? 0;
    final expectedMove = (analysis['expected_move_percent'] as num?)?.toDouble() ?? 0;
    final analyzedAt = DateTime.tryParse(analysis['analyzed_at'] as String? ?? '');
    final summary = analysis['summary'] as String? ?? '';
    final assetType = analysis['asset_type'] as String? ?? '';

    final directionColor = direction == 'bullish'
        ? AppColors.profit
        : direction == 'bearish'
            ? AppColors.loss
            : AppColors.neutral;

    final directionIcon = direction == 'bullish'
        ? Icons.trending_up
        : direction == 'bearish'
            ? Icons.trending_down
            : Icons.trending_flat;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(directionIcon, color: directionColor, size: 18),
              const SizedBox(width: 6),
              Text(
                symbol,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: directionColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  direction.toUpperCase(),
                  style: TextStyle(color: directionColor, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
              if (assetType.isNotEmpty) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    assetType,
                    style: const TextStyle(color: AppColors.primary, fontSize: 9),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${confidence.toStringAsFixed(0)}%',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
              const SizedBox(width: 8),
              Text(
                '${expectedMove >= 0 ? '+' : ''}${expectedMove.toStringAsFixed(1)}%',
                style: TextStyle(color: directionColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              if (analyzedAt != null)
                Text(
                  '${analyzedAt.day}.${analyzedAt.month}.${analyzedAt.year.toString().substring(2)}',
                  style: const TextStyle(color: AppColors.textHint, fontSize: 10),
                ),
            ],
          ),
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              summary,
              style: const TextStyle(color: AppColors.textHint, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
