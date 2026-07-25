import 'package:flutter/material.dart';

import 'package:flutter_application_1/screens/camera/camera_screen.dart';
import 'package:camera/camera.dart';

import 'package:provider/provider.dart';
import '../../providers/weather_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../services/greeting_service.dart';
import '../../widgets/profile_avatar.dart';
import '../../widgets/calendar_event_card.dart';
import '../../core/constants/app_colors.dart';


class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _selectedIndex = 0;
  
  // Mock data - Replace with actual data from database/API
  final bool isNewUser = true; // Set to false for existing user state

  @override
  void initState() {
    super.initState();
    // Initialize weather when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeatherProvider>().initializeWeather();
      // This checks the existing permission only; it never prompts from Home.
      context.read<CalendarProvider>().initialize();
      
      // Initialize profile provider with current user ID
      final authProvider = context.read<AuthProvider>();
      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        context.read<ProfileProvider>().setUserId(authProvider.currentUser!.userId);
      }
    });
  }
  
  void _onBottomNavTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    // Navigate to different screens based on index
    switch (index) {
      case 0:
        // Already on home
        break;
      case 1:
        Navigator.of(context).pushNamed('/wardrobe');
        break;
      case 2:
        Navigator.of(context).pushNamed('/add-clothing');
        break;
      case 3:
        Navigator.of(context).pushNamed('/suggestions');
        break;
      case 4:
        Navigator.of(context).pushNamed('/profile');
        break;
    }
  }
  Future<void> _navigateToCamera() async {
    // 1. Fetch available cameras on the device dynamically
    WidgetsFlutterBinding.ensureInitialized();
    final List<CameraDescription> availableDeviceCameras = await availableCameras();

    // 2. Safely jump to your camera screen, passing the device cameras along
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(cameras: availableDeviceCameras),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Menu',
            offset: const Offset(0, 52),
            elevation: 5,
            color: AppColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            icon: const Icon(Icons.menu_rounded, color: AppColors.textPrimary),
            onSelected: (route) => Navigator.of(context).pushNamed(route),
            itemBuilder: (context) => const [
              PopupMenuItem(value: '/settings', child: _HomeMenuItem(icon: Icons.settings_outlined, label: 'Settings')),
              PopupMenuItem(value: '/calendar', child: _HomeMenuItem(icon: Icons.calendar_month_outlined, label: 'Calendar')),
              PopupMenuItem(value: '/style-tips', child: _HomeMenuItem(icon: Icons.lightbulb_outline, label: 'Style Tips')),
              PopupMenuItem(value: '/outfit-history', child: _HomeMenuItem(icon: Icons.shopping_bag_outlined, label: 'Outfit History')),
              PopupMenuItem(value: '/activity-history', child: _HomeMenuItem(icon: Icons.history, label: 'Activity History')),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main Content (Scrollable)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Greeting and Profile
                    _buildHeader(),
                    
                    const SizedBox(height: 20),
                    
                    // Search Bar
                    _buildSearchBar(),
                    
                    const SizedBox(height: 20),
                    
                    // Weather Card
                    _buildWeatherCard(),

                    const SizedBox(height: 24),

                    // Compact calendar context, when the user has opted in.
                    _buildNextEventSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Conditional Content based on user state
                    if (isNewUser) ...[
                      _buildNewUserContent(),
                    ] else ...[
                      _buildExistingUserContent(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  /// ============================================
  /// HEADER SECTION
  /// ============================================
  Widget _buildHeader() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Get dynamic greeting
        final greeting = GreetingService.getGreetingWithName(
          authProvider.currentUser?.firstName,
        );
        final userInitials = authProvider.currentUser?.initials ?? 'G';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (authProvider.isAuthenticated)
                    Text(
                      authProvider.currentUser!.firstName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Profile Photo with ProfileAvatar widget
            ProfileAvatar(
              radius: 28,
              initials: userInitials,
              showCameraIcon: true,
            ),
          ],
        );
      },
    );
  }

  /// ============================================
  /// SEARCH BAR
  /// ============================================
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        readOnly: true,
        decoration: InputDecoration(
          hintText: 'Search your wardrobe...',
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 16,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF6B7280),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        onTap: () {
          // Open the dedicated wardrobe search screen.
          Navigator.of(context).pushNamed('/search');
        },
      ),
    );
  }

  /// ============================================
  /// WEATHER CARD
  /// ============================================
  Widget _buildWeatherCard() {
    return Consumer<WeatherProvider>(
      builder: (context, weatherProvider, child) {
        // Loading state
        if (weatherProvider.isLoading && !weatherProvider.hasData) {
          return Card(
            elevation: 0,
            color: const Color(0xFFFEF3C7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Padding(
              padding: EdgeInsets.all(20.0),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                ),
              ),
            ),
          );
        }

        // Error state (with cached data fallback)
        if (weatherProvider.hasError && !weatherProvider.hasData) {
          return Card(
            elevation: 0,
            color: const Color(0xFFFEF3C7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off,
                    size: 48,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    weatherProvider.errorMessage ?? 'Unable to fetch weather',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      weatherProvider.refreshWeather();
                    },
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text('Retry'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Location denied state
        if (weatherProvider.isLocationDenied) {
          return Card(
            elevation: 0,
            color: const Color(0xFFFEF3C7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const Icon(
                    Icons.location_off,
                    size: 48,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Location access required',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weatherProvider.errorMessage ?? 'Please grant location permission to see weather',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      await weatherProvider.requestLocationPermission();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Grant Permission',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Success state with weather data
        final weather = weatherProvider.weather;
        if (weather != null) {
          return Card(
            elevation: 0,
            color: const Color(0xFFFEF3C7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  // Weather Icon
                  Text(
                    weather.weatherEmoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(width: 16),
                  // Weather Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              weather.temperatureDisplay,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const Spacer(),
                            if (weatherProvider.isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF2563EB),
                                  ),
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(Icons.refresh, size: 20),
                                onPressed: () {
                                  weatherProvider.refreshWeather();
                                },
                                color: const Color(0xFF6B7280),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        Text(
                          weather.condition,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          weather.friendlyDescription,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          weather.cityName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                            fontStyle: FontStyle.italic,
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

        // Default fallback
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildNextEventSection() {
    return Consumer<CalendarProvider>(
      builder: (context, calendarProvider, child) {
        final event = calendarProvider.nextEvent;
        if (!calendarProvider.hasPermission || event == null) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Next Event',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 10),
            CalendarEventCard(
              event: event,
              isCompact: true,
              onTap: () => Navigator.of(context).pushNamed('/calendar'),
            ),
          ],
        );
      },
    );
  }

  /// ============================================
  /// NEW USER CONTENT (State 1)
  /// ============================================
  Widget _buildNewUserContent() {
    return Column(
      children: [
        // Wardrobe Summary
        _buildSectionCard(
          title: 'Wardrobe Summary',
          child: Column(
            children: [
              const Icon(
                Icons.checkroom_outlined,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your wardrobe is empty. Start',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'by adding your first clothing',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'item.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _navigateToCamera,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    'Add Your First Clothing',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Today's Outfit
        _buildSectionCard(
          title: "Today's Outfit",
          child: Column(
            children: [
              const Icon(
                Icons.camera_alt_outlined,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 12),
              const Text(
                'No outfit recommendations yet. Add',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'clothes to receive personalized',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'suggestions.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF6B7280),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ============================================
  /// EXISTING USER CONTENT (State 2)
  /// ============================================
  Widget _buildExistingUserContent() {
    return Column(
      children: [
        // Wardrobe Summary
        _buildSectionCard(
          title: 'Wardrobe Summary',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('15', 'Tops'),
              _buildStatItem('8', 'Bottoms'),
              _buildStatItem('5', 'Shoes'),
              _buildStatItem('3', 'Accessories'),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Today's Outfit Recommendation
        _buildSectionCard(
          title: "Today's Outfit",
          child: Column(
            children: [
              // Outfit preview images would go here
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'Outfit Preview',
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Blue Shirt + Black Jeans + White Sneakers',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Perfect for today\'s weather',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Recent Outfit History
        _buildSectionCard(
          title: 'Recent Outfit History',
          child: Column(
            children: [
              _buildHistoryItem('Yesterday', 'Black T-Shirt + Jeans'),
              const Divider(height: 20),
              _buildHistoryItem('2 days ago', 'White Shirt + Chinos'),
              const Divider(height: 20),
              _buildHistoryItem('3 days ago', 'Hoodie + Joggers'),
            ],
          ),
        ),
      ],
    );
  }

  /// ============================================
  /// HELPER WIDGETS
  /// ============================================
  Widget _buildSectionCard({
    required String title,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(String date, String outfit) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.checkroom,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                outfit,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Color(0xFF9CA3AF),
        ),
      ],
    );
  }

  /// ============================================
  /// BOTTOM NAVIGATION BAR
  /// ============================================
  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onBottomNavTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF2563EB),
      unselectedItemColor: const Color(0xFF6B7280),
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.checkroom),
          label: 'Wardrobe',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_circle_outline),
          label: 'Add',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.lightbulb_outline),
          label: 'Suggestions',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}

class _HomeMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HomeMenuItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 22),
            const SizedBox(width: 14),
            Text(label, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15)),
          ],
        ),
      );
}
