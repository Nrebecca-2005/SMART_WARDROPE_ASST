// ============================================
// RECOMMENDATION_PROVIDER.DART
// ============================================
// Provider class for recommendation state management
//
// Purpose:
// - Manage recommendation state
// - Coordinate weather and wardrobe data
// - Generate and cache recommendations
// ============================================

import 'package:flutter/material.dart';
import '../models/recommendation_model.dart';
import '../models/weather_model.dart';
import '../models/calendar_event_model.dart';
import '../models/clothing_item.dart';
import '../services/recommendation_service.dart';
import '../services/ai_service.dart';

/// Recommendation state enum
enum RecommendationState {
  initial,      // No recommendation generated yet
  loading,      // Currently generating recommendation
  loaded,       // Recommendation successfully generated
  error,        // Error occurred
  emptyWardrobe, // User has no clothing items
}

/// RecommendationProvider
/// Manages state for outfit recommendations
class RecommendationProvider with ChangeNotifier {
  // ============================================
  // STATE VARIABLES
  // ============================================

  RecommendationState _state = RecommendationState.initial;
  RecommendationModel? _recommendation;
  String? _errorMessage;
  final RecommendationService _recommendationService = RecommendationService();
  final AiService _aiService;

  RecommendationProvider({AiService? aiService}) : _aiService = aiService ?? AiService();

  // ============================================
  // GETTERS
  // ============================================

  RecommendationState get state => _state;
  RecommendationModel? get recommendation => _recommendation;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == RecommendationState.loading;
  bool get hasError => _state == RecommendationState.error;
  bool get hasRecommendation => _state == RecommendationState.loaded && _recommendation != null;
  bool get isEmptyWardrobe => _state == RecommendationState.emptyWardrobe;

  // ============================================
  // PUBLIC METHODS
  // ============================================

  /// Generate recommendation based on weather and wardrobe
  Future<void> generateRecommendation({
    required WeatherModel weather,
    required List<ClothingItem> clothingItems,
    CalendarEventModel? calendarEvent,
    RecommendationPreference preference = RecommendationPreference.balanced,
  }) async {
    try {
      _setState(RecommendationState.loading);
      _errorMessage = null;

      // Check if wardrobe is empty
      if (clothingItems.isEmpty) {
        _recommendation = RecommendationModel(
          outfitItems: [],
          explanation: 'Your wardrobe is empty. Add some clothing items to receive outfit recommendations.',
          weatherCondition: weather.condition,
          temperature: weather.temperature,
        );
        _setState(RecommendationState.emptyWardrobe);
        return;
      }

      // Generate recommendation using the service
      _recommendation = _recommendationService.generateRecommendation(
        weather: weather,
        availableClothing: clothingItems,
        calendarEvent: calendarEvent,
        preference: preference,
      );

      // Check if recommendation is valid
      if (_recommendation == null || !_recommendation!.isValid) {
        _errorMessage = _recommendation?.explanation ??
            'We could not find a perfect outfit from your current wardrobe. Add more clothing items and try again.';
        _setState(RecommendationState.error);
        return;
      }

      _setState(RecommendationState.loaded);
      print('Recommendation generated: ${_recommendation!.itemCount} items');
    } catch (e) {
      print('Error generating recommendation: $e');
      _errorMessage = 'Failed to generate recommendation: ${e.toString()}';
      _setState(RecommendationState.error);
    }
  }

  /// Refresh recommendation (regenerate with current data)
  Future<void> refreshRecommendation({
    required WeatherModel weather,
    required List<ClothingItem> clothingItems,
    CalendarEventModel? calendarEvent,
    RecommendationPreference preference = RecommendationPreference.balanced,
  }) async {
    await generateRecommendation(
      weather: weather,
      clothingItems: clothingItems,
      calendarEvent: calendarEvent,
      preference: preference,
    );
  }

  /// Clear current recommendation
  void clearRecommendation() {
    _recommendation = null;
    _errorMessage = null;
    _setState(RecommendationState.initial);
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    if (_state == RecommendationState.error) {
      _setState(RecommendationState.initial);
    }
  }

  // ============================================
  // FUTURE AI INTEGRATION
  // ============================================

  /// Generate recommendation using AI model
  /// This is prepared for future AI integration
  Future<void> generateAIRecommendation({
    required WeatherModel weather,
    required List<ClothingItem> clothingItems,
    CalendarEventModel? calendarEvent,
    RecommendationPreference preference = RecommendationPreference.balanced,
  }) async {
    try {
      _setState(RecommendationState.loading);
      _errorMessage = null;

      // Check if wardrobe is empty
      if (clothingItems.isEmpty) {
        _recommendation = RecommendationModel(
          outfitItems: [],
          explanation: 'Your wardrobe is empty. Add some clothing items to receive outfit recommendations.',
          weatherCondition: weather.condition,
          temperature: weather.temperature,
        );
        _setState(RecommendationState.emptyWardrobe);
        return;
      }

      final aiResult = await _aiService.recommendOutfit(
        weather: weather,
        wardrobe: clothingItems,
        calendarEvent: calendarEvent,
        preference: preference,
      );
      if (!aiResult.success) {
        _errorMessage = aiResult.message;
        _setState(RecommendationState.error);
        return;
      }

      // The backend only returns IDs from the submitted wardrobe. This second
      // lookup is a client-side guard that prevents invented items from showing.
      final selectedItems = clothingItems
          .where((item) => aiResult.itemIds.contains(item.clothingId?.toString()))
          .toList(growable: false);
      if (selectedItems.isEmpty) {
        _errorMessage = 'No suitable outfit could be found from your current wardrobe.';
        _setState(RecommendationState.error);
        return;
      }
      _recommendation = RecommendationModel(
        outfitItems: selectedItems,
        explanation: aiResult.reason,
        weatherCondition: weather.condition,
        temperature: weather.temperature,
        eventCategory: calendarEvent?.category,
        confidenceScore: aiResult.confidence,
        recommendationSource: 'pretrained-ai-backend',
        aiEventType: aiResult.eventType,
        aiWeatherSummary: aiResult.weatherSummary,
        missingItems: aiResult.missingItems,
        isCompleteOutfit: aiResult.isCompleteOutfit,
        purchaseRecommendations: aiResult.purchaseRecommendations,
      );

      _setState(RecommendationState.loaded);
    } on AiServiceException catch (error) {
      _errorMessage = error.message;
      _setState(RecommendationState.error);
    } catch (_) {
      _errorMessage = 'The AI recommendation could not be generated. Please retry.';
      _setState(RecommendationState.error);
    }
  }

  // ============================================
  // PRIVATE METHODS
  // ============================================

  /// Update state and notify listeners
  void _setState(RecommendationState newState) {
    _state = newState;
    notifyListeners();
  }

  /// Reset provider state
  void reset() {
    _state = RecommendationState.initial;
    _recommendation = null;
    _errorMessage = null;
    notifyListeners();
  }
}
