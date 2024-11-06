import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = 'https://www.aimaker.world/';  // Your Django backend URL


class ApiService {
  static const String baseUrls = 'https://www.aimaker.world';

static Future<String?> exchangeAuthCodeForToken(String authCode) async {
  final uri = Uri.https('https://www.aimaker.world', '/auth/google/callback/', {'code': authCode});

  final response = await http.post(uri);

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    return data['token']; // Return JWT token
  } else {
    print('Error: ${response.body}');
    return null;
  }
}

 



 



// can only use if u have a token
Future<String?> getToken() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('jwt_token');
}

// Helper: Save JWT token locally
Future<void> saveToken(String token) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('jwt_token', token);
}

// Helper: Clear JWT token on logout or token expiration
Future<void> clearToken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('jwt_token');
}

// Login using JWT token (for re-auth)
Future<bool> loginWithToken() async {
  final token = await getToken();
  if (token == null) return false; // No token found

  final response = await http.get(
    Uri.parse('$baseUrl/auth/login_with_token/'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    return true;
  } else {
    await clearToken(); // Clear token if invalid
    return false;
  }
}


// Set a new username for the user
Future<bool> setUserName(String newName) async {
  final token = await getToken();
  if (token == null) return false;

  final response = await http.post(
    Uri.parse('$baseUrl/user/set_username/'),
    headers: {'Authorization': 'Bearer $token'},
    body: {'name': newName},
  );

  return response.statusCode == 200;
}

// Give the user credits
Future<bool> giveCredits() async {
  final token = await getToken();
  if (token == null) return false;

  final response = await http.post(
    Uri.parse('$baseUrl/give/'),
    headers: {'Authorization': 'Bearer $token'},
  );

  return response.statusCode == 200;
}
// Fetch user profile from backend
Future<Map<String, dynamic>?> getUserProfile() async {
  final token = await getToken();
  if (token == null) return null;

  final response = await http.get(
    Uri.parse('$baseUrl/user/profile/'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    if (response.statusCode == 401) await clearToken(); // Handle expired token
    return null;
  }
}


// Generate assets
Future<Map<String, dynamic>?> generateAsset(String prompt) async {
  final token = await getToken();
  if (token == null) return null;

  final response = await http.post(
    Uri.parse('$baseUrl/generate/'),
    headers: {'Authorization': 'Bearer $token'},
    body: {'prompt': prompt},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    if (response.statusCode == 401) await clearToken(); // Clear on token expiry
    return null;
  }
}
}