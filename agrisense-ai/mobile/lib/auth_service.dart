// AgriSense AI - Auth service
// Handles account creation, login, and remembering who's signed in.
// Mirrors the pattern in api_service.dart: static methods, same baseUrl.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class AppUser {
  final int id;
  final String name;
  final String email;
  final String? district;

  AppUser({required this.id, required this.name, required this.email, this.district});

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      district: json['district'],
    );
  }
}

class AuthService {
  static const _tokenKey = 'agrisense_token';
  static const _nameKey = 'agrisense_user_name';
  static const _emailKey = 'agrisense_user_email';
  static const _districtKey = 'agrisense_user_district';

  // Reads the token saved on a previous launch, if any. Used at startup to
  // decide whether to show the login screen or go straight to the app.
  static Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<AppUser?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_emailKey);
    if (email == null) return null;
    return AppUser(
      id: 0,
      name: prefs.getString(_nameKey) ?? '',
      email: email,
      district: prefs.getString(_districtKey),
    );
  }

  static Future<void> _saveSession(String token, AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_nameKey, user.name);
    await prefs.setString(_emailKey, user.email);
    if (user.district != null) await prefs.setString(_districtKey, user.district!);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_districtKey);
  }

  static Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    String? district,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/v1/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        if (district != null) 'district': district,
      }),
    );
    return _handleAuthResponse(response, fallback: 'Could not create your account');
  }

  static Future<AppUser> login({required String email, required String password}) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/v1/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handleAuthResponse(response, fallback: 'Incorrect email or password');
  }

  static Future<AppUser> _handleAuthResponse(http.Response response, {required String fallback}) async {
    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      final user = AppUser.fromJson(data['user']);
      await _saveSession(data['access_token'], user);
      return user;
    }
    String message = fallback;
    try {
      final data = jsonDecode(response.body);
      if (data['detail'] != null) message = data['detail'];
    } catch (_) {
      // response wasn't JSON (e.g. backend unreachable) - keep fallback message
    }
    throw Exception(message);
  }
}
