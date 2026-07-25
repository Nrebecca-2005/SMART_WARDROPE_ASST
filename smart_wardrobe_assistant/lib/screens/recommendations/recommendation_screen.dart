// ============================================
// RECOMMENDATION_SCREEN.DART
// ============================================
// Screen for displaying outfit recommendations
//
// Purpose:
// - Show recommended outfit based on weather
// - Display weather information
// - Explain recommendation reasoning
// - Allow user to view clothing details
// ============================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/recommendation_provider.dart';
import '../../providers/weather_provider.dart';
import '../../providers/wardrobe_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/settings_provider.dart';
import '../../models/clothing_item.dart';
import '../../models/recommendation_model.dart';
import '../../models/weather_model.dart';

/// RecommendationScreen
/// Displays personalized outfit recommendations based on weather
class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  @override
  void initState() {
    super.initState();
    _initializeRecommendation();
  }

  /// Initialize recommendation by loading weather and wardrobe data
  Future<void> _initializeRecommendation() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
    final recommendationProvider = Provider.of<RecommendationProvider>(context, listen: false);
    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    // Set user ID for wardrobe
    final userId = authProvider.currentUser?.userId;
    if (userId != null) {
      await wardrobeProvider.setUserId(userId);
    }

    // Initialize weather if not already loaded
    if (!weatherProvider.hasData) {
      await weatherProvider.initializeWeather();
    }
    await calendarProvider.initialize();

    // Generate recommendation
    if (weatherProvider.hasData && wardrobeProvider.clothingItems.isNotEmpty) {
      await recommendationProvider.generateAIRecommendation(
        weather: weatherProvider.weather!,
        clothingItems: wardrobeProvider.clothingItems,
        calendarEvent: calendarProvider.selectedEvent,
        preference: settingsProvider.outfitPreference,
      );
    } else if (wardrobeProvider.clothingItems.isEmpty) {
      // Handle empty wardrobe
      recommendationProvider.clearRecommendation();
    }
  }

  /// Refresh recommendation
  Future<void> _refreshRecommendation() async {
    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
    final wardrobeProvider = Provider.of<WardrobeProvider>(context, listen: false);
    final recommendationProvider = Provider.of<RecommendationProvider>(context, listen: false);
    final calendarProvider = Provider.of<CalendarProvider>(context, listen: false);
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

    // Refresh weather
    await weatherProvider.refreshWeather();

    // Refresh wardrobe
    await wardrobeProvider.refreshWardrobe();
    await calendarProvider.refreshEvents();

    // Generate new recommendation
    if (weatherProvider.hasData) {
      await recommendationProvider.generateAIRecommendation(
        weather: weatherProvider.weather!,
        clothingItems: wardrobeProvider.clothingItems,
        calendarEvent: calendarProvider.selectedEvent,
        preference: settingsProvider.outfitPreference,
      );
    }
  }

  /// Navigate to clothing details
  void _navigateToClothingDetails(ClothingItem item) {
    Navigator.pushNamed(
      context,
      '/clothing-details',
      arguments: item,
    );
  }

  /// Format current date
  String _formatCurrentDate() {
    return DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // ============================================
      // APP BAR
      // ============================================
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Recommendations',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Refresh Button
          IconButton(
            icon: const Icon(
              Icons.refresh,
              color: AppColors.primary,
            ),
            onPressed: _refreshRecommendation,
            tooltip: 'Refresh Recommendation',
          ),
          const SizedBox(width: 8),
        ],
      ),

      // ============================================
      // BODY
      // ============================================
      body: RefreshIndicator(
        onRefresh: _refreshRecommendation,
        color: AppColors.primary,
        child: Consumer5<RecommendationProvider, WeatherProvider, WardrobeProvider, CalendarProvider, SettingsProvider>(
          builder: (context, recommendationProvider, weatherProvider, wardrobeProvider, calendarProvider, settingsProvider, child) {
            // ============================================
            // LOADING STATE
            // ============================================
            if (recommendationProvider.isLoading || weatherProvider.isLoading) {
              return _buildLoadingState();
            }

            // ============================================
            // WEATHER ERROR STATE
            // ============================================
            if (weatherProvider.hasError) {
              return _buildWeatherErrorState(weatherProvider);
            }

            // ============================================
            // EMPTY WARDROBE STATE
            // ============================================
            if (wardrobeProvider.clothingItems.isEmpty) {
              return _buildEmptyWardrobeState();
            }

            // ============================================
            // RECOMMENDATION ERROR STATE
            // ============================================
            if (recommendationProvider.hasError) {
              return _buildRecommendationErrorState(recommendationProvider);
            }

            // ============================================
            // MAIN CONTENT
            // ============================================
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page Header
                    _buildPageHeader(),

                    const SizedBox(height: 24),

                    // Weather Section
                    if (weatherProvider.hasData)
                      _buildWeatherSection(weatherProvider.weather!),

                    const SizedBox(height: 24),

                    _buildEventSection(calendarProvider),

                    if (recommendationProvider.hasRecommendation)
                      _buildAiContext(recommendationProvider.recommendation!),

                    const SizedBox(height: 24),

                    // Recommended Outfit Section
                    if (recommendationProvider.hasRecommendation)
                      _buildRecommendedOutfit(recommendationProvider.recommendation!),

                    // Outfit completeness + missing clothing categories
                    if (recommendationProvider.hasRecommendation) ...[
                      const SizedBox(height: 16),
                      _buildOutfitStatus(recommendationProvider.recommendation!),
                    ],

                    if (recommendationProvider.hasRecommendation &&
                        recommendationProvider.recommendation!.missingItems.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildMissingItems(recommendationProvider.recommendation!),
                    ],

                    const SizedBox(height: 24),

                    // Recommendation Explanation
                    if (recommendationProvider.hasRecommendation)
                      _buildRecommendationExplanation(recommendationProvider.recommendation!),

                    // Suggested purchase categories (missing items only)
                    if (recommendationProvider.hasRecommendation &&
                        recommendationProvider.recommendation!.purchaseRecommendations.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildSuggestedPurchases(recommendationProvider.recommendation!),
                    ],

                    if (recommendationProvider.hasRecommendation) ...[
                      const SizedBox(height: 16),
                      _buildMatchScore(recommendationProvider.recommendation!),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Build page header
  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Recommendation',
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatCurrentDate(),
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// Build weather section
  Widget _buildWeatherSection(WeatherModel weather) {
    return Card(
      elevation: 2,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.secondary,
              AppColors.secondaryDark,
            ],
          ),
        ),
        child: Row(
          children: [
            // Weather Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  weather.weatherEmoji,
                  style: const TextStyle(fontSize: 40),
                ),
              ),
            ),

            const SizedBox(width: 20),

            // Weather Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weather.cityName,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${weather.temperature.round()}°C',
                    style: GoogleFonts.poppins(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weather.condition,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
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

  Widget _buildEventSection(CalendarProvider provider) {
    final event = provider.selectedEvent;
    return Card(
      elevation: 1,
      child: ListTile(
        leading: const Icon(Icons.event, color: AppColors.primary),
        title: Text(event?.title ?? 'No calendar event selected'),
        subtitle: Text(event == null
            ? 'Recommendations will use your weather and wardrobe.'
            : '${event.isToday ? 'Today' : event.formattedDate} • ${event.timeRange}'),
        trailing: TextButton(
          onPressed: provider.hasPermission ? _showEventPicker : null,
          child: const Text('Change'),
        ),
      ),
    );
  }

  Widget _buildMatchScore(RecommendationModel recommendation) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.verified_outlined, color: AppColors.success),
            const SizedBox(width: 10),
            Text('${recommendation.matchPercentage}% Match',
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildAiContext(RecommendationModel recommendation) {
    if (recommendation.recommendationSource != 'pretrained-ai-backend') {
      return const SizedBox.shrink();
    }
    final confidence = recommendation.confidenceScore ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'AI analysis',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Pretrained model (BART-MNLI): event classified as '
                '${_formatEventType(recommendation.aiEventType)}.',
              ),
              Text('AI confidence: ${(confidence * 100).toStringAsFixed(1)}%'),
              Text(
                'Weather: ${recommendation.aiWeatherSummary ?? recommendation.weatherDisplay}',
              ),
              const SizedBox(height: 10),
              Text(
                'Application logic: selected clothing from your wardrobe that matches '
                'the event and current weather.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatEventType(String? eventType) {
    if (eventType == null || eventType.isEmpty) return 'General';
    return eventType[0].toUpperCase() + eventType.substring(1);
  }

  Future<void> _showEventPicker() async {
    final provider = context.read<CalendarProvider>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose an upcoming event')),
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('No event'),
              subtitle: const Text('Use weather and wardrobe only'),
              onTap: () {
                provider.selectEvent(null);
                Navigator.pop(sheetContext);
              },
            ),
            ...provider.upcomingEvents.map((event) => ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(event.title),
                  subtitle: Text('${event.formattedDate} • ${event.timeRange}'),
                  selected: provider.selectedEvent?.id == event.id,
                  onTap: () {
                    provider.selectEvent(event);
                    Navigator.pop(sheetContext);
                  },
                )),
          ],
        ),
      ),
    );
    if (mounted) await _refreshRecommendation();
  }

  /// Build recommended outfit section
  Widget _buildRecommendedOutfit(RecommendationModel recommendation) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          'Recommended Outfit',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),

        const SizedBox(height: 16),

        // Outfit Items Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: recommendation.outfitItems.length,
          itemBuilder: (context, index) {
            final item = recommendation.outfitItems[index];
            return _buildClothingItemCard(item);
          },
        ),
      ],
    );
  }

  /// Build outfit completeness badge (Complete Outfit vs Missing Items)
  Widget _buildOutfitStatus(RecommendationModel recommendation) {
    final isComplete = recommendation.isCompleteOutfit;
    final color = isComplete ? AppColors.success : AppColors.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(
            isComplete ? Icons.check_circle_outline : Icons.info_outline,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isComplete
                  ? 'Complete Outfit — everything you need is in your wardrobe.'
                  : 'Missing Items — some pieces are needed to complete this outfit.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build the list of missing clothing categories (not real products)
  Widget _buildMissingItems(RecommendationModel recommendation) {
    return Card(
      elevation: 2,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checkroom_outlined, color: AppColors.warning),
                const SizedBox(width: 8),
                Text(
                  'Missing Items',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendation.missingItems.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _titleCase(item.category),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (item.reason.isNotEmpty)
                      Text(
                        item.reason,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build suggested purchase categories. These are clothing categories to
  /// consider — not real products, prices, shops, or links.
  Widget _buildSuggestedPurchases(RecommendationModel recommendation) {
    return Card(
      elevation: 2,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Suggested Purchases',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Clothing categories to consider adding to your wardrobe.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ...recommendation.purchaseRecommendations.map(
              (rec) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Consider adding ${_titleCase(rec.category)} to your wardrobe.',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (rec.priority != null) _buildPriorityChip(rec.priority!),
                      ],
                    ),
                    if (rec.reason.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        rec.reason,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String priority) {
    final color = switch (priority.toLowerCase()) {
      'high' => AppColors.error,
      'medium' => AppColors.warning,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priority.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String _titleCase(String value) {
    if (value.trim().isEmpty) return value;
    return value
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  /// Build clothing item card
  Widget _buildClothingItemCard(ClothingItem item) {
    return GestureDetector(
      onTap: () => _navigateToClothingDetails(item),
      child: Card(
        elevation: 2,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: _buildClothingImage(item),
              ),
            ),

            // Item Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.clothingName,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.categoryName ?? 'Clothing',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build clothing image
  Widget _buildClothingImage(ClothingItem item) {
    final imageFile = File(item.imagePath);

    if (imageFile.existsSync()) {
      return Image.file(
        imageFile,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    } else {
      return _buildPlaceholderImage();
    }
  }

  /// Build placeholder image
  Widget _buildPlaceholderImage() {
    return Container(
      color: AppColors.background,
      child: Center(
        child: Icon(
          Icons.checkroom,
          size: 48,
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  /// Build recommendation explanation
  Widget _buildRecommendationExplanation(RecommendationModel recommendation) {
    return Card(
      elevation: 2,
      shadowColor: AppColors.shadow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: AppColors.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Why this outfit?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              recommendation.explanation,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Generating your outfit...',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Build weather error state
  Widget _buildWeatherErrorState(WeatherProvider weatherProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to load weather',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              weatherProvider.errorMessage ?? 'Please check your connection',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshRecommendation,
              icon: const Icon(Icons.refresh),
              label: Text(
                'Try Again',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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

  /// Build empty wardrobe state
  Widget _buildEmptyWardrobeState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.checkroom,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Your wardrobe is empty',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add some clothing items to receive outfit recommendations.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, '/wardrobe');
              },
              icon: const Icon(Icons.add),
              label: Text(
                'Go to Wardrobe',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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

  /// Build recommendation error state
  Widget _buildRecommendationErrorState(RecommendationProvider recommendationProvider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 48,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Unable to generate recommendation',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              recommendationProvider.errorMessage ?? 'Please try again',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _refreshRecommendation,
              icon: const Icon(Icons.refresh),
              label: Text(
                'Try Again',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
