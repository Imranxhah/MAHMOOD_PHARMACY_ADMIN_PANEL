import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mahmoodpharmacy_admin_panel/screens/admin_webview_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On Android, we may need to request permissions early
  if (!kIsWeb && Platform.isAndroid) {
    await [
      Permission.camera,
      Permission.storage, // For older Android
      Permission.photos, // For newer Android (READ_MEDIA_IMAGES)
    ].request();
  }

  runApp(const MahmoodPharmacyAdminApp());
}

class MahmoodPharmacyAdminApp extends StatelessWidget {
  const MahmoodPharmacyAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Panel Mahmood Pharmacy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const AdminWebViewScreen(),
    );
  }
}
