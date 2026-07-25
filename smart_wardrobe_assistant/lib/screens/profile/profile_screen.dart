import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/wardrobe_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            if (!authProvider.isAuthenticated ||
                authProvider.currentUser == null) {
              return _buildSignedOut(context);
            }

            final user = authProvider.currentUser!;

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildHeaderCard(
                  context,
                  user.initials,
                  user.fullName,
                  user.email,
                  user.gender,
                ),
                const SizedBox(height: 24),
                _buildActionsCard(context, authProvider),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    String initials,
    String fullName,
    String email,
    String? gender,
  ) {
    return Card(
      elevation: 0,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 28,
          horizontal: 20,
        ),
        child: Column(
          children: [
            Consumer<ProfileProvider>(
              builder: (context, profile, _) {
                final hasPicture =
                    profile.hasProfilePicture &&
                    profile.profilePicturePath != null &&
                    File(profile.profilePicturePath!).existsSync();

                return CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary,
                  child: hasPicture
                      ? ClipOval(
                          child: Image.file(
                            File(profile.profilePicturePath!),
                            width: 96,
                            height: 96,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _initials(initials);
                            },
                          ),
                        )
                      : _initials(initials),
                );
              },
            ),

            const SizedBox(height: 16),

            Text(
              fullName,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 4),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.email_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),

            if (gender != null && gender.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  gender,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _initials(String initials) {
    return Text(
      initials,
      style: GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textOnPrimary,
      ),
    );
  }

  Widget _buildActionsCard(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    return Card(
      elevation: 0,
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _actionTile(
            icon: Icons.edit_outlined,
            label: 'Edit Profile',
            onTap: () => _showEditProfile(
              context,
              authProvider,
            ),
          ),

          const Divider(
            height: 1,
            color: AppColors.divider,
          ),

          _actionTile(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),

          const Divider(
            height: 1,
            color: AppColors.divider,
          ),

          _actionTile(
            icon: Icons.logout,
            label: 'Logout',
            iconColor: AppColors.error,
            labelColor: AppColors.error,
            onTap: () => _confirmLogout(
              context,
              authProvider,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = AppColors.primary,
    Color labelColor = AppColors.textPrimary,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: iconColor,
      ),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: labelColor,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right,
        color: AppColors.textHint,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSignedOut(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_outline,
              size: 72,
              color: AppColors.textHint,
            ),

            const SizedBox(height: 16),

            Text(
              'You are not signed in',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Sign in to view your profile details.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
              ),
              child: Text(
                'Go to Login',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfile(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    final user = authProvider.currentUser;

    if (user == null) return;

    final nameController = TextEditingController(
      text: user.fullName,
    );

    String? gender = user.gender;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext)
                    .viewInsets
                    .bottom +
                20,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Profile',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: nameController,
                    textCapitalization:
                        TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Full name',
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Gender',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Wrap(
                    spacing: 8,
                    children: [
                      'Male',
                      'Female',
                      'Other',
                    ].map((option) {
                      return ChoiceChip(
                        label: Text(option),
                        selected: gender == option,
                        selectedColor:
                            AppColors.primaryLight,
                        onSelected: (_) {
                          setModalState(() {
                            gender = option;
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            AppColors.primary,
                        foregroundColor:
                            AppColors.textOnPrimary,
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                      onPressed: () async {
                        final newName =
                            nameController.text.trim();

                        if (newName.isEmpty) return;

                        final messenger =
                            ScaffoldMessenger.of(context);

                        final navigator =
                            Navigator.of(sheetContext);

                        final success =
                            await authProvider.updateProfile(
                          fullName: newName,
                          gender: gender,
                        );

                        navigator.pop();

                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Profile updated.'
                                  : 'Could not update profile.',
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Save',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _confirmLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            'Logout',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: GoogleFonts.poppins(
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final navigator =
                    Navigator.of(context);

                final profileProvider =
                    context.read<ProfileProvider>();

                final wardrobeProvider =
                    context.read<WardrobeProvider>();

                Navigator.of(dialogContext).pop();

                await authProvider.logout();

                profileProvider.clear();

                wardrobeProvider.resetFilters();

                navigator.pushNamedAndRemoveUntil(
                  '/login',
                  (route) => false,
                );
              },
              child: Text(
                'Logout',
                style: GoogleFonts.poppins(
                  color: AppColors.error,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}