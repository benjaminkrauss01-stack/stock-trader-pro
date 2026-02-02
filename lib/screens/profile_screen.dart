import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
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
                // User Info Card
                _buildUserInfoCard(user?.email ?? 'Unbekannt', profile?.displayName),
                const SizedBox(height: 16),

                // Subscription Card
                _buildSubscriptionCard(context, authProvider),
                const SizedBox(height: 16),

                // Analysis Usage Card
                _buildAnalysisUsageCard(authProvider),
                const SizedBox(height: 16),

                // Settings Card
                _buildSettingsCard(context),
                const SizedBox(height: 24),

                // Logout Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await authProvider.signOut();
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

  Widget _buildUserInfoCard(String email, String? displayName) {
    return Card(
      color: AppColors.card,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(32),
              ),
              child: const Icon(Icons.person, color: AppColors.primary, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? 'Stock Trader',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, AuthProvider authProvider) {
    final tier = authProvider.subscriptionTier;
    final isUltimate = tier == 'ultimate';
    final isPro = tier == 'pro';

    Color tierColor;
    IconData tierIcon;
    String tierName;
    String tierDescription;

    if (isUltimate) {
      tierColor = Colors.amber;
      tierIcon = Icons.diamond;
      tierName = 'Ultimate';
      tierDescription = 'Unbegrenzte KI-Analysen';
    } else if (isPro) {
      tierColor = AppColors.primary;
      tierIcon = Icons.workspace_premium;
      tierName = 'Pro';
      tierDescription = '100 KI-Analysen pro Monat';
    } else {
      tierColor = AppColors.textSecondary;
      tierIcon = Icons.account_circle;
      tierName = 'Free';
      tierDescription = '5 KI-Analysen pro Monat';
    }

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
                          if (isUltimate) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.verified, color: Colors.amber, size: 20),
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
            if (!isUltimate) ...[
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

  Widget _buildAnalysisUsageCard(AuthProvider authProvider) {
    final remaining = authProvider.remainingAnalyses;
    final tier = authProvider.subscriptionTier;
    final isUnlimited = tier == 'ultimate';

    int limit;
    if (tier == 'pro') {
      limit = 100;
    } else if (tier == 'ultimate') {
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

  Widget _buildSettingsCard(BuildContext context) {
    return Card(
      color: AppColors.card,
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            title: 'Benachrichtigungen',
            subtitle: 'Push-Benachrichtigungen verwalten',
            onTap: () {
              // TODO: Implement notifications settings
            },
          ),
          const Divider(color: AppColors.cardLight, height: 1),
          _buildSettingsTile(
            icon: Icons.security_outlined,
            title: 'Sicherheit',
            subtitle: 'Passwort und 2FA',
            onTap: () {
              // TODO: Implement security settings
            },
          ),
          const Divider(color: AppColors.cardLight, height: 1),
          _buildSettingsTile(
            icon: Icons.help_outline,
            title: 'Hilfe & Support',
            subtitle: 'FAQ und Kontakt',
            onTap: () {
              // TODO: Implement help screen
            },
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
}
