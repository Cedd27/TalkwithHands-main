import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart'; // Import para sa Firebase Core
import 'firebase_options.dart'; // Import para sa auto-generated configuration
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/background_music_service.dart';
import 'services/activity_time_service.dart';
import 'screens/splash_screen.dart';
import 'screens/reset_password_screen.dart';
import 'ui/background_music_region.dart';

void main() async {
  // Sinisigurado nito na ang lahat ng plugins (tulad ng Firebase) ay naka-initialize
  // bago tumakbo ang runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Dito tinatawag ang configuration na ginawa ng 'flutterfire configure' command
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Loads env values (e.g., API_BASE_URL)
  await dotenv.load(fileName: 'lib/.env');
  ActivityTimeService.instance.start();

  // Status bar configuration para sa malinis na UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  

  runApp(const TalkWithHandsApp());
}

class TalkWithHandsApp extends StatelessWidget {
  const TalkWithHandsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Talk with Hands',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor:
            Colors.black, // Swak sa iyong 2D cartoon/glossy aesthetic
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF36D7E7), // Ang iyong primary theme color
          brightness: Brightness.dark,
        ),
        textTheme: ThemeData.dark().textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
      builder: (context, child) {
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            if (child != null) child,
            const Positioned(
              right: 14,
              bottom: 14,
              width: 52,
              height: 52,
              child: SafeArea(
                top: false,
                left: false,
                minimum: EdgeInsets.zero,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: MusicToggleButton(),
                ),
              ),
            ),
          ],
        );
      },
      // Ang SplashScreen ang unang lalabas bago mag-login
      home: const SplashScreen(),
      navigatorObservers: [appRouteObserver],
      onGenerateRoute: (settings) {
        final uri = Uri.tryParse(settings.name ?? '');
        if (uri != null && uri.path == '/reset-password') {
          return MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              initialEmail: uri.queryParameters['email'],
              initialToken: uri.queryParameters['token'],
            ),
          );
        }
        return null;
      },
    );
  }
}
