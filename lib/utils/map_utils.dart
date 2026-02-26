import 'package:url_launcher/url_launcher.dart';

class MapUtils {
  static Future<void> openMap(String location) async {
    // Convert the location string into a URL-encoded query parameter
    final query = Uri.encodeComponent(location);
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$query';
    
    final uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $googleMapsUrl';
    }
  }
}