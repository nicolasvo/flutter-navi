import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:http/http.dart' as http;

void main() {
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
  LatLng _destinationLocation = const LatLng(48.8594, 2.3138);
  List<LatLng> _routeCoords = [];
  late final _animatedMapController = AnimatedMapController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    // _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try to ask for permissions again
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _animatedMapController.animateTo(dest: _currentLocation, zoom: 14.0);
    });
  }

  void _resetOrientation() {
    _animatedMapController.animatedRotateReset();
  }

  Future<void> _getRoute(LatLng origin, LatLng destination) async {
    // Make a request to the OSRM backend to get the route between origin and destination
    // For example, using the http package:
    final response = await http.get(
        'http://localhost:6000/route/v1/walking/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
            as Uri);
    if (response.statusCode == 200) {
      // Parse the response and extract the route geometry
      // For simplicity, assuming the response is JSON with a 'geometry' field containing the route geometry
      final Map<String, dynamic> data = json.decode(response.body);
      final List<dynamic> coordinates =
          data['routes'][0]['geometry']['coordinates'];
      _routeCoords =
          coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
      setState(() {
        _routeCoords =
            coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
      });
    }

    // For now, using dummy route coordinates
    // _routeCoords = [
    //   LatLng(48.8575, 2.3514), // Start point (current location)
    //   LatLng(48.8594, 2.3138), // End point (destination location)
    // ];

    // Animate to the destination location
    _animatedMapController.animateTo(dest: _destinationLocation, zoom: 14.0);
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
            options: const MapOptions(
              initialCenter: LatLng(48.8575, 2.3514),
              initialZoom: 12.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png",
                subdomains: const ['a', 'b', 'c'],
              ),
              AnimatedMarkerLayer(
                markers: [
                  AnimatedMarker(
                      point: _currentLocation,
                      builder: (_, animation) {
                        return const Icon(
                          Icons.person_pin_circle,
                          color: Colors.blue,
                          size: 50.0,
                        );
                      }),
                  AnimatedMarker(
                      point: const LatLng(48.8594, 2.3138),
                      builder: (_, animation) {
                        return const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 50.0,
                        );
                      }),
                ],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routeCoords, // Route coordinates
                    color: Colors.blue, // Route color
                    strokeWidth: 4.0, // Route width
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 16.0,
            right: 16.0,
            child: FloatingActionButton(
              onPressed: _resetOrientation,
              child: const Icon(Icons.explore),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _getCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
