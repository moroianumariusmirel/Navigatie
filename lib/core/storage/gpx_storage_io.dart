import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/route_model.dart';
import '../routing/gpx_parser.dart';

class GpxPlatformStorage {
  static const String _subDirectory = 'trails';
  static Directory? testDirectory;

  static Future<String?> getTrailsDirectoryPath() async {
    try {
      if (testDirectory != null) {
        final trailsDir = Directory('${testDirectory!.path}/$_subDirectory');
        if (!await trailsDir.exists()) {
          await trailsDir.create(recursive: true);
        }
        return trailsDir.path;
      }
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

      final routeId = route.id.isNotEmpty ? route.id : 'saved_plan_${DateTime.now().millisecondsSinceEpoch}';
      final safeName = routeId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
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
        if (entity is File) {
          final pathLower = entity.path.toLowerCase();
          if (pathLower.endsWith('.gpx') ||
              pathLower.endsWith('.geojson') ||
              pathLower.endsWith('.json') ||
              pathLower.endsWith('.kml')) {
            try {
              final content = await entity.readAsString();
              final fileBaseName = entity.uri.pathSegments.last.replaceAll(RegExp(r'\.[^.]+$'), '');
              RouteModel route;
              if (content.trim().startsWith('{') || pathLower.endsWith('.json') || pathLower.endsWith('.geojson')) {
                route = GpxParser.parseGeoJson(content, fallbackName: fileBaseName);
              } else {
                route = GpxParser.parseGpx(
                  content,
                  fallbackName: fileBaseName,
                );
              }
              // Preserve the file base name as route id so deletion and deduplication work accurately
              loadedRoutes.add(route.copyWith(id: fileBaseName));
            } catch (e) {
              debugPrint('[GpxStorageService] Error parsing saved file ${entity.path}: $e');
            }
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
      const extensions = ['.gpx', '.geojson', '.json', '.kml'];
      for (final ext in extensions) {
        final file = File('$dirPath/$safeName$ext');
        if (await file.exists()) {
          await file.delete();
          debugPrint('[GpxStorageService] Deleted route file: ${file.path}');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[GpxStorageService] Error deleting file: $e');
      return false;
    }
  }
}
