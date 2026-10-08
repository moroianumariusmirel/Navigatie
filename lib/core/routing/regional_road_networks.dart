import 'package:latlong2/latlong.dart';
import 'offline_routing_graph.dart';

/// Predefined key regional road networks for offline routing
class RegionalRoadNetworks {
  /// Muntenia & Danube Delta network (Bucharest, Ploiesti, Pitesti, Targoviste, Sinaia, Tulcea)
  static OfflineRoutingGraph getMunteniaNetwork() {
    final graph = OfflineRoutingGraph();

    // 1. Bucharest Hub
    graph.addNode(const RoutingNode(id: 101, lat: 44.4268, lon: 26.1025, elevationM: 80.0)); // Bucharest Center
    graph.addNode(const RoutingNode(id: 102, lat: 44.4800, lon: 26.0800, elevationM: 90.0)); // Bucharest North (Baneasa)
    graph.addNode(const RoutingNode(id: 103, lat: 44.4300, lon: 25.9800, elevationM: 85.0)); // Bucharest West (Militari A1)
    graph.addNode(const RoutingNode(id: 104, lat: 44.4500, lon: 26.1800, elevationM: 75.0)); // Bucharest East (Pantelimon A2)

    // 2. Ploiesti & Prahova Valley
    graph.addNode(const RoutingNode(id: 201, lat: 44.9367, lon: 26.0129, elevationM: 160.0)); // Ploiesti Center
    graph.addNode(const RoutingNode(id: 202, lat: 45.1200, lon: 25.7400, elevationM: 420.0)); // Campina
    graph.addNode(const RoutingNode(id: 203, lat: 45.3500, lon: 25.5500, elevationM: 860.0)); // Sinaia
    graph.addNode(const RoutingNode(id: 204, lat: 45.4150, lon: 25.5350, elevationM: 900.0)); // Busteni
    graph.addNode(const RoutingNode(id: 205, lat: 45.5000, lon: 25.5300, elevationM: 1030.0)); // Predeal

    // 3. Pitesti & Arges
    graph.addNode(const RoutingNode(id: 301, lat: 44.8565, lon: 24.8692, elevationM: 280.0)); // Pitesti
    graph.addNode(const RoutingNode(id: 302, lat: 45.1400, lon: 24.6700, elevationM: 430.0)); // Curtea de Arges
    graph.addNode(const RoutingNode(id: 303, lat: 45.3500, lon: 24.6300, elevationM: 1200.0)); // Transfagarasan South (Vidraru)

    // 4. Targoviste & Dambovita
    graph.addNode(const RoutingNode(id: 401, lat: 44.9254, lon: 25.4568, elevationM: 280.0)); // Targoviste
    graph.addNode(const RoutingNode(id: 402, lat: 45.1800, lon: 25.4400, elevationM: 520.0)); // Pucioasa / Fieni

    // 5. Danube Delta & Dobrogea Connectors
    graph.addNode(const RoutingNode(id: 501, lat: 44.5600, lon: 27.3600, elevationM: 40.0)); // Slobozia
    graph.addNode(const RoutingNode(id: 502, lat: 44.1800, lon: 28.6300, elevationM: 25.0)); // Constanta
    graph.addNode(const RoutingNode(id: 503, lat: 45.1800, lon: 28.8000, elevationM: 15.0)); // Tulcea
    graph.addNode(const RoutingNode(id: 504, lat: 45.1900, lon: 29.6500, elevationM: 2.0));  // Sulina (Danube Delta)

    const dist = Distance();

    void link(int a, int b, RoadType type, String name, [List<LatLng>? geom]) {
      final na = graph.nodes[a]!;
      final nb = graph.nodes[b]!;
      final d = dist.as(LengthUnit.Meter, na.toLatLng, nb.toLatLng);
      graph.addEdge(RoutingEdge(
        sourceId: a,
        targetId: b,
        distanceMeters: d,
        roadType: type,
        name: name,
        geometry: geom,
      ));
    }

    // Bucharest Arterials
    link(101, 102, RoadType.primary, 'DN1 / Sos. Bucuresti-Ploiesti');
    link(101, 103, RoadType.primary, 'Bd. Iuliu Maniu');
    link(101, 104, RoadType.primary, 'Sos. Pantelimon');

    // Bucharest <-> Ploiesti Corridor (DN1 & A3)
    link(102, 201, RoadType.primary, 'DN1 Bucuresti - Ploiesti', [
      const LatLng(44.6000, 26.0600),
      const LatLng(44.7500, 26.0400),
    ]);

    // Prahova Valley Trail/Roads (Ploiesti -> Campina -> Sinaia -> Busteni -> Predeal)
    link(201, 202, RoadType.primary, 'DN1 Valea Prahovei (Campina)', [
      const LatLng(45.0200, 25.8800),
    ]);
    link(202, 203, RoadType.primary, 'DN1 Campina - Sinaia', [
      const LatLng(45.2400, 25.6400),
      const LatLng(45.2900, 25.5900),
    ]);
    link(203, 204, RoadType.primary, 'DN1 Sinaia - Busteni', [
      const LatLng(45.3800, 25.5450),
    ]);
    link(204, 205, RoadType.primary, 'DN1 Busteni - Predeal', [
      const LatLng(45.4600, 25.5320),
    ]);

    // Bucharest <-> Pitesti (A1 Highway & Old Road DN7)
    link(103, 301, RoadType.primary, 'Autostrada A1 Bucuresti - Pitesti', [
      const LatLng(44.5200, 25.6500),
      const LatLng(44.6800, 25.2000),
    ]);

    // Pitesti <-> Curtea de Arges <-> Vidraru
    link(301, 302, RoadType.primary, 'DN7C Pitesti - Curtea de Arges');
    link(302, 303, RoadType.secondary, 'DN7C Transfagarasan Sud (Baraj Vidraru)', [
      const LatLng(45.2200, 24.6400),
      const LatLng(45.2800, 24.6300),
    ]);

    // Targoviste Connections
    link(101, 401, RoadType.secondary, 'DN71 Bucuresti - Targoviste', [
      const LatLng(44.6500, 25.7500),
    ]);
    link(401, 201, RoadType.secondary, 'DN72 Targoviste - Ploiesti', [
      const LatLng(44.9200, 25.7000),
    ]);
    link(401, 402, RoadType.secondary, 'DN71 Targoviste - Sinaia (via Cota 1000)', [
      const LatLng(45.1000, 25.4600),
    ]);
    link(402, 203, RoadType.track, 'Drum Forestier / Pasul Dichiu - Sinaia', [
      const LatLng(45.2800, 25.5000),
    ]);

    // East / Danube Delta Corridor
    link(104, 501, RoadType.primary, 'DN2A / A2 Bucuresti - Slobozia', [
      const LatLng(44.5000, 26.7000),
    ]);
    link(501, 502, RoadType.primary, 'A2 Slobozia - Constanta', [
      const LatLng(44.3000, 28.0000),
    ]);
    link(501, 503, RoadType.secondary, 'DN22A Slobozia - Harsova - Tulcea', [
      const LatLng(44.8500, 28.2000),
    ]);
    link(503, 504, RoadType.path, 'Canalul Sulina (Naval/Bicicleta Delta)', [
      const LatLng(45.1800, 29.2000),
    ]);

    return graph;
  }

  /// Transylvania & Bucegi-Brasov network
  static OfflineRoutingGraph getTransylvaniaNetwork() {
    final graph = OfflineRoutingGraph();

    // Brasov & Poiana Brasov
    graph.addNode(const RoutingNode(id: 601, lat: 45.6580, lon: 25.6012, elevationM: 580.0)); // Brasov Center
    graph.addNode(const RoutingNode(id: 602, lat: 45.5900, lon: 25.5500, elevationM: 1020.0)); // Poiana Brasov
    graph.addNode(const RoutingNode(id: 603, lat: 45.5450, lon: 25.3600, elevationM: 730.0));  // Rasnov / Bran
    graph.addNode(const RoutingNode(id: 604, lat: 45.5000, lon: 25.5300, elevationM: 1030.0)); // Predeal

    // Sibiu & Fagaras
    graph.addNode(const RoutingNode(id: 701, lat: 45.7983, lon: 24.1256, elevationM: 430.0)); // Sibiu
    graph.addNode(const RoutingNode(id: 702, lat: 45.8400, lon: 24.9700, elevationM: 430.0)); // Fagaras
    graph.addNode(const RoutingNode(id: 703, lat: 45.6000, lon: 24.6200, elevationM: 2034.0)); // Balea Lac (Transfagarasan)

    // Cluj-Napoca & Apuseni
    graph.addNode(const RoutingNode(id: 801, lat: 46.7712, lon: 23.6236, elevationM: 360.0)); // Cluj-Napoca
    graph.addNode(const RoutingNode(id: 802, lat: 46.5600, lon: 23.7800, elevationM: 330.0)); // Turda
    graph.addNode(const RoutingNode(id: 803, lat: 46.5800, lon: 23.1000, elevationM: 850.0)); // Apuseni (Belis/Garda)

    const dist = Distance();

    void link(int a, int b, RoadType type, String name, [List<LatLng>? geom]) {
      final na = graph.nodes[a]!;
      final nb = graph.nodes[b]!;
      final d = dist.as(LengthUnit.Meter, na.toLatLng, nb.toLatLng);
      graph.addEdge(RoutingEdge(
        sourceId: a,
        targetId: b,
        distanceMeters: d,
        roadType: type,
        name: name,
        geometry: geom,
      ));
    }

    // Brasov Hub
    link(601, 602, RoadType.secondary, 'Drumul Poienii (Brasov - Poiana Brasov)', [
      const LatLng(45.6300, 25.5800),
    ]);
    link(602, 603, RoadType.track, 'Poiana Brasov - Rasnov Trail');
    link(601, 603, RoadType.primary, 'DN73 Brasov - Cristian - Rasnov');
    link(601, 604, RoadType.primary, 'DN1 Brasov - Timisu de Jos - Predeal', [
      const LatLng(45.5800, 25.5600),
    ]);

    // Brasov <-> Fagaras <-> Sibiu Corridor
    link(601, 702, RoadType.primary, 'DN1 Brasov - Fagaras', [
      const LatLng(45.7500, 25.3000),
    ]);
    link(702, 701, RoadType.primary, 'DN1 Fagaras - Sibiu', [
      const LatLng(45.8200, 24.5500),
    ]);

    // Transfagarasan Crest (Balea Lac to Cartisoara)
    link(702, 703, RoadType.secondary, 'DN7C Transfagarasan Nord (Balea Cascada - Balea Lac)', [
      const LatLng(45.7000, 24.6100),
    ]);

    // Cluj & Apuseni Corridor
    link(801, 802, RoadType.primary, 'DN1 Cluj-Napoca - Turda');
    link(801, 803, RoadType.secondary, 'DN1R Cluj - Gilau - Belis-Fantanele', [
      const LatLng(46.7200, 23.3500),
    ]);

    return graph;
  }
}
