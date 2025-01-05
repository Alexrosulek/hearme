// ignore_for_file: empty_catches

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert'; 
import 'dart:async'; // For StreamSubscription
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'chat.dart';
import 'api_service.dart';

import 'dart:ui';


final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

final RouteObserver<ModalRoute<void>> routeObserver = RouteObserver<ModalRoute<void>>();

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
       home: const LoginPage(), // Default home page
       scaffoldMessengerKey: scaffoldMessengerKey,
      navigatorObservers: [routeObserver], // Route observer
      routes: {
        '/login': (context) => const LoginPage(), // Login page route
      
      '/home': (BuildContext context)  => const HomePage(),
       '/settings': (context) => const SettingsPage(),
      },
       );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WidgetsBindingObserver, RouteAware {

  bool isPolling = false; // Track polling state
bool isLaunchingBrowser = false;
late Completer<bool> _callbackCompleter; // Completer to control callback flow
  String? _callbackId;
  bool isLoading = false;

  Timer? _pollingTimer; // Timer for polling

  Timer? _refreshTimer; // Timer for callback refresh
  final ApiService apiService = ApiService(); // Create instance
  @override
  void initState() {
    super.initState();
  _callbackCompleter = Completer<bool>();
  _initializeLoginFlow();
  }
  
@override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
   Future<void> _initializeLoginFlow() async {

    _checkLoginStatus();
    final callbackId = await _registerCallback();
      if (mounted) {
    setState(() {
      _callbackId = callbackId;

    });
      }
    if (_callbackId != null && _callbackId != '0') {
      _startRefreshCallback();
      
    }
  }
@override
void dispose() {
 if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  }  // Clear Material Banners
  _pollingTimer?.cancel();
  _refreshTimer?.cancel();
  _callbackCompleter.complete(false); 
  WidgetsBinding.instance.removeObserver(this);
  routeObserver.unsubscribe(this);
  
  super.dispose();
}

 @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
      if (state == AppLifecycleState.paused && !isLaunchingBrowser) {
    _stopPolling();

    _stopRefreshCallback();
    _stopCallbackRegistration(); // Stop callback registration
  } else if (state == AppLifecycleState.resumed) {
    if (_callbackId == null || _callbackId == '0') {
      _startCallbackRegistration(); // Restart registration
    }
    if (_callbackId != null && _callbackId != '0') {
      _startRefreshCallback(); // Resume refresh on resume
    }
      if (isLaunchingBrowser) {
        // Reset the browser launch flag
        isLaunchingBrowser = false;
        _stopPolling();
      } else {
        // Resume polling if necessary
        _stopPolling();
      }
    }
  }
 @override
  void didPushNext() {
    _stopPolling();
    _stopRefreshCallback();
    _stopCallbackRegistration();
  }

  @override
  void didPopNext() {
    if (_callbackId == null || _callbackId == '0') {
      _startCallbackRegistration();
    }
    _startPolling();
    _startRefreshCallback();
  }

Future<void> _startCallbackRegistration() async {
  _callbackCompleter = Completer<bool>(); // Reset the completer
  await _registerCallback();
}
void _stopRefreshCallback() {
  _refreshTimer?.cancel();
  _refreshTimer = null;
}
void _stopCallbackRegistration() {
  _callbackCompleter.complete(false); // Cancel ongoing registration attempts
}
Future<void> _startRefreshCallback() async {
  _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
    if (!mounted) return; // Ensure widget is still active
    try {
      final response = await apiService.refreshCallback(_callbackId!);
      if (response.statusCode == 200) {
      } else {
      }
    } catch (e) {

    }
  });
}

 void _startPolling() {
  if (isPolling) {
    return; // Avoid multiple polling instances
  }

  isPolling = true;

  _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
    
    try {
      final status = await apiService.checkAuthStatus(_callbackId!);

      if (status == 'success') {
        final token = await apiService.fetchToken(_callbackId!);
        if (token != null) {
          _stopPolling(); // Stop polling on success
          await apiService.saveToken(token);
          if (mounted) _navigateToHomePage();
        }
      }
    } catch (e) {
 
      _stopPolling(); // Ensure polling stops on error
    }
  });
}

Future<void> _loginWithApple() async {
    try {
      // Request Apple ID Credential
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Send the `identityToken` to the backend
      final success = await _sendAppleTokenToBackend(credential.identityToken);
      if (success) {
        _navigateToHomePage(); // Navigate to home page on successful login
      } else {
      // Retry if the first attempt failed
      final success = await _sendAppleTokenToBackend(credential.identityToken);

      if (success) {
        _navigateToHomePage();
      } else {
      }
    }
  } catch (e) {
  }
}
  Future<bool> _sendAppleTokenToBackend(String? identityToken) async {
    if (identityToken == null) return false; // No token to send

    final response = await http.post(
      Uri.parse('https://www.hearme.services/auth/apple/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': identityToken}),
    );

   if (response.statusCode == 200) {

    final responseData = jsonDecode(response.body);
    final backendToken = responseData['token'];  // Get the token from the backend's response
    if (backendToken != null) {
      await apiService.saveToken(backendToken);  // Save token to shared preferences
      return true;
    }

  }
  return false;
}

void _stopPolling() {
  if (!isPolling) return; // Avoid unnecessary calls


  isPolling = false;
  _pollingTimer?.cancel();
  _pollingTimer = null;
}



Future<String> _registerCallback() async {
  final String deviceIp = await _getDeviceIp();
  
  // Generate the timestamp
  final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

  // Embed both the IP and timestamp directly in the URL
  final String callbackUrl = 'http://$deviceIp-$timestamp:5000/auth_callback';

  String? state;

  

  while (state == null || state == '0') {
   

    try {
 
      final response = await http.post(
        Uri.parse('https://www.hearme.services/register/callback/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'callback_url': callbackUrl}),
      );
      

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        state = data['state'];

        if (state != null && state != '0') {
          return state; // Return the valid state immediately
        }
      } else {
      }
    } catch (e) {
    }

    // Wait 2 seconds before trying again
    await Future.delayed(const Duration(seconds: 30));
  }

  // This point will never be reached since the loop only exits on success
  return state ;
}


  Future<String> _getDeviceIp() async {
    try {
      final response = await http.get(Uri.parse('https://www.hearme.services/ip'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ip'] ?? '127.0.0.1';
      } else {
      
      }
    } catch (e) {
   
    }
    return '127.0.0.1'; // Fallback to localhost
  }


  Future<void> _checkLoginStatus() async {
    if (!mounted) return;
      if (mounted) {
    setState(() {
      isLoading = true;
    });
      }
    try {
      final isLoggedIn = await apiService.isLoggedIn();
      if (isLoggedIn && mounted) {
        _navigateToHomePage();
      } else if (mounted) {
setState(() {
      _callbackId = null;
    });
    
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Could not login, Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _navigateToHomePage() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomePage(), // Pass instance
        ),
      );
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _loginWithGoogle() async {
isLaunchingBrowser = true; // Mark that we're launching a browser

    _startPolling(); // Start polling
    
    final String callbackId = _callbackId ?? '0';
    final Uri googleAuthUrl = Uri.parse(
        'https://www.hearme.services/auth/?action=login_google&state=$callbackId');
 try {
      if (await canLaunchUrl(googleAuthUrl)) {
        await launchUrl(googleAuthUrl);
      } else {
         if (mounted) {
        _showMessage('Could not launch the login page, Please try again.');
         }
      }
    } catch (e) {
       if (mounted) {
      _showMessage('Could not launch the login page, Please try again.');
       }
    }
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Gradient Background
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(seconds: 30),
            curve: Curves.linear,
            builder: (context, value, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      Colors.blue.withOpacity(0.6),
                      Colors.green.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: [0.3, value, 1.0],
                  ),
                ),
              );
            },
          ),
          // Blur Effect
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(
              color: Colors.black.withOpacity(0), // Transparent overlay for the blur
            ),
          ),
          // Foreground Content - Login UI
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/icon2text.png',
                    height: 350,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Transcribe & Talk",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  if (isLoading)
                    const CircularProgressIndicator()
                  else
                    Column(
                      children: [
                        ElevatedButton(
                          onPressed: _loginWithGoogle,
                          child: const Text('Login/Register with Google'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loginWithApple,
                          child: const Text('Login/Register with Apple'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class HomePage extends StatefulWidget {
  const HomePage({super.key});

    

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {

 final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
     
  }
    @override
  void dispose() {

  
     if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  }  // Clear Material Banners
  
    super.dispose();
  }

@override
Widget build(BuildContext context, {bool isHomePage = true}) {
  return const Scaffold(
    
    body:  ChatModule(title: "AI Chat Bot"),
  );
}






  

}




class CelebrationDialog extends StatelessWidget {
  final VoidCallback onDismiss;

  const CelebrationDialog({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: const Stack(
        alignment: Alignment.center,
        children: [
          // Placeholder for animated balloons or confetti
         
          Positioned(
            child: Text(
              "🎉 Credits Added! 🎉",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

  final ApiService apiService = ApiService(); // Create instance
 
class SettingsPageState extends State<SettingsPage> {
 @override
  void initState() {
    super.initState();
   
  }
    @override
  void dispose() {

  super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
            const SizedBox(width: 1),
       
          _buildSettingsOption(
            context,
            'Help',
            () => _launchURL('https://www.hearme.services/help'),
          ),
           const SizedBox(height: 16),
          _buildSettingsOption(
            context,
            'Pricing',
            () => _launchURL('https://www.hearme.services/pricing'),
          ),
          const SizedBox(height: 16),
          _buildSettingsOption(
            context,
            'Contact Us',
            () => _launchURL('https://www.hearme.services/contact'),
          ),

         
          const SizedBox(height: 16),
          _buildSettingsOption(
            context,
            'Terms Of Service',
            () => _launchURL('https://www.hearme.services/terms'),
          ),
          const SizedBox(height: 16),
          _buildSettingsOption(
            context,
            'Privacy Policy',
            () => _launchURL('https://www.hearme.services/terms'),
          ),
          const SizedBox(height: 16),
          _buildSettingsOption(
            context,
            'Delete Account',
            () => _confirmDeleteAccount(context),
          ),

          const SizedBox(height: 16),
         _buildLogoutButton(context),
        ],
      ),
    );
  }
 Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator(color: Colors.white);
        }

        final isLoggedIn = snapshot.data ?? false;

       return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.deepPurple,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: () async => _handleLoginOrLogout(context, isLoggedIn),
        child: Text(isLoggedIn ? 'Logout' : 'Login'),
      );
    },
  );
}
void _showSnackBar(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}


Future<void> _handleLoginOrLogout(BuildContext context, bool isLoggedIn) async {
  try {
    if (isLoggedIn) {
      final success = await apiService.logout(context);
      if (success) {
        if (context.mounted) {
          _navigateToLoginPage(context); // Navigate after logout
        }
      } else {
        if (context.mounted) {
          _showSnackBar(context, 'Logout failed. Please try again.');
        }
      }
    } else {
      final success = await apiService.loginWithToken();
      if (success) {
        
      } else {
        if (context.mounted) {
          _navigateToLoginPage(context); // Navigate after not login
        }
      }
    }
  } catch (e) {
    if (context.mounted) {
      _showSnackBar(context, 'Failed, Please try again.');
    }
  }
}


void _navigateToLoginPage(BuildContext context) {
  if (context.mounted) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (context) => const LoginPage()),
    (route) => false, // Removes all previous routes
  );
  }
}



  Widget _buildSettingsOption(BuildContext context, String title, VoidCallback onTap) {
    return Container(
      width: double.infinity,  // Fills the available width
      decoration: BoxDecoration(
        color: Colors.white,  // Background color for button
        borderRadius: BorderRadius.circular(8),  // Rounded corners
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),  // Subtle shadow effect
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),  // Padding for button content
      ),
    );
  }



Future<void> _confirmDeleteAccount(BuildContext context) async {
  // Show confirmation dialog and wait for result
  final confirmed = await _showConfirmationDialog(context);

  // If the user confirmed, proceed with deletion
  if (confirmed == true) {
    _performAccountDeletion();
  }
}

// Step 1: Separate function to handle dialog confirmation
Future<bool?> _showConfirmationDialog(BuildContext dialogContext) async {
  return showDialog<bool>(
    context: dialogContext,
    builder: (BuildContext context) => AlertDialog(
      title: const Text('Delete Account'),
      content: const Text(
          'Are you sure you want to delete your account? You will not be able to undo this and you will not be refunded any credits.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );
}

// Step 2: Separate function to handle account deletion
Future<void> _performAccountDeletion() async {
  final deleteSuccessful = await _deleteAccount();

  // Ensure this navigation only happens if the widget is still mounted
  if (deleteSuccessful && mounted) {
    Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }
}

 void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
Future<bool> _deleteAccount() async {
  final token = await getToken();
  if (token == null) return false;

  try {
    final response = await http.post(
      Uri.parse('https://www.hearme.services/user/delete'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      await clearToken();
      return true;
    }
  } catch (e) {
    _showMessage("Cound not delete account.");
  }
  return false;
}


  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  
 

  Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }
}
