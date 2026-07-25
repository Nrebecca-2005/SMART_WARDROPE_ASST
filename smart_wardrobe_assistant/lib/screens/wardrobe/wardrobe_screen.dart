// ============================================
// WARDROBE_SCREEN.DART
// ============================================
// Main wardrobe screen displaying all clothing items
//
// Purpose:
// - Display user's wardrobe in a grid
// - Search and filter clothing items
// - Navigate to add/view clothing
// - Manage clothing items
// ============================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/wardrobe_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/clothing_card.dart';
import '../../widgets/search_bar_widget.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/empty_wardrobe_widget.dart';
import '../../widgets/loading_widget.dart';

/// WardrobeScreen
/// Displays and manages the user's clothing wardrobe
class WardrobeScreen extends StatefulWidget {
  final bool searchMode;

  const WardrobeScreen({
    super.key,
    this.searchMode = false,
  });

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  /// Available category filters
  final List<String> _categories = [
    'All',
    'Shirts',
    'T-Shirts',
    'Trousers',
    'Dresses',
    'Shoes',
    'Jackets',
    'Accessories',
  ];

  @override
  void initState() {
    super.initState();
    _initializeWardrobe();
  }

  /// Initialize wardrobe by loading user's clothing items
  Future<void> _initializeWardrobe() async {
    // Get current user ID from AuthProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.userId;

    if (userId != null) {
      // Load wardrobe for current user
      final wardrobeProvider =
          Provider.of<WardrobeProvider>(context, listen: false);
      await wardrobeProvider.setUserId(userId);
    }
  }

  /// Refresh wardrobe
  Future<void> _refreshWardrobe() async {
    final wardrobeProvider =
        Provider.of<WardrobeProvider>(context, listen: false);
    await wardrobeProvider.refreshWardrobe();
  }

  Future<void> _startClothingCapture() async {
    try {
      final imagePath = await Navigator.of(context).pushNamed('/camera') as String?;
      if (!mounted || imagePath == null || imagePath.isEmpty) return;

      final processedPath = await Navigator.of(context).pushNamed(
        '/background-removal-preview',
        arguments: imagePath,
      );
      if (!mounted) return;
      if (processedPath == '__retake__') {
        await _startClothingCapture();
        return;
      }
      if (processedPath is! String || processedPath.isEmpty) return;

      await Navigator.of(context).pushNamed('/add-clothing', arguments: processedPath);
      if (mounted) await _refreshWardrobe();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open the camera. Please try again.')),
        );
      }
    }
  }

  /// Show filter bottom sheet
  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFilterBottomSheet(),
    );
  }

  /// Build filter bottom sheet
  Widget _buildFilterBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter by Category',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Category chips
          Consumer<WardrobeProvider>(
            builder: (context, wardrobeProvider, child) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _categories.map((category) {
                  return CategoryChip(
                    label: category,
                    isSelected: wardrobeProvider.selectedCategory == category,
                    onTap: () {
                      wardrobeProvider.filterByCategory(category);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      
      // ============================================
      // APP BAR
      // ============================================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.searchMode ? 'Search Wardrobe' : 'My Wardrobe',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1E293B),
          ),
        ),
        actions: [
          // Filter Icon
          IconButton(
            icon: const Icon(
              Icons.filter_list,
              color: Color(0xFF4F46E5),
            ),
            onPressed: _showFilterBottomSheet,
          ),
          const SizedBox(width: 8),
        ],
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _startClothingCapture,
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
        tooltip: 'Add clothing item',
        child: const Icon(Icons.add),
      ),

      // ============================================
      // BODY
      // ============================================
      body: SafeArea(
        child: Consumer<WardrobeProvider>(
          builder: (context, wardrobeProvider, child) {
            // ============================================
            // LOADING STATE
            // ============================================
            if (wardrobeProvider.isLoading) {
              return const LoadingWidget(
                message: 'Loading your wardrobe...',
              );
            }

            // ============================================
            // ERROR STATE
            // ============================================
            if (wardrobeProvider.errorMessage != null) {
              return _buildErrorState(wardrobeProvider.errorMessage!);
            }

            // ============================================
            // MAIN CONTENT
            // ============================================
            return Column(
              children: [
                // ============================================
                // SEARCH BAR
                // ============================================
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SearchBarWidget(
                    onSearchChanged: (query) {
                      wardrobeProvider.searchClothing(query);
                    },
                    initialValue: wardrobeProvider.searchQuery,
                    hintText: 'Search clothes...',
                    autofocus: widget.searchMode,
                  ),
                ),

                // ============================================
                // CATEGORY FILTER CHIPS
                // ============================================
                SizedBox(
                  height: 50,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return CategoryChip(
                        label: category,
                        isSelected:
                            wardrobeProvider.selectedCategory == category,
                        onTap: () {
                          wardrobeProvider.filterByCategory(category);
                        },
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // ============================================
                // RESULTS COUNT
                // ============================================
                if (wardrobeProvider.searchQuery.isNotEmpty ||
                    wardrobeProvider.selectedCategory != 'All')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${wardrobeProvider.filteredCount} items found',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        if (wardrobeProvider.searchQuery.isNotEmpty ||
                            wardrobeProvider.selectedCategory != 'All')
                          TextButton(
                            onPressed: () {
                              wardrobeProvider.resetFilters();
                            },
                            child: Text(
                              'Clear Filters',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: const Color(0xFF4F46E5),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // ============================================
                // CLOTHING GRID OR EMPTY STATE
                // ============================================
                Expanded(
                  child: wardrobeProvider.clothingItems.isEmpty
                      ? _buildEmptyState(wardrobeProvider)
                      : RefreshIndicator(
                          onRefresh: _refreshWardrobe,
                          color: const Color(0xFF4F46E5),
                          child: GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.75,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: wardrobeProvider.clothingItems.length,
                            itemBuilder: (context, index) {
                              final item = wardrobeProvider.clothingItems[index];
                              return ClothingCard(
                                item: item,
                                onTap: () {
                                  // Navigate to clothing details
                                  Navigator.pushNamed(
                                    context,
                                    '/clothing-details',
                                    arguments: item,
                                  ).then((_) {
                                    // Refresh wardrobe when returning
                                    _refreshWardrobe();
                                  });
                                },
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),


    );
  }

  /// Build empty state based on current filters
  Widget _buildEmptyState(WardrobeProvider wardrobeProvider) {
    if (wardrobeProvider.searchQuery.isNotEmpty ||
        wardrobeProvider.selectedCategory != 'All') {
      // No results for current filter
      return EmptyWardrobeWidget(
        message: 'No items found',
        subtitle:
            'Try adjusting your search or filter to find what you\'re looking for.',
      );
    } else {
      // Wardrobe is actually empty
      return const EmptyWardrobeWidget();
    }
  }

  /// Build error state
  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFEF4444),
              ),
            ),

            const SizedBox(height: 24),

            // Error Title
            Text(
              'Unable to load wardrobe',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Error Message
            Text(
              errorMessage,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Retry Button
            ElevatedButton.icon(
              onPressed: _refreshWardrobe,
              icon: const Icon(Icons.refresh),
              label: Text(
                'Try Again',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
