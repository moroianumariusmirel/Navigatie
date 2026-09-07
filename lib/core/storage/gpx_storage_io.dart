import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/route_model.dart';
import '../routing/gpx_parser.dart';

class GpxPlatformStorage {
  static const String _subDirectory = 'trails';

  static Future<String?> getTrailsDirectoryPath() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final trailsDir = Directory('${docDir.path}/$_subDirectory');
      if (!await trailsDir.exists()) {
        await trailsDir.create(recursive: true);
      }
      return trailsDir.path;
    } catch (e) {
      debugPrint('[GpxStorageService] Error getting trails directory: $e');
      return null;
    }
  }

  static Future<bool> saveGpxToFile(RouteModel route) async {
    try {
      final dirPath = await getTrailsDirectoryPath();
      if (dirPath == null) return false;

      final safeName = route.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('$dirPath/$safeName.gpx');

      final gpxContent = GpxParser.exportToGpx(route);
      await file.writeAsString(gpxContent);
      debugPrint('[GpxStorageService] Saved GPX to: ${file.path}');
      return true;
    } catch (e) {
      debugPrint('[GpxStorageService] Error saving GPX file: $e');
      return false;
    }
  }

  static Future<List<RouteModel>> loadAllSavedGpxRoutes() async {
    try {
      final dirPath = await getTrailsDirectoryPath();
      if (dirPath == null) return [];

      final trailsDir = Directory(dirPath);
      if (!await trailsDir.exists()) return [];

      final entities = trailsDir.listSync();
      final loadedRoutes = <RouteModel>[];

      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.gpx')) {
          try {
            final content = await entity.readAsString();
            final route = GpxParser.parseGpx(
              content,
              fallbackName: entity.uri.pathSegments.last.replaceAll('.gpx', ''),
            );
            loadedRoutes.add(route);
          } catch (e) {
            debugPrint('[GpxStorageService] Error parsing saved file ${entity.path}: $e');
          }
        }
      }

      debugPrint('[GpxStorageService] Loaded ${loadedRoutes.length} saved GPX files from disk');
      return loadedRoutes;
    } catch (e) {
      debugPrint('[GpxStorageService] Error loading saved GPX files: $e');
      return [];
    }
  }

  static Future<bool> deleteGpxFile(String routeId) async {
    try {
      final dirPath = await getTrailsDirectoryPath();
      if (dirPath == null) return false;

      final safeName = routeId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final file = File('$dirPath/$safeName.gpx');
      if (await file.exists()) {
        await file.delete();
        debugPrint('[GpxStorageService] Deleted GPX file: ${file.path}');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[GpxStorageService] Error deleting GPX file: $e');
      return false;
    }
  }
}
