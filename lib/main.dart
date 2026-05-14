import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.instance.initialize(
    url: 'https://sdiqylrnphkqciukdfno.supabase.co',
    anonKey: 'sb_publishable_MEldUMkX87j3f4pgaaJC9A_cIi47WW8',
  );

  runApp(
    const ProviderScope(
      child: ChessRoguelikeApp(),
    ),
  );
}
