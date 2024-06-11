import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:navi/utilities.dart';

void main() async {
  await dotenv.load(fileName: ".env");
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
  LatLng _currentLocation = const LatLng(0.0, 0.0);
  List<LatLng> _routeCoords = [];
  late final _animatedMapController = AnimatedMapController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    curve: Curves.easeInOut,
  );
  bool _isZoomedIn = false;
  StreamSubscription<Position>? _positionStreamSubscription;
  LatLng? _destination;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _startPositionStream();
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
          _getRoute(_currentLocation, _destination!);
        });
      }
    });
  }

  Future<void> _getRoute(LatLng origin, LatLng destination) async {
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
          _routeCoords = decodePolyline(geometry);
        });
        final double minLat = _routeCoords
            .map((coord) => coord.latitude)
            .reduce((a, b) => a < b ? a : b);
        final double maxLat = _routeCoords
            .map((coord) => coord.latitude)
            .reduce((a, b) => a > b ? a : b);
        final double minLng = _routeCoords
            .map((coord) => coord.longitude)
            .reduce((a, b) => a < b ? a : b);
        final double maxLng = _routeCoords
            .map((coord) => coord.longitude)
            .reduce((a, b) => a > b ? a : b);

        _animatedMapController.animatedFitCamera(
            cameraFit: CameraFit.coordinates(
          coordinates: [LatLng(minLat, minLng), LatLng(maxLat, maxLng)],
          padding: const EdgeInsets.all(80),
        ));
      } else {
        throw Exception('No routes found');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Map App'),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _animatedMapController.mapController,
            options: MapOptions(
              initialCenter: LatLng(48.8575, 2.3514),
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routeCoords, // Route coordinates
                    color: Colors.blue.withOpacity(0.4), // Route color
                    strokeWidth: 4.0, // Route width
                  ),
                ],
              ),
              AnimatedMarkerLayer(
                markers: [
                  MyMarker(
                      point: _currentLocation,
                      icon: Icon(
                        Icons.person_pin_circle,
                        color: Colors.orange,
                        size: 50.0,
                      ),
                      onTap: (LatLng point) async {
                        _centerOnUserLocation();
                      }),
                  MyMarker(
                      point: const LatLng(48.8594, 2.3138),
                      icon: Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 50.0,
                      ),
                      onTap: (LatLng point) async {
                        _destination = point;
                        _getRoute(_currentLocation, point);
                      }),
                  MyMarker(
                      point:
                          const LatLng(48.85272284500543, 2.3031675776474687),
                      icon: Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 50.0,
                      ),
                      onTap: (LatLng point) async {
                        _destination = point;
                        _getRoute(_currentLocation, point);
                      }),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              onPressed: () => _animatedMapController.animatedRotateReset(),
              child: const Icon(Icons.explore),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _centerOnUserLocation,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
