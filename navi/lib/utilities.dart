import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';

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
