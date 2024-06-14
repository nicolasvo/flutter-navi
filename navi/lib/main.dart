import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:shimmer/shimmer.dart';

import 'package:navi/utilities.dart';

void main() async {
  await dotenv.load(fileName: ".env");
  WidgetsFlutterBinding.ensureInitialized();
  await FMTCObjectBoxBackend().initialise();
  await FMTCStore('mapStore').manage.create();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Map App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  LatLng? _currentLocation;
  List<LatLng> _routeCoords = [];
  late final _animatedMapController = AnimatedMapController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    curve: Curves.easeInOut,
  );
  bool _isZoomedIn = false;
  bool _orientationChanged = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  LatLng? _destination;
  Timer? _debounce;
  double _heading = 0.0;

  @override
  void initState() {
    super.initState();
    _startPositionStream();
    _startCompass();
    _animatedMapController.mapController.mapEventStream.listen((event) {
      if (event is MapEventRotate) {
        setState(() {
          _orientationChanged = _animatedMapController.rotation != 0.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  void _centerOnUserLocation() {
    setState(() {
      if (_isZoomedIn) {
        _animatedMapController.animateTo(dest: _currentLocation, zoom: 15.0);
      } else {
        _animatedMapController.animateTo(dest: _currentLocation, zoom: 17.0);
      }
      _isZoomedIn = !_isZoomedIn;
    });
  }

  Future<void> _startPositionStream() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    _positionStreamSubscription =
        Geolocator.getPositionStream().listen((Position position) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      if (_destination != null) {
        print('recalculating...');
        _debounce?.cancel();
        _debounce = Timer(const Duration(seconds: 5), () {
          _getRoute(_currentLocation!, _destination!, recenter: false);
        });
      }
    });
  }

  void _startCompass() {
    FlutterCompass.events!.listen((CompassEvent event) {
      setState(() {
        _heading = event.heading!;
      });
    });
  }

  Future<void> _getRoute(LatLng origin, LatLng destination,
      {bool recenter = true}) async {
    final String url =
        '${dotenv.env['OSRM_BACKEND_URL']}/route/v1/walking/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?steps=true&alternatives=false&overview=full';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final routes = data['routes'] as List<dynamic>;
      if (routes.isNotEmpty) {
        final route = routes.first;
        final geometry = route['geometry'] as String;
        setState(() {
          _destination = destination;
          _routeCoords = decodePolyline(geometry);
        });
      } else {
        throw Exception('No routes found');
      }
    }
    if (recenter)
      _animatedMapController.animatedFitCamera(
          cameraFit: CameraFit.coordinates(
        coordinates: [origin, destination],
        padding: const EdgeInsets.all(80),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _animatedMapController.mapController,
            options: MapOptions(
              initialCenter: LatLng(43.676902528460204, 7.176964407768331),
              initialZoom: 12.0,
              interactionOptions: InteractionOptions(
                enableMultiFingerGestureRace: true,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png",
                subdomains: const ['a', 'b', 'c'],
                tileProvider: FMTCStore("mapStore").getTileProvider(),
              ),
              GestureDetector(
                  child: PolylineLayer(
                    polylines: [
                      Polyline(
                        points: _routeCoords, // Route coordinates
                        color: Colors.blue.withOpacity(0.4), // Route color
                        strokeWidth: 4.0, // Route width
                      ),
                    ],
                  ),
                  onTap: () async {
                    _getRoute(_currentLocation!, _destination!);
                  }),
              AnimatedMarkerLayer(
                markers: [
                  if (_currentLocation != null)
                    MyMarker(
                      point: _currentLocation!,
                      icon: UserLocationMarker(
                        point: _currentLocation!,
                        heading: _heading,
                      ),
                      onTap: (LatLng point) async {
                        _centerOnUserLocation();
                      },
                    ),
                  MyMarker(
                    point: const LatLng(48.8594, 2.3138),
                    icon: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50.0,
                    ),
                    onTap: (LatLng point) async {
                      _destination = point;
                      _getRoute(_currentLocation!, point);
                    },
                  ),
                  MyMarker(
                    point: const LatLng(48.85608312652121, 2.297967035877974),
                    icon: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50.0,
                    ),
                    onTap: (LatLng point) async {
                      _destination = point;
                      _getRoute(_currentLocation!, point);
                    },
                  ),
                  MyMarker(
                    point: const LatLng(43.65905756427601, 7.1953319013893084),
                    icon: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50.0,
                    ),
                    onTap: (LatLng point) async {
                      _destination = point;
                      _getRoute(_currentLocation!, point);
                    },
                  ),
                  MyMarker(
                    point: const LatLng(43.69506468906737, 7.268872874437284),
                    icon: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50.0,
                    ),
                    onTap: (LatLng point) async {
                      _destination = point;
                      _getRoute(_currentLocation!, point);
                    },
                  ),
                  MyMarker(
                    point: const LatLng(43.65694065307015, 7.183261174229134),
                    icon: Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 50.0,
                    ),
                    onTap: (LatLng point) async {
                      _destination = point;
                      _getRoute(_currentLocation!, point);
                    },
                  ),
                ],
              ),
            ],
          ),
          if (_orientationChanged)
            Positioned(
              top: 60.0,
              right: 16.0,
              child: FloatingActionButton(
                onPressed: () {
                  _animatedMapController.animatedRotateReset();
                  setState(() {
                    _orientationChanged = false;
                  });
                },
                child: const Icon(Icons.explore),
              ),
            ),
          if (_currentLocation == null)
            Column(
              children: [
                SizedBox(
                  height: 80,
                ),
                Center(
                  child: Container(
                    decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.all(Radius.circular(30))),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Shimmer.fromColors(
                        baseColor: Colors.white,
                        highlightColor: Colors.blueAccent,
                        child: Text(
                          "Searching for location...",
                          style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
        ],
      ),
      floatingActionButton: (_currentLocation != null)
          ? FloatingActionButton(
              onPressed: _centerOnUserLocation,
              child: const Icon(Icons.my_location),
            )
          : FloatingActionButton(
              onPressed: null,
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: CircularProgressIndicator(
                  strokeWidth: 6,
                ),
              ),
            ),
    );
  }
}
