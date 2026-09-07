import 'package:flutter/foundation.dart';
import '../models/route_model.dart';

class GpxPlatformStorage {
  static Future<String?> getTrailsDirectoryPath() async {
    return null;
  }

  static Future<bool> saveGpxToFile(RouteModel route) async {
    debugPrint('[GpxStorageService] Web platform: stored route in memory session: ${route.name}');
    return true;
  }

  static Future<List<RouteModel>> loadAllSavedGpxRoutes() async {
    return [];
  }

  static Future<bool> deleteGpxFile(String routeId) async {
    return true;
  }
}
