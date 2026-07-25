// ============================================
// WARDROBE_PROVIDER.DART
// ============================================
// State management for wardrobe functionality
//
// Purpose:
// - Load clothing items from database
// - Handle search and filtering
// - Manage wardrobe state
// - Notify UI of changes
// ============================================

import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../database/tables.dart';
import '../models/clothing_item.dart';

/// WardrobeProvider class
/// Manages the state of the user's wardrobe
class WardrobeProvider with ChangeNotifier {
  // ============================================
  // STATE VARIABLES
  // ============================================

  /// List of all clothing items
  List<ClothingItem> _allClothingItems = [];

  /// Filtered list of clothing items (after search/filter)
  List<ClothingItem> _filteredClothingItems = [];

  /// Loading state
  bool _isLoading = false;

  /// Error message
  String? _errorMessage;

  /// Current search query
  String _searchQuery = '';

  /// Currently selected category filter
  String _selectedCategory = 'All';

  /// Current logged-in user ID
  int? _userId;

  // ============================================
  // GETTERS
  // ============================================

  /// Returns the filtered list of clothing items
  List<ClothingItem> get clothingItems => _filteredClothingItems;

  /// Returns loading state
  bool get isLoading => _isLoading;

  /// Returns error message
  String? get errorMessage => _errorMessage;

  /// Returns search query
  String get searchQuery => _searchQuery;

  /// Returns selected category
  String get selectedCategory => _selectedCategory;

  /// Returns total count of clothing items
  int get totalCount => _allClothingItems.length;

  /// Returns filtered count
  int get filteredCount => _filteredClothingItems.length;

  // ============================================
  // INITIALIZATION
  // ============================================

  /// Sets the current user ID and loads their wardrobe
  Future<void> setUserId(int userId) async {
    _userId = userId;
    await loadWardrobe();
  }

  // ============================================
  // LOAD WARDROBE
  // ============================================

  /// Loads all clothing items for the current user from the database
  Future<void> loadWardrobe() async {
    if (_userId == null) {
      _errorMessage = 'User not logged in';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Get database instance
      final db = await DatabaseHelper.instance.database;

      // Query clothing items with JOINs to get category, color, season, and occasion names
      final List<Map<String, dynamic>> maps = await db.rawQuery('''
        SELECT 
          ci.clothing_id,
          ci.user_id,
          ci.category_id,
          cat.category_name,
          ci.color_id,
          col.color_name,
          ci.season_id,
          s.season_name,
          ci.occasion_id,
          o.occasion_name,
          ci.clothing_name,
          ci.image_path,
          ci.notes,
          ci.date_added
        FROM ${TableNames.clothingItems} ci
        LEFT JOIN ${TableNames.categories} cat ON ci.category_id = cat.category_id
        LEFT JOIN ${TableNames.colors} col ON ci.color_id = col.color_id
        LEFT JOIN ${TableNames.seasons} s ON ci.season_id = s.season_id
        LEFT JOIN ${TableNames.occasions} o ON ci.occasion_id = o.occasion_id
        WHERE ci.user_id = ?
        ORDER BY ci.date_added DESC
      ''', [_userId]);

      // Convert maps to ClothingItem objects
      _allClothingItems = maps.map((map) => ClothingItem.fromMap(map)).toList();

      // Apply current filters
      _applyFilters();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to load wardrobe: ${e.toString()}';
      print('Error loading wardrobe: $e');
      notifyListeners();
    }
  }

  // ============================================
  // SEARCH
  // ============================================

  /// Updates the search query and filters the clothing list
  void searchClothing(String query) {
    _searchQuery = query.trim();
    _applyFilters();
    notifyListeners();
  }

  /// Clears the search query
  void clearSearch() {
    _searchQuery = '';
    _applyFilters();
    notifyListeners();
  }

  // ============================================
  // CATEGORY FILTER
  // ============================================

  /// Updates the category filter
  void filterByCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  /// Resets the category filter to 'All'
  void clearCategoryFilter() {
    _selectedCategory = 'All';
    _applyFilters();
    notifyListeners();
  }

  // ============================================
  // APPLY FILTERS
  // ============================================

  /// Applies search and category filters to the clothing list
  void _applyFilters() {
    // Start with all items
    List<ClothingItem> filtered = List.from(_allClothingItems);

    // Apply category filter
    if (_selectedCategory != 'All') {
      filtered = filtered.where((item) {
        return item.categoryName?.toLowerCase() == _selectedCategory.toLowerCase();
      }).toList();
    }

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((item) {
        // Search in clothing name
        if (item.clothingName.toLowerCase().contains(query)) return true;

        // Search in category name
        if (item.categoryName?.toLowerCase().contains(query) ?? false) return true;

        // Search in color name
        if (item.colorName?.toLowerCase().contains(query) ?? false) return true;

        // Search in style/occasion (e.g. "formal", "casual")
        if (item.occasionName?.toLowerCase().contains(query) ?? false) return true;

        // Search in season (e.g. "summer", "winter")
        if (item.seasonName?.toLowerCase().contains(query) ?? false) return true;

        // Search in notes
        if (item.notes?.toLowerCase().contains(query) ?? false) return true;

        return false;
      }).toList();
    }

    _filteredClothingItems = filtered;
  }

  // ============================================
  // REFRESH
  // ============================================

  /// Refreshes the wardrobe by reloading from database
  Future<void> refreshWardrobe() async {
    await loadWardrobe();
  }

  /// Saves an item using the application's existing SQLite wardrobe table and
  /// refreshes the in-memory list so the Wardrobe screen updates immediately.
  Future<bool> addClothingItem(ClothingItem item) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final db = await DatabaseHelper.instance.database;
      await db.insert(TableNames.clothingItems, item.toMap());
      await loadWardrobe();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Failed to save clothing item. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // DELETE CLOTHING ITEM
  // ============================================

  /// Deletes a clothing item from the database
  Future<bool> deleteClothingItem(int clothingId) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // Delete the clothing item
      final result = await db.delete(
        TableNames.clothingItems,
        where: 'clothing_id = ?',
        whereArgs: [clothingId],
      );

      if (result > 0) {
        // Remove from local lists
        _allClothingItems.removeWhere((item) => item.clothingId == clothingId);
        _applyFilters();
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      print('Error deleting clothing item: $e');
      _errorMessage = 'Failed to delete item';
      notifyListeners();
      return false;
    }
  }

  // ============================================
  // CLEAR ERROR
  // ============================================

  /// Clears the error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ============================================
  // RESET
  // ============================================

  /// Resets all filters and search
  void resetFilters() {
    _searchQuery = '';
    _selectedCategory = 'All';
    _applyFilters();
    notifyListeners();
  }
}
