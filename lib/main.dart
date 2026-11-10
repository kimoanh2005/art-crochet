import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  if (supabaseUrl.isEmpty || supabaseKey.isEmpty) {
    runApp(const SupabaseConfigErrorApp());
    return;
  }

  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseKey);

  runApp(const CrochetStudioApp());
}

class SupabaseConfigErrorApp extends StatelessWidget {
  const SupabaseConfigErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Chưa cấu hình Supabase. '
              'Hãy chạy ứng dụng với SUPABASE_URL '
              'và SUPABASE_PUBLISHABLE_KEY.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
