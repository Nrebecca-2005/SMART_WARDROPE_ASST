// Testing my first Git commit!
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';

import 'core/themes/app_theme.dart';
import 'core/themes/dark_theme.dart';

import 'screens/splash/splash_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/home/home_dashboard_screen.dart';
import 'screens/wardrobe/wardrobe_screen.dart';
import 'screens/wardrobe/add_clothing_screen.dart';
import 'screens/wardrobe/clothing_details_screen.dart';
import 'screens/camera/camera_screen.dart';
import 'screens/camera/background_removal_preview_screen.dart';
import 'screens/recommendations/recommendation_screen.dart';
import 'screens/shopping_recommendations/shopping_recommendations_screen.dart';
import 'screens/calendar/calendar_screen.dart';
import 'screens/settings/settings_screen.dart';
import 'screens/home/feature_placeholder_screen.dart';

import 'models/clothing_item.dart';

import 'database/database_helper.dart';

import 'providers/weather_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/wardrobe_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/recommendation_provider.dart';
import 'providers/shopping_recommendation_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database
  await DatabaseHelper.instance.initDatabase();

  // Get available cameras
  final cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({
    super.key,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WeatherProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => WardrobeProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => RecommendationProvider()),
        ChangeNotifierProvider(create: (_) => ShoppingRecommendationProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()..initialize()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
        title: 'Smart Wardrobe Assistant',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: DarkTheme.theme,
        themeMode: themeProvider.themeMode,
        initialRoute: '/',
        onGenerateRoute: (settings) {
          // Handle routes with arguments
          if (settings.name == '/clothing-details') {
            final clothingItem = settings.arguments as ClothingItem;
            return MaterialPageRoute(
              builder: (context) => ClothingDetailsScreen(
                clothingItem: clothingItem,
              ),
            );
          }

          if (settings.name == '/add-clothing') {
            return MaterialPageRoute(
              builder: (context) => AddClothingScreen(
                initialImagePath: settings.arguments as String?,
              ),
            );
          }

          if (settings.name == '/background-removal-preview') {
            return MaterialPageRoute(
              builder: (context) => BackgroundRemovalPreviewScreen(
                originalImagePath: settings.arguments as String,
              ),
            );
          }

          // Return null for routes handled by the routes map
          return null;
        },
        routes: {
          '/': (context) => const SplashScreen(),

          '/onboarding': (context) => const OnboardingScreen(),

          '/login': (context) => const LoginScreen(),

          '/register': (context) => const RegisterScreen(),

          '/forgot-password': (context) =>
              const ForgotPasswordScreen(),

          '/home': (context) => const HomeDashboardScreen(),

          // Camera
          '/camera': (context) => CameraScreen(cameras: cameras),

          // Wardrobe
          '/wardrobe': (context) => const WardrobeScreen(),

          '/otp-verification': (context) =>
              const MyHomePage(title: 'OTP Verification Screen'),

          '/edit-clothing': (context) =>
              const MyHomePage(title: 'Edit Clothing Screen'),

          '/suggestions': (context) =>
              const RecommendationScreen(),
          
          '/recommendations': (context) =>
              const RecommendationScreen(),

          '/history': (context) =>
              const MyHomePage(title: 'History Screen'),

          '/shopping-recommendations': (context) =>
              const ShoppingRecommendationsScreen(),

          '/calendar': (context) => const CalendarScreen(),

          '/settings': (context) => const SettingsScreen(),

          '/style-tips': (context) => const FeaturePlaceholderScreen(
                title: 'Style Tips',
                icon: Icons.lightbulb_outline,
                message: 'Style tips will appear here as your wardrobe grows.',
              ),

          '/outfit-history': (context) => const FeaturePlaceholderScreen(
                title: 'Outfit History',
                icon: Icons.shopping_bag_outlined,
                message: 'Your saved outfit history will appear here.',
              ),

          '/activity-history': (context) => const FeaturePlaceholderScreen(
                title: 'Activity History',
                icon: Icons.history,
                message: 'Your wardrobe activity will appear here.',
              ),

          '/profile': (context) => const ProfileScreen(),


          '/search': (context) => const WardrobeScreen(searchMode: true),
        },
        ),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
