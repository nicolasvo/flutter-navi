import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';

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
  late LatLng _destinationLocation;
  List<LatLng> _routeCoords = [];
  late final _animatedMapController = AnimatedMapController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
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
    final String url =
        'http://localhost:6000/route/v1/walking/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?steps=true&alternatives=false&overview=full';
    print(url);
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final routes = data['routes'] as List<dynamic>;
      if (routes.isNotEmpty) {
        final route = routes.first;
        final geometry = route['geometry'] as String;
        setState(() {
          _routeCoords = _decodePolyline(geometry);
        });
      } else {
        throw Exception('No routes found');
      }
    }
    _animatedMapController.animateTo(dest: destination, zoom: 14.0);
  }

  List<LatLng> _decodePolyline(String encodedPolyline) {
    List<LatLng> polylineCoordinates = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encodedPolyline.length) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encodedPolyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encodedPolyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      double latitude = lat / 1E5;
      double longitude = lng / 1E5;
      LatLng position = LatLng(latitude, longitude);
      polylineCoordinates.add(position);
    }
    return polylineCoordinates;
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
                          // Icons.my_location,
                          color: Colors.orange,
                          size: 50.0,
                        );
                      }),
                  MyMarker(
                      point: const LatLng(48.8594, 2.3138),
                      onTap: (LatLng point) async {
                        _getRoute(_currentLocation, point);
                      }),
                  MyMarker(
                      point:
                          const LatLng(48.850336347484784, 2.296388239183677),
                      onTap: (LatLng point) async {
                        _getRoute(_currentLocation, point);
                      }),
                ],
              ),
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _routeCoords, // Route coordinates
                    color: Colors.blue.withOpacity(0.7), // Route color
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

class MyMarker extends AnimatedMarker {
  MyMarker({
    required super.point,
    ValueChanged<LatLng>? onTap,
  }) : super(
          width: markerSize,
          height: markerSize,
          builder: (context, animation) {
            final size = markerSize * animation.value;

            return GestureDetector(
              onTap: () => onTap?.call(point),
              child: Opacity(
                opacity: animation.value,
                child: Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: size,
                ),
              ),
            );
          },
        );
  static const markerSize = 50.0;
}
