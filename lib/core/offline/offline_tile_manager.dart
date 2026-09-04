enum RegionDownloadState { notDownloaded, downloading, ready }

class OfflineMapRegion {
  final String id;
  final String name;
  final String description;
  final double sizeMb;
  final RegionDownloadState state;
  final double downloadProgress; // 0.0 to 1.0
  final String? localPmtilesPath;

  const OfflineMapRegion({
    required this.id,
    required this.name,
    required this.description,
    required this.sizeMb,
    this.state = RegionDownloadState.notDownloaded,
    this.downloadProgress = 0.0,
    this.localPmtilesPath,
  });

  OfflineMapRegion copyWith({
    RegionDownloadState? state,
    double? downloadProgress,
    String? localPmtilesPath,
  }) {
    return OfflineMapRegion(
      id: id,
      name: name,
      description: description,
      sizeMb: sizeMb,
      state: state ?? this.state,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localPmtilesPath: localPmtilesPath ?? this.localPmtilesPath,
    );
  }
}

class OfflineTileManager {
  static List<OfflineMapRegion> sampleRegions() {
    return [
      const OfflineMapRegion(
        id: 'black_forest_de',
        name: 'Black Forest & Schauinsland',
        description: 'OSM Topo + 10m Contours + Valhalla MTB/Gravel routing',
        sizeMb: 142.5,
        state: RegionDownloadState.ready,
        downloadProgress: 1.0,
      ),
      const OfflineMapRegion(
        id: 'swiss_alps_valais',
        name: 'Swiss Alps (Valais / Zermatt)',
        description: 'SAC Hiking Trails + Glaciers + 5m DEM Hillshading',
        sizeMb: 285.0,
        state: RegionDownloadState.notDownloaded,
      ),
      const OfflineMapRegion(
        id: 'dolomites_it',
        name: 'Italian Dolomites (Sella Ronda)',
        description: 'MTB Enduro singletrack + Alpine Huts & Springs',
        sizeMb: 198.0,
        state: RegionDownloadState.notDownloaded,
      ),
    ];
  }
}
