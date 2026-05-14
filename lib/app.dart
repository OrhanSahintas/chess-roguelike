import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'routing/app_router.dart';
import 'ui/theme/app_theme.dart';

class ChessRoguelikeApp extends StatelessWidget {
  const ChessRoguelikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Chess Roguelike',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: AppRouter.router,
      builder: (context, child) {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: Color(0xFF0B0C10),
            systemNavigationBarIconBrightness: Brightness.light,
          ),
        );
        return child!;
      },
    );
  }
}
