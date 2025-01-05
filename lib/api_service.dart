// ignore_for_file: empty_catches

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert'; 
import 'dart:async'; // For StreamSubscription
class ApiService {
  static const String baseUrl = 'https://www.hearme.services';
 
     Future<bool> logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final jwtToken = prefs.getString('jwt_token');

    if (jwtToken == null) {
      return false; // No token to log out
    }

    final url = Uri.parse('$baseUrl/logout/auth/');
    try {
      final response = await http.post(
        url,
        headers: {'Authorization': 'Bearer $jwtToken'},
      );

      if (response.statusCode == 200) {
        await prefs.remove('jwt_token'); // Clear token on successful logout
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }




  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }
Future<bool> isLoggedIn() async {
  final token = await getToken();
  if (token == null) return false;

  // Define the logged endpoint
  final Uri url = Uri.parse('https://www.hearme.services/logged');

  try {
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['is_logged_in'] ?? false;
    } else {
      await clearToken();
      return false;
    }
  } catch (e) {

      await clearToken();

    return false;
  }
}




   Future<String> checkAuthStatus(String callbackId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/check_status/?callbackId=$callbackId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'];
      } else {

      }
    } catch (e) {
      

    }
    
    return 'pending'; // Default to pending if the request fails
  }
  Future<String?> fetchToken(String callbackId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/check_status?callbackId=$callbackId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['token'];
      }
    } catch (e) {
      

    }
    
    return null;
  }
 Future<http.Response> refreshCallback(String callbackId) async {
    final url = Uri.parse('$baseUrl/register/callback/refresh/?state=$callbackId');
    return await http.get(url);
  }

Future<List<dynamic>?> getUserKnowledge() async {
  try {
    final token = await getToken(); // Retrieve token
    if (token == null) {
      await clearToken();
      return null; // User not logged in
    }

    // Make GET request
    final response = await http.get(
      Uri.parse('$baseUrl/user/knowledge/get'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['knowledge_entries']; // Return the list of knowledge entries
    } else if (response.statusCode == 401) {
      
      await clearToken();
    } else {
    
    }
  } catch (e) {
    
  }
  return null; // Return null if fetching failed
}
Future<bool> deleteUserKnowledge(int id) async {
  try {
    final token = await getToken(); // Retrieve token
    if (token == null) {
      await clearToken();
      return false; // User is not logged in
    }

    // Make DELETE request with the knowledge ID in the body
    final response = await http.post(
      Uri.parse('$baseUrl/user/knowledge/delete'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({"id": id}),
    );

    if (response.statusCode == 200) {
      
      return true;
    } else if (response.statusCode == 404) {
     
    } else if (response.statusCode == 401) {
      
      await clearToken();
    } else {
    }
  } catch (e) {
  }
  return false; // Return false if deletion failed
}
Future<bool> setUserKnowledge({
  required String category,
  required String text,
  String? embedding,
}) async {
  try {
    final token = await getToken(); // Retrieve token
    if (token == null) {
      await clearToken();
      return false; // User not logged in
    }

    // Prepare request body
    final Map<String, dynamic> body = {
      'category': category,
      'text': text,
     
    };

    // Make POST request
    final response = await http.post(
      Uri.parse('$baseUrl/user/knowledge/set'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return true;
    } else if (response.statusCode == 400) {
    } else if (response.statusCode == 401) {
      await clearToken();
    } else {
    }
  } catch (e) {
  }
  return false; // Return false if adding failed
}

Future<Map<String, dynamic>?> fetchOrSetUserInfo({
  String? name,
  int? age,
  String? gender,
  String? voice,
}) async {
  try {
    // Retrieve token
    final token = await getToken();
    if (token == null) {
      await clearToken();
      return null; // User is not logged in
    }

    // Prepare query parameters for optional updates
    final queryParams = {
      if (name != null) 'name': name,
      if (age != null) 'age': age.toString(),
      if (gender != null) 'gender': gender,
      if (voice != null) 'voice': voice,
    };

    // Build the API URL with query parameters
    final uri = Uri.parse('$baseUrl/setorget_user_info')
        .replace(queryParameters: queryParams);

    // Make the HTTP GET request
    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    // Check the response status
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data; // Return user info or update confirmation
    } else if (response.statusCode == 401) {
      // Unauthorized: token expired or invalid
      await clearToken();
    } else if (response.statusCode == 404) {
      // User profile not found
      await clearToken();
    } else {
      // Other errors
    }
  } catch (e) {
    // Handle unexpected errors
  }

  // Clear token and return null if anything fails
  await clearToken();
  return null;
}

Future<int?> fetchCredits() async {
  try {
    // Retrieve the JWT token from local storage
    final token = await getToken();
    if (token == null) {

      await clearToken();
      return null; // No token means the user is not logged in
    }

    // Make the API request to fetch the user's profile
    final response = await http.get(
      Uri.parse('$baseUrl/user/credits'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    // Handle the response
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['credits']; // Return the user's credits
    } else if (response.statusCode == 404) {
    

      await clearToken();
    } else {


      await clearToken();
    }
  } catch (e) {


      await clearToken();
  }

      await clearToken();
  return null; // Return null if fetching credits failed
}
  Future<bool> loginWithToken() async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/login_with_token/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        await clearToken();
        return false;
      }
    } catch (e) {

      await clearToken();
      return false;
    }
  }
}