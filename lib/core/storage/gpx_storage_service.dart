import '../models/route_model.dart';
import 'gpx_storage_io.dart' if (dart.library.html) 'gpx_storage_web.dart';

class GpxStorageService {
  /// Returns the directory where saved GPX routes are stored on device
  static Future<String?> getTrailsDirectoryPath() {
    return GpxPlatformStorage.getTrailsDirectoryPath();
  }

  /// Persists a RouteModel as a .gpx XML file on device storage
  static Future<bool> saveGpxToFile(RouteModel route) {
    return GpxPlatformStorage.saveGpxToFile(route);
  }

  /// Loads all saved .gpx files from device storage
  static Future<List<RouteModel>> loadAllSavedGpxRoutes() {
    return GpxPlatformStorage.loadAllSavedGpxRoutes();
  }

  /// Deletes a saved .gpx file from device storage
  static Future<bool> deleteGpxFile(String routeId) {
    return GpxPlatformStorage.deleteGpxFile(routeId);
  }
}
