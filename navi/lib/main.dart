import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  // final MapController _mapController = MapController();
  LatLng _currentLocation = const LatLng(0.0, 0.0);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Map App'),
      ),
      body: FlutterMap(
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
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _getCurrentLocation,
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            onPressed: _resetOrientation,
            child: const Icon(Icons.explore),
          ),
        ],
      ),
    );
  }
}
