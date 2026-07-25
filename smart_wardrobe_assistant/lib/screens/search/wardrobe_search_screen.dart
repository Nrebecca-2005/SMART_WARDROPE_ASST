// ============================================
// WARDROBE_SEARCH_SCREEN.DART
// ============================================
// Dedicated search screen for the user's digital wardrobe.
//
// Purpose:
// - Search the user's real clothing items (name, category, colour, style).
// - Reuse the existing WardrobeProvider search (no duplicate data source).
// - Reuse SearchBarWidget, ClothingCard and EmptyWardrobeWidget for a
//   consistent look with the rest of the app.
// ============================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../widgets/clothing_card.dart';
import '../../widgets/empty_wardrobe_widget.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/search_bar_widget.dart';

/// WardrobeSearchScreen
/// Lets the user search their wardrobe and dynamically filter results.
class WardrobeSearchScreen extends StatefulWidget {
  const WardrobeSearchScreen({super.key});

  @override
  State<WardrobeSearchScreen> createState() => _WardrobeSearchScreenState();
}

class _WardrobeSearchScreenState extends State<WardrobeSearchScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareSearch());
  }

  /// Ensures the wardrobe is loaded for the current user and starts from a
  /// clean search query so results reflect only what the user types here.
  Future<void> _prepareSearch() async {
    final wardrobe = context.read<WardrobeProvider>();
    if (wardrobe.totalCount == 0) {
      final userId = context.read<AuthProvider>().currentUser?.userId;
      if (userId != null) {
        await wardrobe.setUserId(userId);
      }
    }
    wardrobe.clearSearch();
  }

  @override
  void dispose() {
    // Do not leave a stale query behind for other screens sharing the provider.
    context.read<WardrobeProvider>().clearSearch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text(
          'Search Wardrobe',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        // Tapping outside the field dismisses the keyboard.
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Consumer<WardrobeProvider>(
            builder: (context, wardrobe, _) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SearchBarWidget(
                      autofocus: true,
                      initialValue: wardrobe.searchQuery,
                      hintText: 'Search by name, category, colour or style...',
                      onSearchChanged: wardrobe.searchClothing,
                    ),
                  ),
                  if (wardrobe.searchQuery.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${wardrobe.filteredCount} '
                          '${wardrobe.filteredCount == 1 ? 'item' : 'items'} found',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Expanded(child: _buildBody(wardrobe)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBody(WardrobeProvider wardrobe) {
    if (wardrobe.isLoading) {
      return const LoadingWidget(message: 'Loading your wardrobe...');
    }

    // Prompt before the user has typed anything.
    if (wardrobe.searchQuery.isEmpty) {
      return _buildPrompt();
    }

    // No matches for the current query.
    if (wardrobe.clothingItems.isEmpty) {
      return const EmptyWardrobeWidget(
        message: 'No clothing items found.',
        subtitle: 'Try a different name, category, colour or style.',
      );
    }

    return GridView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.75,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: wardrobe.clothingItems.length,
      itemBuilder: (context, index) {
        final item = wardrobe.clothingItems[index];
        return ClothingCard(
          item: item,
          onTap: () => Navigator.of(
            context,
          ).pushNamed('/clothing-details', arguments: item),
        );
      },
    );
  }

  Widget _buildPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              'Search your wardrobe',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start typing to find items by name, category, colour or style.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
