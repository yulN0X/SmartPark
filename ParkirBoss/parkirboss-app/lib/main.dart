. . art';
import 'package:flutter/services.dart';
import 'presentation/themes/app_theme.dart';
import 'presentation/navigation/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait — optimized for parking kiosk-style mobile UX
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const ParkirBossApp());
}

class ParkirBossApp extends StatelessWidget {
  const ParkirBossApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parkir Boss',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRouter.onboarding,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
