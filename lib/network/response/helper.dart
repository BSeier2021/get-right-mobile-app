import 'dart:async';
 
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
 
final Completer<bool> autoLoginCompleter = Completer<bool>();
 
class HelperFunctions {
  // static const String authTokenKey = "authToken";
 
  // Toast message utility
  static toastMessage(String message, BuildContext context) {
    FToast toast = FToast();
    toast.init(context);
    toast.removeCustomToast();
    toast.showToast(
        child: Container(
      constraints: BoxConstraints(maxWidth: Get.height * 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.grey, borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image.asset(
          //   AppAssets.appLogo,
          //   scale: 2.5,
          // ),
          10.horizontalSpace,
          Flexible(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Nunito',
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    ));
  }
 
  // Save the token in local storage
  // static Future<void> saveAuthToken(String token) async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.setString(authTokenKey, token);
  // }
 
  // // Retrieve the token from local storage
  // static Future<String?> getAuthToken() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   return prefs.getString(authTokenKey);
  // }
 
  // // Delete the token (for logout or token refresh scenarios)
  // static Future<void> clearAuthToken() async {
  //   final prefs = await SharedPreferences.getInstance();
  //   await prefs.remove(authTokenKey);
  // }
 
  // Other existing methods
  static Future<Map<String, String>> getCityAndLocation(
      double latitude, double longitude) async {
    List<Placemark> placemarks =
        await placemarkFromCoordinates(latitude, longitude);
 
    if (placemarks.isNotEmpty) {
      Placemark placemark = placemarks.first;
      String city = placemark.locality ?? 'Unknown city';
      String locationName = placemark.name ?? 'Unknown location';
 
      return {
        'city': city,
        'locationName': locationName,
      };
    } else {
      return {
        'city': 'Unknown city',
        'locationName': 'Unknown location',
      };
    }
  }
 
  static String getExtension(String url) {
    String filename = url.split('/').last;
    String extension = filename.split('.').last;
    return extension;
  }
 
  static getAddressFromLatLng(lat, long) async {
    final placemarks = await placemarkFromCoordinates(lat, long);
    if (placemarks.isNotEmpty) {
      final placemark = placemarks[0];
      String completeAddress =
          '${placemark.street},${placemark.subLocality},${placemark.locality}, ${placemark.administrativeArea}  ${placemark.country}';
      print('Location is $completeAddress');
      return completeAddress;
    }
    return "Unable to get address";
  }
}