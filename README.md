# PharmaFinder Customer Mobile App

Flutter customer app for finding medicines, comparing pharmacy availability
and prices, locating pharmacies, and getting directions.

## Maps and directions

The app uses free, OpenStreetMap-based map and routing services; it does not
embed the paid Google Maps API or require a Google Maps API key.

1. The map is rendered with Flutter's `flutter_map` package and map tiles from
   OpenStreetMap (`tile.openstreetmap.org`).
2. Pharmacy markers come from Firebase Firestore's `pharmacies` collection.
   Each pharmacy needs `latitude` and `longitude` fields. Only active
   pharmacies are displayed.
3. The app asks for device location through `geolocator`. When permission is
   granted, the user's coordinates are shown as a blue marker and used to
   calculate distances to pharmacies.
4. If GPS is unavailable or denied, the user can enter an address manually.
   The address is geocoded with OpenStreetMap's Nominatim service (restricted
   to Cameroon) and saved on the device for later use.
5. Tapping a pharmacy marker selects it and exposes actions to view the
   pharmacy or get directions. The map recentres on the selected pharmacy.
6. In-app driving routes, ETA, distance, and turn-by-turn steps are requested
   from the public OSRM routing service (`router.project-osrm.org`) and drawn
   on the OpenStreetMap map. If OSRM cannot be reached, the app shows a dashed
   direct path and an estimated travel time instead.
7. The optional **Open in Google Maps** action only launches an external
   directions URL with the pharmacy coordinates; Google Maps is not used for
   the in-app map or routing.
8. The **Offline maps** button on the map screen saves the visible area
   (three detail presets, up to 1200 tiles) for offline use. Downloads are
   rate-limited to stay polite to the public OpenStreetMap tile servers.

## Map performance and offline support

- **Tile caching:** every map (`MapScreen`, `DirectionsScreen`, `MiniMap`)
  shares one tile layer (`widgets/app_tile_layer.dart`) backed by
  `services/offline_map_service.dart`, a persistent `z/x/y.png` tile store in
  the app support directory. Tiles seen while browsing are cached
  automatically and served from disk on later visits (instant loads, less
  mobile data). Stored tiles are always treated as fresh, so they also render
  with no connection.
- **Offline downloads:** the offline maps sheet downloads a whole region
  (visible bounds × zoom range) into its own folder, with progress and
  cancel support. Saved areas can be deleted from the same sheet or via
  Settings → Reset local data.
- **Camera persistence:** the app remembers the last map position and zoom,
  so reopening the map starts where the user left off instead of jumping and
  re-downloading tiles. The first-ever launch defaults to Buea, Cameroon.
- **Pharmacy data cache:** the pharmacy list is cached in memory and on disk
  (stale-while-revalidate, 10 minute TTL), so map markers and the nearby list
  appear immediately and still work offline.

In summary:

`Firestore pharmacy coordinates + GPS/manual user location -> OpenStreetMap map -> OSRM route -> optional Google Maps handoff`
