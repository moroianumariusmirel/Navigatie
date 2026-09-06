class WaypointModel {
  final int index;
  final String title;
  final String elevation;
  final String distance;
  final bool isApex;
  final String type;
  final String? description;

  const WaypointModel({
    required this.index,
    required this.title,
    required this.elevation,
    required this.distance,
    this.isApex = false,
    this.type = 'waypoint',
    this.description,
  });
}
