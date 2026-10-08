import 'package:latlong2/latlong.dart';

enum RegionDownloadState { notDownloaded, downloading, ready, failed }

class OfflineMapRegion {
  final String id;
  final String countryId;
  final String countryName;
  final String countryFlag;
  final String name;
  final String description;
  final double sizeMb;
  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;
  final RegionDownloadState state;
  final double downloadProgress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String? localPmtilesPath;
  final String downloadUrl;
  final bool hasCyclingProfiles;
  final bool hasHikingContours;
  final bool isCountryMaster;
  final int maxZoom;
  final String? errorMessage;

  const OfflineMapRegion({
    required this.id,
    required this.countryId,
    required this.countryName,
    required this.countryFlag,
    required this.name,
    required this.description,
    required this.sizeMb,
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
    this.state = RegionDownloadState.notDownloaded,
    this.downloadProgress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.localPmtilesPath,
    this.downloadUrl = '',
    this.hasCyclingProfiles = true,
    this.hasHikingContours = true,
    this.isCountryMaster = false,
    this.maxZoom = 14,
    this.errorMessage,
  });

  LatLng get center => LatLng((minLat + maxLat) / 2.0, (minLon + maxLon) / 2.0);

  bool contains(LatLng point) {
    return point.latitude >= minLat &&
        point.latitude <= maxLat &&
        point.longitude >= minLon &&
        point.longitude <= maxLon;
  }

  bool containsCoordinates(double lat, double lon) {
    return lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon;
  }

  OfflineMapRegion copyWith({
    RegionDownloadState? state,
    double? downloadProgress,
    int? downloadedBytes,
    int? totalBytes,
    String? localPmtilesPath,
    String? downloadUrl,
    int? maxZoom,
    String? errorMessage,
    double? sizeMb,
  }) {
    return OfflineMapRegion(
      id: id,
      countryId: countryId,
      countryName: countryName,
      countryFlag: countryFlag,
      name: name,
      description: description,
      sizeMb: sizeMb ?? this.sizeMb,
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
      state: state ?? this.state,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      localPmtilesPath: localPmtilesPath ?? this.localPmtilesPath,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      hasCyclingProfiles: hasCyclingProfiles,
      hasHikingContours: hasHikingContours,
      isCountryMaster: isCountryMaster,
      maxZoom: maxZoom ?? this.maxZoom,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'countryId': countryId,
      'state': state.name,
      'localPmtilesPath': localPmtilesPath,
      'sizeMb': sizeMb,
      'maxZoom': maxZoom,
    };
  }
}

class OfflineCountry {
  final String id;
  final String name;
  final String flag;
  final double totalSizeMb;
  final List<OfflineMapRegion> regions;

  const OfflineCountry({
    required this.id,
    required this.name,
    required this.flag,
    required this.totalSizeMb,
    required this.regions,
  });

  OfflineMapRegion? get masterRegion =>
      regions.where((r) => r.isCountryMaster).firstOrNull ?? regions.firstOrNull;

  List<OfflineMapRegion> get subRegions =>
      regions.where((r) => !r.isCountryMaster).toList();

  bool get isFullyDownloaded =>
      regions.isNotEmpty && regions.every((r) => r.state == RegionDownloadState.ready);

  bool get hasAnyDownloaded =>
      regions.any((r) => r.state == RegionDownloadState.ready);

  int get downloadedRegionsCount =>
      regions.where((r) => r.state == RegionDownloadState.ready).length;

  /// Dynamic total size calculated from sub-regions (or master pack if no sub-regions)
  double get effectiveTotalSizeMb {
    final sub = subRegions;
    if (sub.isEmpty) return totalSizeMb;
    return sub.fold(0.0, (acc, r) => acc + r.sizeMb);
  }
}

class OfflineTileManager {
  static const String cdnBaseUrl =
      'https://github.com/trailpulse/maps/releases/download/v1.0';
  static const String defaultManifestUrl =
      'https://raw.githubusercontent.com/trailpulse/maps/main/manifest.json';

  /// Comprehensive European map catalog for Cycling & Hiking with regional sub-packs
  static List<OfflineCountry> europeanCountries() {
    return [
      // 1. ROMANIA
      const OfflineCountry(
        id: 'ro',
        name: 'Romania',
        flag: '🇷🇴',
        totalSizeMb: 500.0,
        regions: [
          OfflineMapRegion(
            id: 'ro_all',
            countryId: 'ro',
            countryName: 'Romania',
            countryFlag: '🇷🇴',
            name: 'Romania (Entire Country Master)',
            description: 'Complete OSM vector basemap + Via Transilvanica + Carpathians network (Zoom 0-10)',
            sizeMb: 59.0,
            minLat: 43.6186,
            minLon: 20.2618,
            maxLat: 48.2654,
            maxLon: 29.7155,
            downloadUrl: '$cdnBaseUrl/romania_all.pmtiles',
            isCountryMaster: true,
            maxZoom: 10,
          ),
          OfflineMapRegion(
            id: 'ro_bucegi_brasov',
            countryId: 'ro',
            countryName: 'Romania',
            countryFlag: '🇷🇴',
            name: 'Bucegi Mountains & Brașov',
            description: 'Bucegi Plateau, Babele, Omu Peak, Postăvaru, Piatra Craiului, Sinaia & Brașov MTB',
            sizeMb: 8.3,
            minLat: 45.3000,
            minLon: 25.2500,
            maxLat: 45.7500,
            maxLon: 25.7500,
            downloadUrl: '$cdnBaseUrl/romania_bucegi_brasov.pmtiles',
            maxZoom: 15,
          ),
          OfflineMapRegion(
            id: 'ro_transylvania_carpathians',
            countryId: 'ro',
            countryName: 'Romania',
            countryFlag: '🇷🇴',
            name: 'Transylvania & Carpathian Arc',
            description: 'Bucegi, Făgăraș, Piatra Craiului, Apuseni, Brașov, Sibiu, Cluj singletrack',
            sizeMb: 135.0,
            minLat: 45.1000,
            minLon: 22.5000,
            maxLat: 47.1500,
            maxLon: 26.2000,
            downloadUrl: '$cdnBaseUrl/romania_transylvania_carpathians.pmtiles',
            maxZoom: 15,
          ),
          OfflineMapRegion(
            id: 'ro_muntenia_dobrogea',
            countryId: 'ro',
            countryName: 'Romania',
            countryFlag: '🇷🇴',
            name: 'Muntenia & Danube Delta',
            description: 'Bucharest, Prahova Valley, Dobrogea gravel routes, Danube Delta reserve',
            sizeMb: 152.0,
            minLat: 43.6000,
            minLon: 24.8000,
            maxLat: 45.6000,
            maxLon: 29.7200,
            downloadUrl: '$cdnBaseUrl/romania_muntenia_dobrogea.pmtiles',
            maxZoom: 15,
          ),
          OfflineMapRegion(
            id: 'ro_moldavia_bucovina',
            countryId: 'ro',
            countryName: 'Romania',
            countryFlag: '🇷🇴',
            name: 'Moldavia & Bucovina',
            description: 'Ceahlău National Park, Rarău, Suceava forest ways, Iași rolling hills',
            sizeMb: 110.0,
            minLat: 45.8000,
            minLon: 25.0000,
            maxLat: 48.2700,
            maxLon: 28.2500,
            downloadUrl: '$cdnBaseUrl/romania_moldavia_bucovina.pmtiles',
            maxZoom: 15,
          ),
          OfflineMapRegion(
            id: 'ro_banat_crisana',
            countryId: 'ro',
            countryName: 'Romania',
            countryFlag: '🇷🇴',
            name: 'Banat & Crișana',
            description: 'Danube Gorges (Cazane), Semenic, Cheile Nerei, Timișoara & Arad trails',
            sizeMb: 95.0,
            minLat: 44.5000,
            minLon: 20.2600,
            maxLat: 47.4000,
            maxLon: 23.0000,
            downloadUrl: '$cdnBaseUrl/romania_banat_crisana.pmtiles',
            maxZoom: 15,
          ),
        ],
      ),

      // 2. GERMANY
      const OfflineCountry(
        id: 'de',
        name: 'Germany',
        flag: '🇩🇪',
        totalSizeMb: 920.0,
        regions: [
          OfflineMapRegion(
            id: 'de_all',
            countryId: 'de',
            countryName: 'Germany',
            countryFlag: '🇩🇪',
            name: 'Germany (Entire Country Master)',
            description: 'Full German cycling network (D-Netz), Radwege & national hiking trails',
            sizeMb: 920.0,
            minLat: 47.2701,
            minLon: 5.8663,
            maxLat: 55.0583,
            maxLon: 15.0419,
            downloadUrl: '$cdnBaseUrl/germany_all.pmtiles',
            isCountryMaster: true,
          ),
          OfflineMapRegion(
            id: 'de_bavaria_alps',
            countryId: 'de',
            countryName: 'Germany',
            countryFlag: '🇩🇪',
            name: 'Bavaria & Bavarian Alps',
            description: 'Zugspitze, Allgäu, Berchtesgaden, Isar Radweg & Alpine MTB trails',
            sizeMb: 320.0,
            minLat: 47.2700,
            minLon: 9.0000,
            maxLat: 50.5600,
            maxLon: 13.8400,
            downloadUrl: '$cdnBaseUrl/germany_bavaria_alps.pmtiles',
          ),
          OfflineMapRegion(
            id: 'de_black_forest_baden',
            countryId: 'de',
            countryName: 'Germany',
            countryFlag: '🇩🇪',
            name: 'Black Forest & Baden-Württemberg',
            description: 'Schauinsland, Feldberg, Westweg trail, Rhine cycleway & Swabian Jura',
            sizeMb: 240.0,
            minLat: 47.5000,
            minLon: 7.5000,
            maxLat: 49.8000,
            maxLon: 10.5000,
            downloadUrl: '$cdnBaseUrl/germany_black_forest.pmtiles',
          ),
          OfflineMapRegion(
            id: 'de_central_highlands',
            countryId: 'de',
            countryName: 'Germany',
            countryFlag: '🇩🇪',
            name: 'Harz, Eifel & Central Highlands',
            description: 'Harz Brocken, Eifel volcanic trails, Sauerland bike parks, Rothaarsteig',
            sizeMb: 190.0,
            minLat: 49.8000,
            minLon: 6.0000,
            maxLat: 52.2000,
            maxLon: 12.0000,
            downloadUrl: '$cdnBaseUrl/germany_central_highlands.pmtiles',
          ),
        ],
      ),

      // 3. FRANCE
      const OfflineCountry(
        id: 'fr',
        name: 'France',
        flag: '🇫🇷',
        totalSizeMb: 1050.0,
        regions: [
          OfflineMapRegion(
            id: 'fr_all',
            countryId: 'fr',
            countryName: 'France',
            countryFlag: '🇫🇷',
            name: 'France (Entire Country Master)',
            description: 'Complete French national territory, GR walking trails & Voies Vertes',
            sizeMb: 1050.0,
            minLat: 41.3337,
            minLon: -5.1422,
            maxLat: 51.0890,
            maxLon: 9.5600,
            downloadUrl: '$cdnBaseUrl/france_all.pmtiles',
            isCountryMaster: true,
          ),
          OfflineMapRegion(
            id: 'fr_alps_mont_blanc',
            countryId: 'fr',
            countryName: 'France',
            countryFlag: '🇫🇷',
            name: 'French Alps & Mont Blanc',
            description: 'Chamonix, Tour du Mont Blanc, Vanoise, Col du Galibier & Écrins',
            sizeMb: 340.0,
            minLat: 44.0000,
            minLon: 5.5000,
            maxLat: 46.5000,
            maxLon: 7.2000,
            downloadUrl: '$cdnBaseUrl/france_alps.pmtiles',
          ),
          OfflineMapRegion(
            id: 'fr_pyrenees',
            countryId: 'fr',
            countryName: 'France',
            countryFlag: '🇫🇷',
            name: 'French Pyrenees & Occitanie',
            description: 'GR10 Trans-Pyrenean trail, Tourmalet, Gavarnie, Pic du Midi',
            sizeMb: 270.0,
            minLat: 42.4000,
            minLon: -1.8000,
            maxLat: 43.6000,
            maxLon: 3.2000,
            downloadUrl: '$cdnBaseUrl/france_pyrenees.pmtiles',
          ),
          OfflineMapRegion(
            id: 'fr_provence_cotedazur',
            countryId: 'fr',
            countryName: 'France',
            countryFlag: '🇫🇷',
            name: 'Provence & Côte d\'Azur',
            description: 'Mont Ventoux cycling climb, Verdon Gorges, Calanques trails',
            sizeMb: 210.0,
            minLat: 43.0000,
            minLon: 4.5000,
            maxLat: 44.5000,
            maxLon: 7.5000,
            downloadUrl: '$cdnBaseUrl/france_provence.pmtiles',
          ),
        ],
      ),

      // 4. ITALY
      const OfflineCountry(
        id: 'it',
        name: 'Italy',
        flag: '🇮🇹',
        totalSizeMb: 960.0,
        regions: [
          OfflineMapRegion(
            id: 'it_all',
            countryId: 'it',
            countryName: 'Italy',
            countryFlag: '🇮🇹',
            name: 'Italy (Entire Country Master)',
            description: 'Complete Italian Peninsula, Alps, Apennines, Sardinia & Sicily',
            sizeMb: 960.0,
            minLat: 36.6492,
            minLon: 6.6267,
            maxLat: 47.0921,
            maxLon: 18.5206,
            downloadUrl: '$cdnBaseUrl/italy_all.pmtiles',
            isCountryMaster: true,
          ),
          OfflineMapRegion(
            id: 'it_dolomites_alps',
            countryId: 'it',
            countryName: 'Italy',
            countryFlag: '🇮🇹',
            name: 'Dolomites & Northern Alps',
            description: 'Sella Ronda MTB, Tre Cime di Lavaredo, Stelvio Pass, Alta Via trails',
            sizeMb: 310.0,
            minLat: 45.7000,
            minLon: 9.8000,
            maxLat: 47.1000,
            maxLon: 13.0000,
            downloadUrl: '$cdnBaseUrl/italy_dolomites.pmtiles',
          ),
          OfflineMapRegion(
            id: 'it_tuscany_apennines',
            countryId: 'it',
            countryName: 'Italy',
            countryFlag: '🇮🇹',
            name: 'Tuscany & Florence (Verified Pack)',
            description: 'Florence, Chianti hills, L\'Eroica gravel routes & Arno valley trails',
            sizeMb: 6.6,
            minLat: 43.7000,
            minLon: 11.1500,
            maxLat: 43.8500,
            maxLon: 11.3500,
            downloadUrl: 'https://raw.githubusercontent.com/protomaps/PMTiles/main/spec/v3/protomaps(vector)ODbL_firenze.pmtiles',
          ),
        ],
      ),

      // 5. SWITZERLAND
      const OfflineCountry(
        id: 'ch',
        name: 'Switzerland',
        flag: '🇨🇭',
        totalSizeMb: 370.0,
        regions: [
          OfflineMapRegion(
            id: 'ch_all',
            countryId: 'ch',
            countryName: 'Switzerland',
            countryFlag: '🇨🇭',
            name: 'Switzerland (Entire Country Master)',
            description: 'Complete SwitzerlandMobility cycling & SAC Alpine hiking network',
            sizeMb: 370.0,
            minLat: 45.8180,
            minLon: 5.9559,
            maxLat: 47.8084,
            maxLon: 10.4921,
            downloadUrl: '$cdnBaseUrl/switzerland_all.pmtiles',
            isCountryMaster: true,
          ),
          OfflineMapRegion(
            id: 'ch_valais_zermatt',
            countryId: 'ch',
            countryName: 'Switzerland',
            countryFlag: '🇨🇭',
            name: 'Valais & Zermatt',
            description: 'Matterhorn, Haute Route, Aletsch Glacier, Val d\'Hérens',
            sizeMb: 140.0,
            minLat: 45.9000,
            minLon: 6.8000,
            maxLat: 46.6000,
            maxLon: 8.4000,
            downloadUrl: '$cdnBaseUrl/switzerland_valais.pmtiles',
          ),
          OfflineMapRegion(
            id: 'ch_bernese_oberland',
            countryId: 'ch',
            countryName: 'Switzerland',
            countryFlag: '🇨🇭',
            name: 'Bernese Oberland & Jungfrau',
            description: 'Eiger, Jungfraujoch, Lauterbrunnen, Grindelwald trail & passes',
            sizeMb: 125.0,
            minLat: 46.4000,
            minLon: 7.2000,
            maxLat: 47.0500,
            maxLon: 8.5000,
            downloadUrl: '$cdnBaseUrl/switzerland_bernese.pmtiles',
          ),
        ],
      ),

      // 6. AUSTRIA
      const OfflineCountry(
        id: 'at',
        name: 'Austria',
        flag: '🇦🇹',
        totalSizeMb: 410.0,
        regions: [
          OfflineMapRegion(
            id: 'at_all',
            countryId: 'at',
            countryName: 'Austria',
            countryFlag: '🇦🇹',
            name: 'Austria (Entire Country Master)',
            description: 'Complete Austrian Alpine network, Tauern bike path & Danube route',
            sizeMb: 410.0,
            minLat: 46.3723,
            minLon: 9.5307,
            maxLat: 49.0206,
            maxLon: 17.1607,
            downloadUrl: '$cdnBaseUrl/austria_all.pmtiles',
            isCountryMaster: true,
          ),
          OfflineMapRegion(
            id: 'at_tyrol_innsbruck',
            countryId: 'at',
            countryName: 'Austria',
            countryFlag: '🇦🇹',
            name: 'Tyrol & Vorarlberg',
            description: 'Innsbruck, Zillertal, Ötztal, Arlberg pass & bikeparks',
            sizeMb: 165.0,
            minLat: 46.8000,
            minLon: 9.7000,
            maxLat: 47.7000,
            maxLon: 12.8000,
            downloadUrl: '$cdnBaseUrl/austria_tyrol.pmtiles',
          ),
          OfflineMapRegion(
            id: 'at_salzburg_tauern',
            countryId: 'at',
            countryName: 'Austria',
            countryFlag: '🇦🇹',
            name: 'Salzburg & Hohe Tauern',
            description: 'Grossglockner High Alpine Road, Hohe Tauern National Park',
            sizeMb: 140.0,
            minLat: 46.9000,
            minLon: 12.0000,
            maxLat: 47.9500,
            maxLon: 14.2000,
            downloadUrl: '$cdnBaseUrl/austria_salzburg.pmtiles',
          ),
        ],
      ),

      // 7. SPAIN
      const OfflineCountry(
        id: 'es',
        name: 'Spain',
        flag: '🇪🇸',
        totalSizeMb: 890.0,
        regions: [
          OfflineMapRegion(
            id: 'es_all',
            countryId: 'es',
            countryName: 'Spain',
            countryFlag: '🇪🇸',
            name: 'Spain (Entire Country Master)',
            description: 'Camino de Santiago, Vías Verdes, Pyrenees, Sierra Nevada & Balearics',
            sizeMb: 890.0,
            minLat: 35.9468,
            minLon: -9.3015,
            maxLat: 43.7915,
            maxLon: 3.3223,
            downloadUrl: '$cdnBaseUrl/spain_all.pmtiles',
            isCountryMaster: true,
          ),
          OfflineMapRegion(
            id: 'es_pyrenees_catalonia',
            countryId: 'es',
            countryName: 'Spain',
            countryFlag: '🇪🇸',
            name: 'Spanish Pyrenees & Catalonia',
            description: 'Aigüestortes, Ordesa y Monte Perdido, Girona gravel trails',
            sizeMb: 260.0,
            minLat: 41.5000,
            minLon: -0.5000,
            maxLat: 42.9000,
            maxLon: 3.3000,
            downloadUrl: '$cdnBaseUrl/spain_pyrenees.pmtiles',
          ),
          OfflineMapRegion(
            id: 'es_picos_de_europa',
            countryId: 'es',
            countryName: 'Spain',
            countryFlag: '🇪🇸',
            name: 'Picos de Europa & Cantabria',
            description: 'Cares Gorge, Covadonga lakes, Angliru cycling climb, northern coast',
            sizeMb: 175.0,
            minLat: 42.8000,
            minLon: -5.5000,
            maxLat: 43.6000,
            maxLon: -3.8000,
            downloadUrl: '$cdnBaseUrl/spain_picos.pmtiles',
          ),
        ],
      ),

      // 8. UNITED KINGDOM
      const OfflineCountry(
        id: 'gb',
        name: 'United Kingdom',
        flag: '🇬🇧',
        totalSizeMb: 820.0,
        regions: [
          OfflineMapRegion(
            id: 'gb_all',
            countryId: 'gb',
            countryName: 'United Kingdom',
            countryFlag: '🇬🇧',
            name: 'United Kingdom (Entire Country Master)',
            description: 'National Cycle Network (NCN), National Trails, Scotland, Wales & England',
            sizeMb: 820.0,
            minLat: 49.8824,
            minLon: -8.6493,
            maxLat: 60.8547,
            maxLon: 1.7689,
            downloadUrl: '$cdnBaseUrl/uk_all.pmtiles',
            isCountryMaster: true,
          ),
          OfflineMapRegion(
            id: 'gb_scotland_highlands',
            countryId: 'gb',
            countryName: 'United Kingdom',
            countryFlag: '🇬🇧',
            name: 'Scottish Highlands & Skye',
            description: 'Ben Nevis, West Highland Way, Cairngorms & North Coast 500',
            sizeMb: 230.0,
            minLat: 56.0000,
            minLon: -7.5000,
            maxLat: 58.7000,
            maxLon: -2.8000,
            downloadUrl: '$cdnBaseUrl/uk_scotland.pmtiles',
          ),
          OfflineMapRegion(
            id: 'gb_lake_district_wales',
            countryId: 'gb',
            countryName: 'United Kingdom',
            countryFlag: '🇬🇧',
            name: 'Lake District & Snowdonia (Wales)',
            description: 'Scafell Pike, Helvellyn, Snowdon, Pennine Bridleway MTB route',
            sizeMb: 210.0,
            minLat: 52.5000,
            minLon: -4.5000,
            maxLat: 54.8000,
            maxLon: -2.2000,
            downloadUrl: '$cdnBaseUrl/uk_lakes_wales.pmtiles',
          ),
        ],
      ),

      // 9. NORWAY
      const OfflineCountry(
        id: 'no',
        name: 'Norway',
        flag: '🇳🇴',
        totalSizeMb: 460.0,
        regions: [
          OfflineMapRegion(
            id: 'no_all',
            countryId: 'no',
            countryName: 'Norway',
            countryFlag: '🇳🇴',
            name: 'Norway (Fjords, Jotunheimen & Lofoten)',
            description: 'Rallarvegen cycling path, Preikestolen, Trolltunga, DNT huts',
            sizeMb: 460.0,
            minLat: 57.9000,
            minLon: 4.5000,
            maxLat: 71.2000,
            maxLon: 31.1000,
            downloadUrl: '$cdnBaseUrl/norway_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),

      // 10. SWEDEN
      const OfflineCountry(
        id: 'se',
        name: 'Sweden',
        flag: '🇸🇪',
        totalSizeMb: 470.0,
        regions: [
          OfflineMapRegion(
            id: 'se_all',
            countryId: 'se',
            countryName: 'Sweden',
            countryFlag: '🇸🇪',
            name: 'Sweden (Kungsleden & Southern Trails)',
            description: 'Kungsleden King\'s Trail, Vasaloppsleden, Kattegattleden cycleway',
            sizeMb: 470.0,
            minLat: 55.3000,
            minLon: 11.0000,
            maxLat: 69.1000,
            maxLon: 24.2000,
            downloadUrl: '$cdnBaseUrl/sweden_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),

      // 11. POLAND
      const OfflineCountry(
        id: 'pl',
        name: 'Poland',
        flag: '🇵🇱',
        totalSizeMb: 580.0,
        regions: [
          OfflineMapRegion(
            id: 'pl_all',
            countryId: 'pl',
            countryName: 'Poland',
            countryFlag: '🇵🇱',
            name: 'Poland & Tatra Mountains',
            description: 'Tatra National Park (Zakopane), Green Velo route, Bieszczady',
            sizeMb: 580.0,
            minLat: 49.0000,
            minLon: 14.1000,
            maxLat: 54.8500,
            maxLon: 24.1500,
            downloadUrl: '$cdnBaseUrl/poland_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),

      // 12. CZECHIA
      const OfflineCountry(
        id: 'cz',
        name: 'Czechia',
        flag: '🇨🇿',
        totalSizeMb: 310.0,
        regions: [
          OfflineMapRegion(
            id: 'cz_all',
            countryId: 'cz',
            countryName: 'Czechia',
            countryFlag: '🇨🇿',
            name: 'Czechia & Krkonoše',
            description: 'Krkonoše Giant Mountains, Bohemian Switzerland, Rychleby singletracks',
            sizeMb: 310.0,
            minLat: 48.5500,
            minLon: 12.0900,
            maxLat: 51.0600,
            maxLon: 18.8600,
            downloadUrl: '$cdnBaseUrl/czechia_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),

      // 13. SLOVAKIA
      const OfflineCountry(
        id: 'sk',
        name: 'Slovakia',
        flag: '🇸🇰',
        totalSizeMb: 235.0,
        regions: [
          OfflineMapRegion(
            id: 'sk_all',
            countryId: 'sk',
            countryName: 'Slovakia',
            countryFlag: '🇸🇰',
            name: 'Slovakia (High & Low Tatras)',
            description: 'High Tatras alpine ridge, Slovak Paradise ladders, Malá Fatra',
            sizeMb: 235.0,
            minLat: 47.7300,
            minLon: 16.8300,
            maxLat: 49.6100,
            maxLon: 22.5700,
            downloadUrl: '$cdnBaseUrl/slovakia_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),

      // 14. SLOVENIA
      const OfflineCountry(
        id: 'si',
        name: 'Slovenia',
        flag: '🇸🇮',
        totalSizeMb: 120.0,
        regions: [
          OfflineMapRegion(
            id: 'si_all',
            countryId: 'si',
            countryName: 'Slovenia',
            countryFlag: '🇸🇮',
            name: 'Slovenia & Julian Alps',
            description: 'Triglav National Park, Soča Valley gravel, Lake Bled & Bohinj',
            sizeMb: 120.0,
            minLat: 45.4200,
            minLon: 13.3700,
            maxLat: 46.8800,
            maxLon: 16.6100,
            downloadUrl: '$cdnBaseUrl/slovenia_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),

      // 15. CROATIA
      const OfflineCountry(
        id: 'hr',
        name: 'Croatia',
        flag: '🇭🇷',
        totalSizeMb: 215.0,
        regions: [
          OfflineMapRegion(
            id: 'hr_all',
            countryId: 'hr',
            countryName: 'Croatia',
            countryFlag: '🇭🇷',
            name: 'Croatia (Dinaric Alps & Istria)',
            description: 'Parenzana cycling path, Velebit Premužić trail, Plitvice Lakes',
            sizeMb: 215.0,
            minLat: 42.3900,
            minLon: 13.4900,
            maxLat: 46.5500,
            maxLon: 19.4500,
            downloadUrl: '$cdnBaseUrl/croatia_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),

      // 16. GREECE
      const OfflineCountry(
        id: 'gr',
        name: 'Greece',
        flag: '🇬🇷',
        totalSizeMb: 380.0,
        regions: [
          OfflineMapRegion(
            id: 'gr_all',
            countryId: 'gr',
            countryName: 'Greece',
            countryFlag: '🇬🇷',
            name: 'Greece (Mount Olympus & Pindus)',
            description: 'Mount Olympus summit trail, Vikos Gorge, Peloponnese mountain passes',
            sizeMb: 380.0,
            minLat: 34.8000,
            minLon: 19.3700,
            maxLat: 41.7500,
            maxLon: 28.2500,
            downloadUrl: '$cdnBaseUrl/greece_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),

      // 17. PORTUGAL
      const OfflineCountry(
        id: 'pt',
        name: 'Portugal',
        flag: '🇵🇹',
        totalSizeMb: 275.0,
        regions: [
          OfflineMapRegion(
            id: 'pt_all',
            countryId: 'pt',
            countryName: 'Portugal',
            countryFlag: '🇵🇹',
            name: 'Portugal (Rota Vicentina & Serra da Estrela)',
            description: 'Rota Vicentina coastal trail, Peneda-Gerês National Park, N2 cycleway',
            sizeMb: 275.0,
            minLat: 36.9600,
            minLon: -9.5300,
            maxLat: 42.1500,
            maxLon: -6.1800,
            downloadUrl: '$cdnBaseUrl/portugal_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),

      // 18. NETHERLANDS
      const OfflineCountry(
        id: 'nl',
        name: 'Netherlands',
        flag: '🇳🇱',
        totalSizeMb: 210.0,
        regions: [
          OfflineMapRegion(
            id: 'nl_all',
            countryId: 'nl',
            countryName: 'Netherlands',
            countryFlag: '🇳🇱',
            name: 'Netherlands (National Fietsnetwerk)',
            description: 'Complete LF-routes, Knooppunten junction network, North Sea cycle route',
            sizeMb: 210.0,
            minLat: 50.7500,
            minLon: 3.3500,
            maxLat: 53.5500,
            maxLon: 7.2200,
            downloadUrl: '$cdnBaseUrl/netherlands_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),

      // 19. BELGIUM
      const OfflineCountry(
        id: 'be',
        name: 'Belgium',
        flag: '🇧🇪',
        totalSizeMb: 195.0,
        regions: [
          OfflineMapRegion(
            id: 'be_all',
            countryId: 'be',
            countryName: 'Belgium',
            countryFlag: '🇧🇪',
            name: 'Belgium (Ardennes & Flanders)',
            description: 'Ardennes MTB trails, High Fens plateau, Flanders cycling cobbles & RAVeL',
            sizeMb: 195.0,
            minLat: 49.5000,
            minLon: 2.5400,
            maxLat: 51.5000,
            maxLon: 6.4000,
            downloadUrl: '$cdnBaseUrl/belgium_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),

      // 20. IRELAND
      const OfflineCountry(
        id: 'ie',
        name: 'Ireland',
        flag: '🇮🇪',
        totalSizeMb: 225.0,
        regions: [
          OfflineMapRegion(
            id: 'ie_all',
            countryId: 'ie',
            countryName: 'Ireland',
            countryFlag: '🇮🇪',
            name: 'Ireland (Wild Atlantic Way & Wicklow)',
            description: 'Wild Atlantic Way, Kerry Way, Wicklow Way & greenways',
            sizeMb: 225.0,
            minLat: 51.4000,
            minLon: -10.5000,
            maxLat: 55.4000,
            maxLon: -5.9000,
            downloadUrl: '$cdnBaseUrl/ireland_all.pmtiles',
            isCountryMaster: true,
          ),
        ],
      ),
    ];
  }

  /// Backward-compatible sample regions getter
  static List<OfflineMapRegion> sampleRegions() {
    return europeanCountries().expand((c) => c.regions).toList();
  }
}
