import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/search_screen.dart';
import '../screens/profile_screen.dart';
import '../utils/constants.dart';

List<Widget> buildCommonAppBarActions(BuildContext context) {
  return [
    IconButton(
      icon: const Icon(Icons.search, color: AppColors.textPrimary),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SearchScreen()),
        );
      },
      tooltip: 'Suchen',
    ),
    Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final tier = authProvider.subscriptionTier;
        final tierColor = tier == 'ultimate'
            ? Colors.amber
            : tier == 'pro'
                ? AppColors.primary
                : AppColors.textSecondary;
        return IconButton(
          icon: Stack(
            children: [
              const Icon(Icons.account_circle, color: AppColors.textPrimary),
              if (tier == 'ultimate' || tier == 'pro')
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: tierColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
          tooltip: 'Profil',
        );
      },
    ),
  ];
}
