import 'dart:io';
import 'package:flutter/foundation.dart';

class DeviceInfo {
  static String getPlatform() {
    if (kIsWeb) {
      return 'web';
    } else if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    } else {
      return 'unknown';
    }
  }
  
  static Map<String, dynamic> getDeviceDetails() {
    return {
      'platform': getPlatform(),
      'isIOS': Platform.isIOS,
      'isAndroid': Platform.isAndroid,
      'version': Platform.operatingSystemVersion,
    };
  }
}