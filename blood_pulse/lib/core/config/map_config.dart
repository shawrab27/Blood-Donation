// Copyright (c) 2026 Nasim Uddin Shawrab. All rights reserved.
// Part of the Blood Pulse project — unauthorized copying or distribution prohibited.

/// Central MapConfig defining single source of truth for free OpenStreetMap tiles,
/// attribution, and user agent package name across all Flutter map widgets.
class MapConfig {
  MapConfig._();

  /// OpenStreetMap standard raster tile template.
  static const String osmTileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Standard app user-agent package name per OSM Tile Usage Policy.
  static const String osmUserAgentPackageName = 'com.bloodpulse.app';

  /// Required attribution string for OpenStreetMap.
  static const String osmAttribution = '© OpenStreetMap contributors';
}
