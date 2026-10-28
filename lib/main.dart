import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en_IN');
  await Supabase.initialize(
    url: 'https://zxhnaujufheaoceajnka.supabase.co',
    anonKey: 'sb_publishable_adwRszZe0yYj1CViDcGvuQ_fF7CHp8h',
  );
  runApp(const RsEnterpriseApp());
}

class RsEnterpriseApp extends StatelessWidget {
  const RsEnterpriseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'RS Enterprise',
      debugShowCheckedModeBanner: false,
      initialRoute: Routes.clients,
      getPages: AppPages.pages,
    );
  }
}
