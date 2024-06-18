import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';

class MyMarker extends AnimatedMarker {
  MyMarker({
    required super.point,
    required Widget icon,
    ValueChanged<LatLng>? onTap,
  }) : super(
          width: markerSize,
          height: markerSize,
          rotate: true,
          builder: (context, animation) {
            return GestureDetector(
              onTap: () => onTap?.call(point),
              child: Opacity(opacity: animation.value, child: icon),
            );
          },
        );
  static const markerSize = 40.0;
}

class UserLocationMarker extends StatelessWidget {
  final LatLng point;
  final double heading;

  const UserLocationMarker({
    Key? key,
    required this.point,
    required this.heading,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Transform.rotate(
          angle: heading * (3.141592653589793 / 180),
          child: Icon(
            Icons.navigation,
            color: Colors.blue,
            size: 40.0,
          ),
        ),
      ],
    );
  }
}

List<LatLng> decodePolyline(String encodedPolyline) {
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

String formatDuration(double seconds) {
  var hours = (seconds / 3600).round();
  var minutes = (seconds % 3600) ~/ 60;

  if (hours < 1 && minutes < 1) {
    return '${seconds}s';
  } else if (hours < 1) {
    return '${minutes}m';
  } else if (hours > 1) {
    return '${hours}h${minutes}m';
  } else {
    return '${hours}h${minutes}m';
  }
}
