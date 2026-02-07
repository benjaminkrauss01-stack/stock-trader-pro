import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/analysis_provider.dart';
import '../providers/stock_provider.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'admin_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Row(
          children: [
            Icon(Icons.person, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Profil', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
      ),
      body: Consumer3<AuthProvider, AnalysisProvider, StockProvider>(
        builder: (context, authProvider, analysisProvider, stockProvider, _) {
          if (authProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          final profile = authProvider.profile;
          final user = authProvider.user;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A. Profile Header
                _buildProfileHeader(
                  user?.email ?? 'Unbekannt',
                  profile?.displayName,
                  profile?.createdAt,
                  authProvider,
                ),
                const SizedBox(height: 16),

                // B. Statistics Grid
                _buildStatisticsGrid(analysisProvider, stockProvider),
                const SizedBox(height: 16),

                // C. Portfolio Summary
                if (stockProvider.portfolio.isNotEmpty) ...[
                  _buildPortfolioSummaryCard(stockProvider),
                  const SizedBox(height: 16),
                ],

                // D. Subscription Card
                _buildSubscriptionCard(context, authProvider),
                const SizedBox(height: 16),

                // E. Analysis Usage Card
                _buildAnalysisUsageCard(analysisProvider),
                const SizedBox(height: 16),

                // F. Settings Card
                _buildSettingsCard(context, authProvider),
                const SizedBox(height: 24),

                // G. Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await authProvider.signOut();
                      if (context.mounted) {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Abmelden'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.loss,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────
  // A. Profile Header
  // ──────────────────────────────────────────────

  String _getInitials(String? displayName, String email) {
    if (displayName != null && displayName.trim().isNotEmpty) {
      final parts = displayName.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return parts[0][0].toUpperCase();
    }
    return email[0].toUpperCase();
  }

  Widget _buildProfileHeader(
    String email,
    String? displayName,
    DateTime? createdAt,
    AuthProvider authProvider,
  ) {
    final tier = authProvider.subscriptionTier;
    final tierColor = _getTierColor(tier);
    final tierName = _getTierName(tier);

    return Card(
      color: AppColors.card,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withValues(alpha: 0.15),
              AppColors.card,
            ],
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Initials Avatar
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  _getInitials(displayName, email),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display Name + Edit
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayName ?? 'Stock Trader',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => _showChangeNameDialog(context, authProvider, displayName),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.edit, color: AppColors.textHint, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Tier Badge + Member Since
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: tierColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          tierName,
                          style: TextStyle(
                            color: tierColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (createdAt != null) ...[
                        const SizedBox(width: 12),
                        const Icon(Icons.calendar_today, color: AppColors.textHint, size: 13),
                        const SizedBox(width: 4),
                        Text(
                          'Seit ${_formatDate(createdAt)}',
                          style: const TextStyle(
                            color: AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // B. Statistics Grid
  // ──────────────────────────────────────────────

  Widget _buildStatisticsGrid(AnalysisProvider analysisProvider, StockProvider stockProvider) {
    final accuracy = analysisProvider.analysisAccuracy;
    final accuracyPercent = accuracy['percent'] as double;
    final accuracyTotal = accuracy['total'] as int;

    Color accuracyColor;
    if (accuracyTotal == 0) {
      accuracyColor = AppColors.textHint;
    } else if (accuracyPercent >= 60) {
      accuracyColor = AppColors.profit;
    } else if (accuracyPercent >= 40) {
      accuracyColor = Colors.amber;
    } else {
      accuracyColor = AppColors.loss;
    }

    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bar_chart, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Statistiken',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.psychology,
                    value: '${analysisProvider.savedAnalyses.length}',
                    label: 'Analysen',
                    iconColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.track_changes,
                    value: accuracyTotal > 0 ? '${accuracyPercent.toStringAsFixed(0)}%' : '--',
                    label: 'Trefferquote',
                    iconColor: accuracyColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.account_balance_wallet,
                    value: '${stockProvider.portfolio.length}',
                    label: 'Positionen',
                    iconColor: AppColors.profit,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatTile(
                    icon: Icons.visibility,
                    value: '${stockProvider.watchlistStocks.length}',
                    label: 'Watchlist',
                    iconColor: Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String value,
    required String label,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // C. Portfolio Summary
  // ──────────────────────────────────────────────

  Widget _buildPortfolioSummaryCard(StockProvider stockProvider) {
    final profit = stockProvider.portfolioTotalProfit;
    final profitPercent = stockProvider.portfolioProfitPercent;
    final isPositive = profit >= 0;

    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_graph, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Portfolio-Uebersicht',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatRow(
              'Gesamtwert',
              Formatters.formatCurrency(stockProvider.portfolioTotalValue),
              AppColors.textPrimary,
            ),
            const SizedBox(height: 10),
            _buildStatRow(
              'Gewinn/Verlust',
              '${isPositive ? '+' : ''}${Formatters.formatCurrency(profit)}',
              isPositive ? AppColors.profit : AppColors.loss,
            ),
            const SizedBox(height: 10),
            _buildStatRow(
              'Rendite',
              '${isPositive ? '+' : ''}${profitPercent.toStringAsFixed(2)}%',
              isPositive ? AppColors.profit : AppColors.loss,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // D. Subscription Card
  // ──────────────────────────────────────────────

  Widget _buildSubscriptionCard(BuildContext context, AuthProvider authProvider) {
    final tier = authProvider.subscriptionTier;
    final isUltimate = tier == 'ultimate';
    final isPro = tier == 'pro';
    final isFriends = tier == 'friends';
    final isAdmin = tier == 'admin';

    final tierColor = _getTierColor(tier);
    final tierIcon = _getTierIcon(tier);
    final tierName = _getTierName(tier);
    final tierDescription = _getTierDescription(tier);

    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(tierIcon, color: tierColor, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Aktuelles Abo',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            tierName,
                            style: TextStyle(
                              color: tierColor,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isUltimate || isFriends || isAdmin) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.verified, color: isAdmin ? Colors.purple : (isFriends ? Colors.teal : Colors.amber), size: 20),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tierDescription,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isAdmin) ...[
              const SizedBox(height: 20),
              const Divider(color: AppColors.cardLight),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AdminScreen()),
                    );
                  },
                  icon: const Icon(Icons.admin_panel_settings),
                  label: const Text('Admin Panel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else if (!isUltimate && !isFriends) ...[
              const SizedBox(height: 20),
              const Divider(color: AppColors.cardLight),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showUpgradeDialog(context);
                  },
                  icon: const Icon(Icons.upgrade),
                  label: Text(isPro ? 'Auf Ultimate upgraden' : 'Upgraden'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // E. Analysis Usage Card
  // ──────────────────────────────────────────────

  Widget _buildAnalysisUsageCard(AnalysisProvider analysisProvider) {
    final remaining = analysisProvider.remainingAnalyses;
    final tier = analysisProvider.subscriptionTier;
    final isUnlimited = tier == 'ultimate' || tier == 'friends' || tier == 'admin';

    int limit;
    if (tier == 'pro') {
      limit = 100;
    } else if (tier == 'ultimate' || tier == 'friends' || tier == 'admin') {
      limit = -1;
    } else {
      limit = 5;
    }

    final used = isUnlimited ? 0 : (limit - remaining);
    final progress = isUnlimited ? 0.0 : (used / limit).clamp(0.0, 1.0);

    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.psychology, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'KI-Analysen diesen Monat',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isUnlimited)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.all_inclusive, color: Colors.amber, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Unbegrenzt',
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$used von $limit verwendet',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$remaining verbleibend',
                    style: TextStyle(
                      color: remaining <= 2 ? AppColors.loss : AppColors.profit,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.cardLight,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    progress > 0.8 ? AppColors.loss : AppColors.primary,
                  ),
                  minHeight: 12,
                ),
              ),
              if (remaining <= 2) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.loss.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.loss.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: AppColors.loss, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          remaining == 0
                              ? 'Limit erreicht! Upgraden Sie fuer mehr Analysen.'
                              : 'Nur noch $remaining ${remaining == 1 ? 'Analyse' : 'Analysen'} verbleibend!',
                          style: const TextStyle(
                            color: AppColors.loss,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // F. Settings Card
  // ──────────────────────────────────────────────

  Widget _buildSettingsCard(BuildContext context, AuthProvider authProvider) {
    return Card(
      color: AppColors.card,
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.badge_outlined,
            title: 'Anzeigename aendern',
            subtitle: authProvider.profile?.displayName ?? 'Nicht festgelegt',
            onTap: () => _showChangeNameDialog(context, authProvider, authProvider.profile?.displayName),
          ),
          const Divider(color: AppColors.cardLight, height: 1),
          _buildSettingsTile(
            icon: Icons.lock_outlined,
            title: 'Passwort aendern',
            subtitle: 'Passwort aktualisieren',
            onTap: () => _showChangePasswordDialog(context, authProvider),
          ),
          const Divider(color: AppColors.cardLight, height: 1),
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Benachrichtigungen',
            subtitle: 'Push-Benachrichtigungen',
            onTap: () => _showInfoDialog(
              context,
              'Benachrichtigungen',
              'Push-Benachrichtigungen sind in Entwicklung und bald verfuegbar!',
              Icons.notifications_active,
            ),
          ),
          const Divider(color: AppColors.cardLight, height: 1),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Hilfe & Support',
            subtitle: 'FAQ und Kontakt',
            onTap: () => _showInfoDialog(
              context,
              'Hilfe & Support',
              'Stock Trader Pro bietet KI-gestuetzte Aktienanalysen, Echtzeit-Kursdaten und virtuelles Portfolio-Management.\n\nBei Fragen oder Problemen kontaktiere uns unter:\nsupport@stocktraderpro.app',
              Icons.support_agent,
            ),
          ),
          const Divider(color: AppColors.cardLight, height: 1),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'Ueber die App',
            subtitle: 'Version 1.0.0',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Stock Trader Pro',
                applicationVersion: '1.0.0',
                applicationLegalese: '2024 Stock Trader Pro',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textHint),
      onTap: onTap,
    );
  }

  // ──────────────────────────────────────────────
  // Dialogs
  // ──────────────────────────────────────────────

  void _showChangeNameDialog(BuildContext context, AuthProvider authProvider, String? currentName) {
    final controller = TextEditingController(text: currentName ?? '');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'Anzeigename aendern',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Dein Name',
              hintStyle: const TextStyle(color: AppColors.textHint),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.cardLight),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: AppColors.cardLight,
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final newName = controller.text.trim();
                      if (newName.isEmpty) return;
                      setDialogState(() => isSaving = true);
                      final success = await authProvider.updateDisplayName(newName);
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Name aktualisiert' : 'Fehler beim Aktualisieren'),
                            backgroundColor: success ? AppColors.profit : AppColors.loss,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, AuthProvider authProvider) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSaving = false;
    String? errorText;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: const Text(
            'Passwort aendern',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: newPasswordController,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Neues Passwort',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.cardLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: AppColors.cardLight,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Passwort bestaetigen',
                  labelStyle: const TextStyle(color: AppColors.textSecondary),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.cardLight),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppColors.primary),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: AppColors.cardLight,
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorText!,
                  style: const TextStyle(color: AppColors.loss, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Abbrechen', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      final newPw = newPasswordController.text;
                      final confirmPw = confirmPasswordController.text;

                      if (newPw.length < 6) {
                        setDialogState(() => errorText = 'Mindestens 6 Zeichen erforderlich');
                        return;
                      }
                      if (newPw != confirmPw) {
                        setDialogState(() => errorText = 'Passwoerter stimmen nicht ueberein');
                        return;
                      }

                      setDialogState(() {
                        isSaving = true;
                        errorText = null;
                      });

                      final success = await authProvider.changePassword(newPw);

                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Passwort aktualisiert' : (authProvider.error ?? 'Fehler')),
                            backgroundColor: success ? AppColors.profit : AppColors.loss,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Aendern'),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String message, IconData icon) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title, style: const TextStyle(color: AppColors.textPrimary)),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text(
          'Upgrade verfuegbar',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildUpgradeOption(
              'Pro',
              '9,99 EUR/Monat',
              '100 KI-Analysen pro Monat',
              AppColors.primary,
              Icons.workspace_premium,
            ),
            const SizedBox(height: 16),
            _buildUpgradeOption(
              'Ultimate',
              '19,99 EUR/Monat',
              'Unbegrenzte KI-Analysen',
              Colors.amber,
              Icons.diamond,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Spaeter', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }

  Widget _buildUpgradeOption(
    String name,
    String price,
    String description,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            price,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Color _getTierColor(String tier) {
    switch (tier) {
      case 'admin': return Colors.purple;
      case 'friends': return Colors.teal;
      case 'ultimate': return Colors.amber;
      case 'pro': return AppColors.primary;
      default: return AppColors.textSecondary;
    }
  }

  IconData _getTierIcon(String tier) {
    switch (tier) {
      case 'admin': return Icons.admin_panel_settings;
      case 'friends': return Icons.favorite;
      case 'ultimate': return Icons.diamond;
      case 'pro': return Icons.workspace_premium;
      default: return Icons.account_circle;
    }
  }

  String _getTierName(String tier) {
    switch (tier) {
      case 'admin': return 'Administrator';
      case 'friends': return 'Friends';
      case 'ultimate': return 'Ultimate';
      case 'pro': return 'Pro';
      default: return 'Free';
    }
  }

  String _getTierDescription(String tier) {
    switch (tier) {
      case 'admin': return 'Voller Zugriff + User-Management';
      case 'friends': return 'Unbegrenzte KI-Analysen';
      case 'ultimate': return 'Unbegrenzte KI-Analysen';
      case 'pro': return '100 KI-Analysen pro Monat';
      default: return '5 KI-Analysen pro Monat';
    }
  }
}
