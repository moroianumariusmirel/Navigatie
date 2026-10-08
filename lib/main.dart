import 'package:flutter/material.dart';
import 'app.dart';
import 'core/offline/offline_download_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OfflineDownloadService().initialize();
  runApp(const TrailPulseApp());
}
