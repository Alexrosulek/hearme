import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert'; 
import 'dart:async'; // For StreamSubscription
import 'dart:io';

import 'package:video_player/video_player.dart';
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart';

import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:flutter/services.dart'; // Add this import
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
         '/background-replace': (context) => const BackgroundReplacePage(),
          '/background-removal': (context) => const BackgroundRemovalPage(), // Remove Background Page route
       '/restore-face': (context) => const RestoreFacePage(), // Remove Background Page route
      '/watermark-removal': (context) => const WatermarkRemovalPage(), // Remove Background Page route
      '/text-removal': (context) => const TextRemovalPage(), // Remove Background Page route
      '/merge-faces': (context) => const MergeFacePage(), // Remove Background Page route
      '/doodle': (context) => const DoodlePage(), // Remove Background Page route
      '/txt2img': (context) => const Txt2ImgPage(), // Remove Background Page route
       '/img2img': (context) => const Img2ImgPage(), // Remove Background Page route
        '/txt2vid': (context) => const Txt2VidPage(), // Remove Background Page route
       '/img2vid': (context) => const Img2VidPage(), // Remove Background Page route

       '/convert': (context) => const ConvertPage(), // Remove Background Page route
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
      Uri.parse('https://www.aimaker.world/auth/apple/'),
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
        Uri.parse('https://www.aimaker.world/register/callback/'),
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
      final response = await http.get(Uri.parse('https://www.aimaker.world/ip'));
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
        'https://www.aimaker.world/auth/?action=login_google&state=$callbackId');
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

  void _continueWithoutLogin() {
    if (mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Pass instance
      ),
    );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with scrolling images
          const ScrollingImageBackground(),
          // Foreground content - login UI
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/logo.png',
                    height: 150,
                  ),
                  const SizedBox(height: 40),
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
                        const SizedBox(height: 8),
                       ElevatedButton(
                          onPressed: _continueWithoutLogin,
                          child: const Text(
                            'Continue as guest',
                            style: TextStyle(
                              fontSize: 9,
                            ),
                          ),
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
class ScrollingImageBackground extends StatelessWidget {
  const ScrollingImageBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          flex: 1,
          child: ScrollingColumn(
            imagePaths: [
              'assets/images/2.png',
              'assets/images/32.png',
              'assets/images/23.png',
              'assets/images/4.png',
              'assets/images/1.gif',
              'assets/images/18.png',
              'assets/images/24.png',
              'assets/images/9.png',
              'assets/images/6.png',
              'assets/images/25.png',
              'assets/images/3.png',
              'assets/images/27.png',
              'assets/images/7.png',
              'assets/images/33.png',
              'assets/images/44.png',
              'assets/images/4.gif',
              'assets/images/41.png',
              'assets/images/5.png',
              'assets/images/8.gif',
              'assets/images/8.png',
              'assets/images/28.png',
            ],
            scrollDuration: Duration(seconds: 200),
            delay: Duration.zero,
          ),
        ),
        Expanded(
          flex: 1,
          child: ScrollingColumn(
            imagePaths: [
              'assets/images/9.gif',
              'assets/images/20.png',
              'assets/images/10.png',
              'assets/images/1.png',
              'assets/images/37.png',
              'assets/images/31.png',
              'assets/images/35.png',
              'assets/images/19.png',
              'assets/images/36.png',
              'assets/images/39.png',
              'assets/images/15.png',
              'assets/images/29.png',
              'assets/images/38.png',
              'assets/images/34.png',
              'assets/images/11.png',
              'assets/images/16.png',
              'assets/images/13.png',
              'assets/images/2.gif',
              'assets/images/14.png',
              'assets/images/30.png',
              'assets/images/17.png',
              'assets/images/3.gif',
              'assets/images/12.png',
            ],
            scrollDuration: Duration(seconds: 250),
            delay: Duration(milliseconds: 500),
          ),
        ),
        Expanded(
          flex: 1,
          child: ScrollingColumn(
            imagePaths: [
              'assets/images/10.gif',
              'assets/images/49.png',
              'assets/images/50.png',
              'assets/images/7.gif',
              'assets/images/43.png',
              'assets/images/22.png',
              'assets/images/18.png',
              'assets/images/21.png',
              'assets/images/48.png',
              'assets/images/47.png',
              'assets/images/26.png',
              'assets/images/42.png',
              'assets/images/6.gif',
              'assets/images/40.png',
              'assets/images/21.png',
              'assets/images/44.png',
              'assets/images/4.gif',
              'assets/images/41.png',
              'assets/images/19.png',
              'assets/images/20.png',
              'assets/images/45.png',
              'assets/images/5.gif',
              'assets/images/46.png',
              'assets/images/11.gif',
              'assets/images/22.png',
            ],
            scrollDuration: Duration(seconds: 300),
            delay: Duration(seconds: 1),
          ),
        ),
      ],
    );
  }
}

class ScrollingColumn extends StatefulWidget {
  final List<String> imagePaths;
  final Duration scrollDuration;
  final Duration delay;

  const ScrollingColumn({
    required this.imagePaths,
    required this.scrollDuration,
    required this.delay,
    super.key,
  });

  @override
  ScrollingColumnState createState() => ScrollingColumnState();
}

class ScrollingColumnState extends State<ScrollingColumn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.scrollDuration,
      vsync: this,
    )..addListener(() {
        if (mounted) {
          setState(() {});
        }
      });

    // Start the animation after the specified delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the total scrollable height based on image height, margin, and the number of images
    const double imageHeight = 200.0; // Fixed height for each image
    const double imageMargin = 4.0; // Margin above and below each image
    final double totalScrollableHeight = (imageHeight + 2 * imageMargin) * widget.imagePaths.length;

    // Offset for scrolling
    final scrollOffset = _controller.value * totalScrollableHeight;
    const double columnMargin = 8.0; // Margin between columns

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: columnMargin), // Margin between columns
      child: ClipRect(
        child: Stack(
          children: [
            Positioned(
              top: -scrollOffset,
              child: Column(
                children: widget.imagePaths.map((path) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: imageMargin), // Adds a margin around each image
                    width: MediaQuery.of(context).size.width / 3,
                    height: imageHeight,
                    child: Image.asset(
                      path,
                      fit: BoxFit.cover,
                    ),
                  );
                }).toList(),
              ),
            ),
            Positioned(
              top: totalScrollableHeight - scrollOffset,
              child: Column(
                children: widget.imagePaths.map((path) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: imageMargin), // Adds a margin around each image
                    width: MediaQuery.of(context).size.width / 3,
                    height: imageHeight,
                    child: Image.asset(
                      path,
                      fit: BoxFit.cover,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
bool _isCelebrationActive = false;

void _showCelebrationWidget(BuildContext context) {
  if (_isCelebrationActive) return; // Avoid showing multiple celebrations
  _isCelebrationActive = true;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return CelebrationDialog(
        onDismiss: () {
          _isCelebrationActive = false;
          Navigator.of(context).pop(); // Close the dialog
        },
      );
    },
  );
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
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
   const HomePage({super.key}); // Super parameter syntax

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> with RouteAware {
  
  final ApiService apiService = ApiService(); // Create instance

int? credits;

  @override
  void initState() {
    super.initState();
     
      _initializeInAppPurchaseListener();
    _fetchAndSetCredits(); // Fetch credits on initialization
  }
  
    @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  @override
  void dispose() {
 if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  }  // Clear Material Banners
  
    _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  @override
  Widget build(BuildContext context,{bool isHomePage = true}) {
    return Scaffold(
      appBar: AppBar(
         automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF5F5F5),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            
             GestureDetector(
          onTap: () {
            if (!isHomePage) {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },

          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
        IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          Navigator.pushNamed(context, '/settings');
        },
      ),const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
            _buildLogoutButton(context),
          ],
        ),
      ),
      backgroundColor: const Color(0xFFF5F5F5),
      body: SingleChildScrollView(
        
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          
          children: [
            _buildHorizontalList(context),
            const SizedBox(height: 24),
         const Text(
              'Spotlight',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize: 30,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),
             _buildImageGrid(context),
             
          ],
        ),
      ),
    );
  }
  
 Widget _buildImageGrid(BuildContext context) {
    final List<Map<String, String>> images = [
      {'path': 'assets/images/image2.png', 'route': '/merge-faces'},

      {'path': 'assets/images/image4.gif', 'route': '/img2vid'},
      {'path': 'assets/images/image3.png', 'route': '/txt2img'},

      {'path': 'assets/images/image1.png', 'route': '/doodle'},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,  // 2x2 grid
        childAspectRatio: 0.5,  // 512x1024 aspect ratio
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        return GestureDetector(
          onTap: () {
            Navigator.pushNamed(context, image['route']!);
          },
          child: Image.asset(
            image['path']!,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
      );
    },
  );
}


Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
        if (mounted) {
      Navigator.pushNamed(context, route);
        }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
              fontWeight: FontWeight.bold,
              fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}
StreamSubscription<List<PurchaseDetails>>? _subscription;

void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}

void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // Show a loading or pending message to the user
        _showSnackBar(context, 'Purchase is pending. Please wait...');
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
        if (mounted) {
          _showSnackBar(context, 'Purchase was canceled.');
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}


void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {
    // Purchase validation failed, log error details if necessary
   
    return false;
  }
}


  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }
  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
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


  Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
          _buildServiceTile('Remove Background',"assets/images/bgremoval.png", context, '/background-removal'),
  _buildServiceTile('Replace Background',"assets/images/bgreplace.png", context, '/background-replace'),
  _buildServiceTile('Face Swap',"assets/images/mergefaces.png", context, '/merge-faces'),
 _buildServiceTile('Restore Face',"assets/images/resface.png", context, '/restore-face'),
 
  _buildServiceTile('Remove Watermark',"assets/images/wmremoval.png", context, '/watermark-removal'),
_buildServiceTile('Remove Text',"assets/images/txtremoval.png", context, '/text-removal'),

_buildServiceTile('Text-> Image',"assets/images/txt2img.png", context, '/txt2img'),

_buildServiceTile('Image-> Image',"assets/images/img2img.png", context, '/img2img'),

_buildServiceTile('Text-> Video',"assets/images/txt2vid.png", context, '/txt2vid'),

_buildServiceTile('Image-> Video',"assets/images/img2vid.png", context, '/img2vid'),


_buildServiceTile('Size/Convert',"assets/images/convert.png", context, '/convert'),
        ],
      ),
    );
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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

 void _navigateToHomePage(BuildContext context) {
  if (context.mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
  }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}




class ApiService {
  static const String baseUrl = 'https://www.aimaker.world';
  
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
  final Uri url = Uri.parse('https://www.aimaker.world/logged');

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
Future<bool> logout(BuildContext context) async {
  final token = await getToken(); // Retrieve the stored token

  if (token == null) {

      await clearToken();
    return false; // No token means user is already logged out
  }

  try {
    // Clear the token from storage
    await clearToken();
    // Ensure widget is still in the tree before navigating
    if (context.mounted) {
      _navigateToLoginPage(context);
    }
    return true; // Successful logout

  } catch (e) {


    // Show Snackbar only if widget is mounted
    if (context.mounted) {
      _showSnackBar(context, 'Logout failed. Please try again.');
    }
    return false; // Logout failed
  }
}

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
    );
  }
}

void _showSnackBar(BuildContext context, String message) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
// Give the user credits
Future<bool> giveCredits() async {
  try{
  final token = await getToken();
  if (token == null) return false;

  final response = await http.post(
    Uri.parse('$baseUrl/give/'),
    headers: {'Authorization': 'Bearer $token'},

    body: jsonEncode({'amount': 5}),
  );

  return response.statusCode == 200;
  }catch (e) {


      await clearToken();
      return false;
  }
}
Future<int?> _fetchCredits() async {
  try {
    // Retrieve the JWT token from local storage
    final token = await getToken();
    if (token == null) {

      await clearToken();
      return null; // No token means the user is not logged in
    }

    // Make the API request to fetch the user's profile
    final response = await http.get(
      Uri.parse('$baseUrl/user/profile'),
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
class BackgroundRemovalPage extends StatefulWidget {
  const BackgroundRemovalPage({super.key}); // Super parameter syntax

  @override
  BackgroundRemovalPageState createState() => BackgroundRemovalPageState();
}


class BackgroundRemovalPageState extends State<BackgroundRemovalPage> with RouteAware {
  File? _imageFile;

  bool _isInformationVisible = false;
  bool _isLoading = false;
  String? _base64Image;
  Uint8List? _imageBytes;
  bool _isGenerateEnabled = false; // Manage generate button state

  bool _isLoggedIn = false;
  int? credits;
 
  final ApiService apiService = ApiService(); // Create instance

  @override
  void initState() {
    super.initState();

      _initializeInAppPurchaseListener();

    _checkLoginStatus();
   _fetchAndSetCredits(); // Fetch credits on initialization
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  @override
  void dispose() {
 if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  } // Clear Material Banners
      _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
     if (mounted) {
    setState(() {
      _isLoggedIn = token != null;
      if (token != null){
        credits = null;
      }
    });
     }
  }
Future<void> _pickImage() async {
if (!mounted) return;
  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
  try {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85, // Reduce size for compatibility
    );

    if (pickedFile != null) {
       if (mounted) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _imageBytes = null;
        _base64Image = base64Encode(_imageFile!.readAsBytesSync());
        _isGenerateEnabled = true; // Enable the generate button
      });
       }
    }
  } catch (e) {
     if (mounted) {
    _showMessage('Image too large, Max: 2048x2048px.');
     }
  }
  
   } else {
     if (mounted) {
    _showMessage('Enable photo library permissions for this app in settings to upload!');
     }
  }
}


void _showLoginDialog(BuildContext context) {
  if (!context.mounted) return;  // Ensure widget is mounted before showing banner

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title:  const Text("Login Required"),
        content: const  Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
                if (mounted) {

              Navigator.pushNamed(context, '/login'); // Navigate to login
                }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}

  Future<void> _generateBackgroundRemovedImage() async {
    if (!mounted) return;
    if (!_isLoggedIn) {
      _showLoginDialog(context);
      return;
    }
if (mounted) {
    setState(() {
      _isLoading = true;
    });
}
   final token = await getToken();
      if (token == null) return;
    try {
   
      const String removebackground = 'remove_background';
      final response = await http.post(
        Uri.parse('https://www.aimaker.world/generate/'),
     
        headers: {'Authorization': 'Bearer $token'},
        body: jsonEncode({'image': _base64Image,'task_type': removebackground}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
   
        final String newImageBase64 = data['image'];
          // Decode Base64 to Image and Update the UI
        Uint8List imageBytes = base64Decode(newImageBase64);
        if (mounted) {
        setState(() {
          _imageBytes = imageBytes; // Store the decoded bytes
          _base64Image = newImageBase64;
        });
        }
      
        _fetchAndSetCredits();
        if (mounted) {
             setState(() {
   
    _isGenerateEnabled = false; // Disable the generate button
  });
        }
      } else {
        if (mounted) {
        _fetchAndSetCredits();
       final data = jsonDecode(response.body);
    final String errorMessage = data['error'] ?? 'Unknown error';
    _showDisputeSnackBar2(context, token, errorMessage);
        }
        
      }
    } catch (e) {
      if (mounted) {
      _fetchAndSetCredits();
      
      
        _showDisputeSnackBar(context, token);
      }
    } finally {
if (mounted) {
      setState(() {
        _isLoading = false;
      });
}
    }
  }

   void _showDisputeSnackBar2(BuildContext context, String token, String error) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content:  Text("Something went wrong. $error."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
   }
 void _showDisputeSnackBar(BuildContext context, String token) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
    Future.delayed(const Duration(milliseconds: 20), () {if (!mounted) return;
    if (!mounted) return;
    final banner = MaterialBanner(
      content: const Text("Experiencing issues? Check common problems."),
      actions: [
        TextButton(
          onPressed: () {
              if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
            _showCommonProblemsDialog(context);
          },
          child: const Text("Common Problems"),
        ),
      ],
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.all(8),
    );
if (mounted) {
   
scaffoldMessengerKey.currentState?.showMaterialBanner(banner);
}
    // Set timer to auto-dismiss the banner after 5 seconds
    Timer(const Duration(seconds: 11), () {
      
      if (mounted) { // Check inside Timer before hiding the banner
    // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
 
  }
    });
  });
}

void _showCommonProblemsDialog(BuildContext context) {
  if (!mounted) return; // FIRST LINE inside _showCommonProblemsDialog

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Common Problems"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("1. Image Size: Ensure your image is below 5MB."),
            SizedBox(height: 8),
            Text("2. Format: Most heavily supported formats are PNG and JPG."),
            SizedBox(height: 8),
            Text("3. Network: Check your internet connection."),
            SizedBox(height: 8),
            Text("4. Usage: Is there a background to remove?."),

            Text("Not working? Try different inputs."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}


  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  

  void _showMessage(String message) {
    if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
  


Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
    

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
Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
        if (mounted) {
      Navigator.pushNamed(context, route);
        }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color:  Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
             fontWeight: FontWeight.bold,
            fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}

  void _navigateToHomePage(BuildContext context) {
    if (context.mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
    }
  }

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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

void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
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
 
StreamSubscription<List<PurchaseDetails>>? _subscription;

void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
      
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
      
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}



void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {

    return false;
  }
}

  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }

  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
}
    Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
        _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
          _buildServiceTile('Replace Background',"assets/images/bgreplace.png", context, '/background-replace'),
_buildServiceTile('Face Swap',"assets/images/mergefaces.png", context, '/merge-faces'),
          _buildServiceTile('Restore Face',"assets/images/resface.png", context, '/restore-face'),
          _buildServiceTile('Remove Watermark',"assets/images/wmremoval.png", context, '/watermark-removal'),
_buildServiceTile('Remove Text',"assets/images/txtremoval.png", context, '/text-removal'),


_buildServiceTile('Text-> Image',"assets/images/txt2img.png", context, '/txt2img'),

_buildServiceTile('Image-> Image',"assets/images/img2img.png", context, '/img2img'),

_buildServiceTile('Text-> Video',"assets/images/txt2vid.png", context, '/txt2vid'),

_buildServiceTile('Image-> Video',"assets/images/img2vid.png", context, '/img2vid'),


_buildServiceTile('Size/Convert',"assets/images/convert.png", context, '/convert'),
        ],
      ),
    );
  }
Future<void> _downloadImage() async {
  if (_imageBytes == null) return;

  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
    try {
      // Save the image to the photo gallery.
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(_imageBytes!),
        quality: 100,
        name: "background_removed_image",
      );

      if (result['isSuccess']) {
        if (mounted) {
        _showMessage('Successfully saved to photos.');
        }
      } else {
        if (mounted) {
        _showMessage('Failed to save.');
        }
      }
    } catch (e) {
      if (mounted) {
      _showMessage('Failed to save.');
      }
    }
  } else {
    if (mounted) {
    _showMessage('Enable photo library permissions for this app in settings to download!');
    }
  }
}
  
    Widget _buildInformationSection() {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 16), // Adjust top and left padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Input:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Select an image with a background.'),
        const SizedBox(height: 12),
        const Text(
          'Result:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Image with background removed.'),
        const SizedBox(height: 12),
              Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/pricing');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Pricing'),
          ),
        ),
        const SizedBox(height: 8),
        Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('More info'),
          ),
        ),
      ],
    ),
  );
}



  @override
Widget build(BuildContext context,{bool isHomePage = false}) {
  return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF5F5F5),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
            
        GestureDetector(
          onTap: () {
            if (!isHomePage) {
              if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
              }
            }
          },
          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
        IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          if (mounted) {
          Navigator.pushNamed(context, '/settings');
          }
        },
      ),const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
          _buildLogoutButton(context),
        ],
      ),
    ),
     backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
      
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
       
          _buildHorizontalList(context),
          const SizedBox(height: 24),
          const Text(
              'Remove Background',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize:25,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),
          // Improved Image Container
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(2, 4), // Shadow position
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                      ),
                    )
                  : _imageBytes != null
                      ? Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                        )
                      : _imageFile != null
                          ? Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Text(
                                'Remove a background from an image',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
            ),
          ),

          const SizedBox(height: 16),
          // Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Upload',
                    style: TextStyle(color: Colors.black),),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  
                  onPressed: _isLoading || _imageFile == null || !_isGenerateEnabled
                      ? null
                      : _generateBackgroundRemovedImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Generate',
                    style: TextStyle(color: Colors.black, fontSize: 13.55)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _imageBytes == null
                      ? null
                      : _downloadImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Download',
                    style: TextStyle(color: Colors.black, fontSize: 12.59)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Cost Display
             ElevatedButton(
              onPressed: () {
                if (mounted) {
                setState(() {
                  _isInformationVisible = !_isInformationVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Information'),
            ),
            if (_isInformationVisible) _buildInformationSection(),
        ],
      ),
    ),
  );
}

}
class BackgroundReplacePage extends StatefulWidget {
  const BackgroundReplacePage({super.key}); // Super parameter syntax

  @override
  BackgroundReplacePageState createState() => BackgroundReplacePageState();
}


class BackgroundReplacePageState extends State<BackgroundReplacePage> with RouteAware {
  File? _imageFile;

  bool _isInformationVisible = false;
  bool _isLoading = false;
  String? _base64Image;
  bool _isGenerateEnabled = false; // Manage generate button state

  Uint8List? _imageBytes;
  bool _isLoggedIn = false;
  int? credits;
  String prompt = ''; // Store the prompt text

 
  final ApiService apiService = ApiService(); // Create instance

  @override
  void initState() {
    super.initState();

      _initializeInAppPurchaseListener();
    _checkLoginStatus();
   _fetchAndSetCredits(); // Fetch credits on initialization
  }
   
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  @override
  void dispose() {
  if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  } // Clear Material Banners
      _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
                if (mounted) {
    
    setState(() {
        _isLoggedIn = token != null;
      if (token != null) {
      credits = null;
    }
    });
                }
  }
Future<void> _pickImage() async {
if (!mounted) return;
  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
  try {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 65, // Reduce size for compatibility
    );

    if (pickedFile != null) {
                if (mounted) {

      setState(() {
        _imageFile = File(pickedFile.path);
        _imageBytes = null;
        _base64Image = base64Encode(_imageFile!.readAsBytesSync());
        _isGenerateEnabled = true; // Enable the generate button
      });
                }
    }
  } catch (e) {
                if (mounted) {
    
    _showMessage('Image too large, Max: 1024x1024px.');
                }
  }
  
   } else {
                if (mounted) {

    _showMessage('Enable photo library permissions for this app in settings to upload!');
                }
  }
}


void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
                if (mounted) {

              Navigator.pushNamed(context, '/login'); // Navigate to login
                }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}

  Future<void> _generateBackgroundReplacedImage() async {
    if (!mounted) return;
    if (!_isLoggedIn) {
       _showLoginDialog(context);
      return;
    }
                if (mounted) {

    setState(() {
      _isLoading = true;
    });
                }
      final token = await getToken();
      if (token == null) return;
    try {
      const String removebackground = 'replace_background';
      final response = await http.post(
        Uri.parse('https://www.aimaker.world/generate/'),
     
        headers: {'Authorization': 'Bearer $token'},
        body: jsonEncode({'image': _base64Image,'prompt': prompt,'task_type': removebackground}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
       
        final String newImageBase64 = data['image'];
          // Decode Base64 to Image and Update the UI
        Uint8List imageBytes = base64Decode(newImageBase64);
                if (mounted) {
        
        setState(() {
          _imageBytes = imageBytes; // Store the decoded bytes
          _base64Image = newImageBase64;
        });
                }
                if (mounted) {
      
        _fetchAndSetCredits();
               

             setState(() {
   
    _isGenerateEnabled = false; // Disable the generate button
  });
                }
      } else {
                if (mounted) {

        _fetchAndSetCredits();
        final data = jsonDecode(response.body);
    final String errorMessage = data['error'] ?? 'Unknown error';
    _showDisputeSnackBar2(context, token, errorMessage);
 
      }
      }
    } catch (e) {
      
                if (mounted) {

      _fetchAndSetCredits();
         _showDisputeSnackBar(context, token);
                }
    } finally {
                if (mounted) {

      setState(() {
        _isLoading = false;
      });
                }
    }
  }
     void _showDisputeSnackBar2(BuildContext context, String token, String error) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content:  Text("Something went wrong. $error."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
   }
void _showDisputeSnackBar(BuildContext context, String token) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
    Future.delayed(const Duration(milliseconds: 20), () {if (!mounted) return;
    final banner = MaterialBanner(
      content: const Text("Experiencing issues? Check common problems."),
      actions: [
        TextButton(
          onPressed: () {
              if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
            _showCommonProblemsDialog(context);
          },
          child: const Text("Common Problems"),
        ),
      ],
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.all(8),
    );
    if (mounted) {
scaffoldMessengerKey.currentState?.showMaterialBanner(banner);
    }

    // Set timer to auto-dismiss the banner after 5 seconds
    Timer(const Duration(seconds: 11), () {
        if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
    });
  });
}

void _showCommonProblemsDialog(BuildContext context) {
  if (!mounted) return; // FIRST LINE inside _showCommonProblemsDialog

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Common Problems"),
        content: const Column(
          mainAxisSize:  MainAxisSize.min,
          children: [
            Text("1. Image Size: Ensure your image is below 5MB."),
            SizedBox(height: 8),
            Text("2. Format: Most heavily supported formats are PNG and JPG."),
            SizedBox(height: 8),
            Text("3. Network: Check your internet connection."),
            SizedBox(height: 8),
            Text("4. Usage: Is there a background to replace?."),

            Text("Not working? Try different inputs."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  


  void _showMessage(String message) {
                if (mounted) {

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
  }



Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
    

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
}Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
        if (mounted) {
      Navigator.pushNamed(context, route);
        }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child:  Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
              fontWeight: FontWeight.bold,
              fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}
void _navigateToHomePage(BuildContext context) {
   if (context.mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
   }
  }

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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

void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
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
 
StreamSubscription<List<PurchaseDetails>>? _subscription;
void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // Show a loading or pending message to the user
        _showSnackBar(context, 'Purchase is pending. Please wait...');
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
        if (mounted) {
          _showSnackBar(context, 'Purchase was canceled.');
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}



void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {
    // Purchase validation failed, log error details if necessary
   
    return false;
  }
}

  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }

  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
}
    Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
        _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
          _buildServiceTile('Remove Background',"assets/images/bgremoval.png", context, '/background-removal'),
          _buildServiceTile('Face Swap',"assets/images/mergefaces.png", context, '/merge-faces'),
          _buildServiceTile('Restore Face',"assets/images/resface.png", context, '/restore-face'),
          _buildServiceTile('Remove Watermark',"assets/images/wmremoval.png", context, '/watermark-removal'),
_buildServiceTile('Remove Text',"assets/images/txtremoval.png", context, '/text-removal'),


_buildServiceTile('Text-> Image',"assets/images/txt2img.png", context, '/txt2img'),

_buildServiceTile('Image-> Image',"assets/images/img2img.png", context, '/img2img'),

_buildServiceTile('Text-> Video',"assets/images/txt2vid.png", context, '/txt2vid'),

_buildServiceTile('Image-> Video',"assets/images/img2vid.png", context, '/img2vid'),


_buildServiceTile('Size/Convert',"assets/images/convert.png", context, '/convert'),
        ],
      ),
    );
  }
Future<void> _downloadImage() async {
  if (_imageBytes == null) return;

  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
    try {
      // Save the image to the photo gallery.
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(_imageBytes!),
        quality: 100,
        name: "background_replaced_image",
      );

      if (result['isSuccess']) {
                if (mounted) {
      
        _showMessage('Successfully saved to photos.');
                }
      } else {
                if (mounted) {

        _showMessage('Failed to save.');
                }
      }
    } catch (e) {
                if (mounted) {

      _showMessage('Failed to save.');
                }
    }
  } else {
                if (mounted) {
    
    _showMessage('Enable photo library permissions for this app in settings to download!');
                }
  }
}


  
   Widget _buildInformationSection() {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 16), // Adjust top and left padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Input:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Select an image with a background. Enter a prompt for the desired replacement.'),
        const SizedBox(height: 12),
        const Text(
          'Result:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Image with background replaced.'),
        const SizedBox(height: 12),
              Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/pricing');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Pricing'),
          ),
        ),
        const SizedBox(height: 8),
        Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('More info'),
          ),
        ),
      ],
    ),
  );
}



  @override
Widget build(BuildContext context,{bool isHomePage = false}) {
  return Scaffold(
    appBar: AppBar(
       automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF5F5F5),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          
         GestureDetector(
          onTap: () {
            if (!isHomePage) {
                if (mounted) {

              Navigator.pushReplacementNamed(context, '/home');
                }
            }
          },
          
          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
        IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
                if (mounted) {

          Navigator.pushNamed(context, '/settings');
                }
        },
      ), const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
          _buildLogoutButton(context),
        ],
      ),
    ),
     backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
     
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
       
          _buildHorizontalList(context),
          const SizedBox(height: 24),
            const Text(
              'Replace Background',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize:25,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),

          // Improved Image Container
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(2, 4), // Shadow position
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                      ),
                    )
                  : _imageBytes != null
                      ? Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                        )
                      : _imageFile != null
                          ? Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Text(
                                'Replace the background of an image',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
            ),
          ),
          
          const SizedBox(height: 16),
 TextField(
              onChanged: (value) => setState(() => prompt = value),
              decoration: InputDecoration(
                labelText: 'Enter prompt for the new background.',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Upload',
                    style: TextStyle(color: Colors.black),),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  
                  onPressed: _isLoading || _imageFile == null || !_isGenerateEnabled
                      ? null
                      : _generateBackgroundReplacedImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Generate',
                    style: TextStyle(color: Colors.black, fontSize: 13.55)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _imageBytes == null
                      ? null
                      : _downloadImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Download',
                    style: TextStyle(color: Colors.black, fontSize: 12.59)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Cost Display
             ElevatedButton(
              onPressed: () {
                if (mounted) {

                setState(() {
                  _isInformationVisible = !_isInformationVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Information'),
            ),
            if (_isInformationVisible) _buildInformationSection(),
        ],
      ),
    ),
  );
}
}
class RestoreFacePage extends StatefulWidget {
  const RestoreFacePage({super.key}); // Super parameter syntax

  @override
  RestoreFacePageState createState() => RestoreFacePageState();
}


class RestoreFacePageState extends State<RestoreFacePage> with RouteAware {
  File? _imageFile;

  bool _isInformationVisible = false;
  bool _isLoading = false;
  String? _base64Image;
  Uint8List? _imageBytes;
  bool _isLoggedIn = false;
  bool _isGenerateEnabled = false; // Manage generate button state

  bool _isAdvancedVisible = false;
  int? credits;
  double _sliderValue = 0.6;

 
  final ApiService apiService = ApiService(); // Create instance

  @override
  void initState() {

    super.initState();

      _initializeInAppPurchaseListener();
    _checkLoginStatus();
   _fetchAndSetCredits(); // Fetch credits on initialization
  }
   
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  @override
  void dispose() {
  if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  } // Clear Material Banners
      _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
                if (mounted) {
    
    setState(() {
        _isLoggedIn = token != null;
      if (token != null){
        credits = null;
      }
    });
                }
  }
Future<void> _pickImage() async {
if (!mounted) return;
  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
  try {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85, // Reduce size for compatibility
    );

    if (pickedFile != null) {
                if (mounted) {

      setState(() {
        _imageFile = File(pickedFile.path);
        _imageBytes = null;
        _base64Image = base64Encode(_imageFile!.readAsBytesSync());
        _isGenerateEnabled = true; // Enable the generate button
      });
                }
    }
  } catch (e) {
                if (mounted) {
    
    _showMessage('Image too large, Max: 1024x1024px.');
                }
  }
  
   } else {
                if (mounted) {

    _showMessage('Enable photo library permissions for this app in settings to upload!');
                }
  }
}



void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title:  const Text("Login Required"),
        content: const Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
                if (mounted) {

              Navigator.pushNamed(context, '/login'); // Navigate to login
                }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}

  Future<void> _generateRestorefaceImage() async {
    if (!mounted) return;
    if (!_isLoggedIn) {
       _showLoginDialog(context);
      return;
    }
                if (mounted) {

    setState(() {
      _isLoading = true;
    });
                }
      final token = await getToken();
      if (token == null) return;
    try {
      const String removebackground = 'restore_face';
      final response = await http.post(
        Uri.parse('https://www.aimaker.world/generate/'),
     
        headers: {'Authorization': 'Bearer $token'},
        body: jsonEncode({'image': _base64Image,'fidelity': _sliderValue,'task_type': removebackground}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final String newImageBase64 = data['image'];
          // Decode Base64 to Image and Update the UI
        Uint8List imageBytes = base64Decode(newImageBase64);
                if (mounted) {
        
        setState(() {
          _imageBytes = imageBytes; // Store the decoded bytes
          _base64Image = newImageBase64;
        });

      
        _fetchAndSetCredits();
             setState(() {
   
    _isGenerateEnabled = false; // Disable the generate button
  });
                }
      } else {
                if (mounted) {

        _fetchAndSetCredits();
         final data = jsonDecode(response.body);
    final String errorMessage = data['error'] ?? 'Unknown error';
    _showDisputeSnackBar2(context, token, errorMessage);
      }
      }
    } catch (e) {
                if (mounted) {

      _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
                }
    } finally {
                if (mounted) {

      setState(() {
        _isLoading = false;
      });
                }
    }
  }
     void _showDisputeSnackBar2(BuildContext context, String token, String error) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content:  Text("Something went wrong. $error."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
   }
  void _showDisputeSnackBar(BuildContext context, String token) {
    if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
    Future.delayed(const Duration(milliseconds: 20), () {if (!mounted) return;
    final banner = MaterialBanner(
      content: const Text("Experiencing issues? Check common problems."),
      actions: [
        TextButton(
          onPressed: () {
              if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
            _showCommonProblemsDialog(context);
          },
          child: const Text("Common Problems"),
        ),
      ],
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.all(8),
    );
                if (mounted) {

scaffoldMessengerKey.currentState?.showMaterialBanner(banner);
                }
    // Set timer to auto-dismiss the banner after 5 seconds
    Timer(const Duration(seconds: 11), () {
        if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
    });
  });
}

void _showCommonProblemsDialog(BuildContext context) {
  if (!mounted) return; // FIRST LINE inside _showCommonProblemsDialog

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Common Problems"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("1. Image Size: Ensure your image is below 5MB."),
            SizedBox(height: 8),
            Text("2. Format: Most heavily supported formats are PNG and JPG."),
            SizedBox(height: 8),
            Text("3. Network: Check your internet connection."),
            SizedBox(height: 8),
            Text("4. Usage: Is there a face to restore?."),

            Text("Not working? Try different inputs."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  

  void _showMessage(String message) {
                if (mounted) {

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
  }
 


Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
    

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
}Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
        if (mounted) {
      Navigator.pushNamed(context, route);
        }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
              fontWeight: FontWeight.bold,
              fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}

  void _navigateToHomePage(BuildContext context) {
                if (context.mounted) {

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
                }
  }

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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
void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
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
 
StreamSubscription<List<PurchaseDetails>>? _subscription;
void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // Show a loading or pending message to the user
        _showSnackBar(context, 'Purchase is pending. Please wait...');
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
        if (mounted) {
          _showSnackBar(context, 'Purchase was canceled.');
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}



void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {

    return false;
  }
}

  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }

  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
}
    Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
        _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
          _buildServiceTile('Remove Background',"assets/images/bgremoval.png", context, '/background-removal'),

        
        
          _buildServiceTile('Replace Background',"assets/images/bgreplace.png", context, '/background-replace'),
         _buildServiceTile('Face Swap',"assets/images/mergefaces.png", context, '/merge-faces'),
          _buildServiceTile('Remove Watermark',"assets/images/wmremoval.png", context, '/watermark-removal'),
_buildServiceTile('Remove Text',"assets/images/txtremoval.png", context, '/text-removal'),


_buildServiceTile('Text-> Image',"assets/images/txt2img.png", context, '/txt2img'),

_buildServiceTile('Image-> Image',"assets/images/img2img.png", context, '/img2img'),

_buildServiceTile('Text-> Video',"assets/images/txt2vid.png", context, '/txt2vid'),

_buildServiceTile('Image-> Video',"assets/images/img2vid.png", context, '/img2vid'),


_buildServiceTile('Size/Convert',"assets/images/convert.png", context, '/convert'),
        ],
      ),
    );
  }
Future<void> _downloadImage() async {
  if (_imageBytes == null) return;

  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
    try {
      // Save the image to the photo gallery.
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(_imageBytes!),
        quality: 100,
        name: "restoredface_image",
      );

      if (result['isSuccess']) {
      
                if (mounted) {
      
        _showMessage('Successfully saved to photos.');
                }
      } else {
                if (mounted) {

        _showMessage('Failed to save.');
                }
      }
    } catch (e) {
                if (mounted) {

        _showMessage('Failed to save.');
                }
    }
  } else {
                if (mounted) {
 
    _showMessage('Enable photo library permissions for this app in settings to download!');
                }
  }
}
  

  
Widget buildSliderInput(String label, double currentValue, double min, double max, Function(double) onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center, // Center-align within the column
    children: [
      Center( // Center-align the label text
        child: Text(
          label,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
      Slider(
        value: currentValue,
        min: min,
        max: max,
        divisions: 9,
        label: currentValue.toStringAsFixed(1),
        onChanged: onChanged,
      ),
    ],
  );
}



Widget buildAdvancedOptions() {
  
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

            const SizedBox(height: 8),
      buildSliderInput('Fidelity:', _sliderValue, 0.1, 1, (value) {
                if (mounted) {

        setState(() => _sliderValue = value); // Set the new slider value
                }
      }),
    ],
  );
}
     Widget _buildInformationSection() {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 16), // Adjust top and left padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Input:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Select an image with a face visible. Increase the fidelity to increase details kept or vice verse.'),
        const SizedBox(height: 12),
        const Text(
          'Result:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Image with face unblured, unwrinkled, restored.'),
       const SizedBox(height: 12),
              Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/pricing');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Pricing'),
          ),
        ),
        const SizedBox(height: 8),
        Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('More info'),
          ),
        ),
       
         
      ],
    ),
  );
}


  @override
Widget build(BuildContext context,{bool isHomePage = false}) {
  return Scaffold(
    appBar: AppBar(
       automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF5F5F5),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           
         GestureDetector(
          onTap: () {
            if (!isHomePage) {
                if (mounted) {

              Navigator.pushReplacementNamed(context, '/home');
                }
            }
          },
          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
        IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
                if (mounted) {

          Navigator.pushNamed(context, '/settings');
                }
        },
      ),const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
          _buildLogoutButton(context),
        ],
      ),
    ),
     backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
   
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
       
          _buildHorizontalList(context),
          const SizedBox(height: 24),
            const Text(
              'Restore Face',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize:25,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),
          // Improved Image Container
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(2, 4), // Shadow position
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                      ),
                    )
                  : _imageBytes != null
                      ? Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                        )
                      : _imageFile != null
                          ? Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Text(
                                'Restore a face from an image',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
            ),
          ),

          const SizedBox(height: 16),
          // Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Upload',
                    style: TextStyle(color: Colors.black),),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
               
                  onPressed: _isLoading || _imageFile == null || !_isGenerateEnabled
                      ? null
                      : _generateRestorefaceImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Generate',
                    style: TextStyle(color: Colors.black, fontSize: 13.55)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _imageBytes == null
                      ? null
                      : _downloadImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Download',
                    style: TextStyle(color: Colors.black, fontSize: 12.59)),
                ),
              ),
            ],
          ),
     const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (mounted) {

                setState(() {
                  _isAdvancedVisible = !_isAdvancedVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Advanced Options'),
            ),
            if (_isAdvancedVisible) buildAdvancedOptions(),
              

          const SizedBox(height: 16),
          // Cost Display
             ElevatedButton(
              onPressed: () {
                if (mounted) {

                setState(() {
                  _isInformationVisible = !_isInformationVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Information'),
            ),
            if (_isInformationVisible) _buildInformationSection(),
        ],
      ),
    ),
  );
}
}
class WatermarkRemovalPage extends StatefulWidget {
  const WatermarkRemovalPage({super.key}); // Super parameter syntax

  @override
  WatermarkRemovalPageState createState() => WatermarkRemovalPageState();
}


class WatermarkRemovalPageState extends State<WatermarkRemovalPage> with RouteAware {
  File? _imageFile;

  bool _isInformationVisible = false;
  bool _isLoading = false;
  String? _base64Image;
  Uint8List? _imageBytes;
  bool _isLoggedIn = false;
  bool _isGenerateEnabled = false; // Manage generate button state

  int? credits;
 
  final ApiService apiService = ApiService(); // Create instance

  @override
  void initState() {
    super.initState();

      _initializeInAppPurchaseListener();
    _checkLoginStatus();
   _fetchAndSetCredits(); // Fetch credits on initialization
  }
   
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  @override
  void dispose() {
  if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  }  // Clear Material Banners
      _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
                if (mounted) {

    setState(() {
      _isLoggedIn = token != null;
      if (token != null){
        credits = null;
      }
    });
                }
  }
Future<void> _pickImage() async {
if (!mounted) return;
  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
  try {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85, // Reduce size for compatibility
    );

    if (pickedFile != null) {
                if (mounted) {

      setState(() {
        _imageFile = File(pickedFile.path);
        _imageBytes = null;
        _base64Image = base64Encode(_imageFile!.readAsBytesSync());
        _isGenerateEnabled = true; // Enable the generate button
      });
    }
    }
  } catch (e) {
                if (mounted) {
    
    _showMessage('Image too large, Max: 1024x1024px.');
                }
  }
  
   } else {
                if (mounted) {

    _showMessage('Enable photo library permissions for this app in settings to upload!');
                }
  }
}




void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
                if (context.mounted) {

              Navigator.pushNamed(context, '/login'); // Navigate to login
                }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}

  Future<void> _generateWatermarkedRemovedImage() async {
    if (!mounted) return;
    if (!_isLoggedIn) {
       _showLoginDialog(context);
      return;
    }
                if (mounted) {

    setState(() {
      _isLoading = true;
    });
                }
      final token = await getToken();
      if (token == null) return;
    try {
    
      const String removebackground = 'remove_watermark';
      final response = await http.post(
        Uri.parse('https://www.aimaker.world/generate/'),
     
        headers: {'Authorization': 'Bearer $token'},
        body: jsonEncode({'image': _base64Image,'task_type': removebackground}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        final String newImageBase64 = data['image'];
          // Decode Base64 to Image and Update the UI
        Uint8List imageBytes = base64Decode(newImageBase64);
                if (mounted) {
        
        setState(() {
          _imageBytes = imageBytes; // Store the decoded bytes
          _base64Image = newImageBase64;
        });

      
        _fetchAndSetCredits();
             setState(() {
   
    _isGenerateEnabled = false; // Disable the generate button
  });
                }
      } else {
                if (mounted) {

        _fetchAndSetCredits();
            final data = jsonDecode(response.body);
    final String errorMessage = data['error'] ?? 'Unknown error';
    _showDisputeSnackBar2(context, token, errorMessage);
                }
      }
    } catch (e) {
                if (mounted) {

      _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
                }
    } finally {
                if (mounted) {

      setState(() {
        _isLoading = false;
      }
      );}
    }
  }
     void _showDisputeSnackBar2(BuildContext context, String token, String error) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content:  Text("Something went wrong. $error."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
   }
  void _showDisputeSnackBar(BuildContext context, String token) {
    if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
    Future.delayed(const Duration(milliseconds: 20), () {if (!mounted) return;
    final banner = MaterialBanner(
      content: const Text("Experiencing issues? Check common problems."),
      actions: [
        TextButton(
          onPressed: () {
              if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
            _showCommonProblemsDialog(context);
          },
          child: const Text("Common Problems"),
        ),
      ],
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.all(8),
    );
                if (mounted) {

scaffoldMessengerKey.currentState?.showMaterialBanner(banner);
                }
    // Set timer to auto-dismiss the banner after 5 seconds
    Timer(const Duration(seconds: 11), () {
        if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
    });
  });
}

void _showCommonProblemsDialog(BuildContext context) {
  if (!mounted) return; // FIRST LINE inside _showCommonProblemsDialog

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Common Problems"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("1. Image Size: Ensure your image is below 5MB."),
            SizedBox(height: 8),
            Text("2. Format: Most heavily supported formats are PNG and JPG."),
            SizedBox(height: 8),
            Text("3. Network: Check your internet connection."),
            SizedBox(height: 8),
            Text("4. Usage: Is there a watermark to remove?."),

            Text("Not working? Try different inputs."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  

  void _showMessage(String message) {
                if (mounted) {

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
  }
  


Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
    

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
}Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
        if (mounted) {
      Navigator.pushNamed(context, route);
        }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
              fontWeight: FontWeight.bold,
              fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}

  void _navigateToHomePage(BuildContext context) {
                if (context.mounted) {

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
                }
  }

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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

void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
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
  
StreamSubscription<List<PurchaseDetails>>? _subscription;

void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // Show a loading or pending message to the user
        _showSnackBar(context, 'Purchase is pending. Please wait...');
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
        if (mounted) {
          _showSnackBar(context, 'Purchase was canceled.');
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}



void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {

    return false;
  }
}

  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }

  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
}
    Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
        _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
          _buildServiceTile('Remove Background',"assets/images/bgremoval.png", context, '/background-removal'),
          _buildServiceTile('Replace Background',"assets/images/bgreplace.png", context, '/background-replace'),
_buildServiceTile('Face Swap',"assets/images/mergefaces.png", context, '/merge-faces'),
          _buildServiceTile('Restore Face',"assets/images/resface.png", context, '/restore-face'),

        _buildServiceTile('Remove Text',"assets/images/txtremoval.png", context, '/text-removal'),


_buildServiceTile('Text-> Image',"assets/images/txt2img.png", context, '/txt2img'),

_buildServiceTile('Image-> Image',"assets/images/img2img.png", context, '/img2img'),

_buildServiceTile('Text-> Video',"assets/images/txt2vid.png", context, '/txt2vid'),

_buildServiceTile('Image-> Video',"assets/images/img2vid.png", context, '/img2vid'),


_buildServiceTile('Size/Convert',"assets/images/convert.png", context, '/convert'),
        ],
      ),
    );
  }
Future<void> _downloadImage() async {
  if (_imageBytes == null) return;

  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
    try {
      // Save the image to the photo gallery.
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(_imageBytes!),
        quality: 100,
        name: "watermarkremoval_image",
      );

      if (result['isSuccess']) {
                if (mounted) {

        _showMessage('Successfully saved to photos.');
                }
      } else {
                if (mounted) {

        _showMessage('Failed to save.');
                }
      }
    } catch (e) {
                if (mounted) {

      _showMessage('Failed to save.');
                }
    }
  } else {
                if (mounted) {

    _showMessage('Enable photo library permissions for this app in settings to download!');
                }
  }
}
  
    
    Widget _buildInformationSection() {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 16), // Adjust top and left padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:  [
       const Text(
          'Input:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Select an image with a watermark visible.'),
       const SizedBox(height: 12),
       const Text(
          'Result:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
       const SizedBox(height: 4),
       const Text('Image without watermarks.'),
       const SizedBox(height: 12),
              Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/pricing');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Pricing'),
          ),
        ),
        const SizedBox(height: 8),
        Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('More info'),
          ),
        ),
      ],
    ),
  );
}




  @override
Widget build(BuildContext context,{bool isHomePage = false}) {
  return Scaffold(
    appBar: AppBar(
       automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF5F5F5),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
              
        GestureDetector(
          onTap: () {
            if (!isHomePage) {
                if (mounted) {

              Navigator.pushReplacementNamed(context, '/home');
                }
            }
          },
          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
                if (mounted) {

          Navigator.pushNamed(context, '/settings');
          }
        },
      ),const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
          _buildLogoutButton(context),
        ],
      ),
    ),
     backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
     
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
      
          _buildHorizontalList(context),
          const SizedBox(height: 24),
            const Text(
              'Remove Watermark',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize:25,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),
          // Improved Image Container
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(2, 4), // Shadow position
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                      ),
                    )
                  : _imageBytes != null
                      ? Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                        )
                      : _imageFile != null
                          ? Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Text(
                                'Remove a watermark from an image',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
            ),
          ),

          const SizedBox(height: 16),
          // Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Upload',
                    style: TextStyle(color: Colors.black),),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                
                  onPressed: _isLoading || _imageFile == null || !_isGenerateEnabled
                      ? null
                      : _generateWatermarkedRemovedImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Generate',
                    style: TextStyle(color: Colors.black, fontSize: 13.55)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _imageBytes == null
                      ? null
                      : _downloadImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Download',
                    style: TextStyle(color: Colors.black, fontSize: 12.59)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Cost Display
             ElevatedButton(
              onPressed: () {
                if (mounted) {

                setState(() {
                  _isInformationVisible = !_isInformationVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Information'),
            ),
            if (_isInformationVisible) _buildInformationSection(),
        ],
      ),
    ),
  );
}
}
class TextRemovalPage extends StatefulWidget {
  const TextRemovalPage({super.key}); // Super parameter syntax

  @override
  TextRemovalPageState createState() => TextRemovalPageState();
}


class TextRemovalPageState extends State<TextRemovalPage> with RouteAware {
 
  bool _isLoading = false;

  bool _isInformationVisible = false;
  bool _isGenerateEnabled = false; // Manage generate button state
 File? _imageFile;
  String? _base64Image;
  Uint8List? _imageBytes;
  bool _isLoggedIn = false;
  int? credits;
 
  final ApiService apiService = ApiService(); // Create instance

  @override
  void initState() {
    super.initState();

      _initializeInAppPurchaseListener();
    _checkLoginStatus();
   _fetchAndSetCredits(); // Fetch credits on initialization
  }
   
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  @override
  void dispose() {

 if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  }  // Clear Material Banners
      _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
                if (mounted) {

    setState(() {
      _isLoggedIn = token != null;
      if (token != null){
        credits = null;
      }
    });
    }
  }
Future<void> _pickImage() async {
if (!mounted) return;
  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
  try {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85, // Reduce size for compatibility
    );

    if (pickedFile != null) {
                if (mounted) {

      setState(() {
        _imageFile = File(pickedFile.path);
        _imageBytes = null;
        _base64Image = base64Encode(_imageFile!.readAsBytesSync());
        _isGenerateEnabled = true; // Enable the generate button
      });
                }
    }
  } catch (e) {
                if (mounted) {
    
    _showMessage('Image too large, Max: 1024x1024px.');
                }
  }
  
   } else {
                if (mounted) {

    _showMessage('Enable photo library permissions for this app in settings to upload!');
                }
  }
}


void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
                if (mounted) {

              Navigator.pushNamed(context, '/login'); // Navigate to login
                }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}


  Future<void> _generateTextRemovedImage() async {
    if (!mounted) return;
    if (!_isLoggedIn) {
       _showLoginDialog(context);
      return;
    }
                if (mounted) {

    setState(() {
      _isLoading = true;
    });
                }
      final token = await getToken();
      if (token == null) return;
    try {
  
      const String removebackground = 'remove_text';
      final response = await http.post(
        Uri.parse('https://www.aimaker.world/generate/'),
     
        headers: {'Authorization': 'Bearer $token'},
        body: jsonEncode({'image': _base64Image,'task_type': removebackground}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
    
        final String newImageBase64 = data['image'];
          // Decode Base64 to Image and Update the UI
        Uint8List imageBytes = base64Decode(newImageBase64);
                if (mounted) {
        
        setState(() {
          _imageBytes = imageBytes; // Store the decoded bytes
          _base64Image = newImageBase64;
        });
                
      
        _fetchAndSetCredits();
             setState(() {
   
    _isGenerateEnabled = false; // Disable the generate button
  });}
      } else {
                if (mounted) {

        _fetchAndSetCredits();
         final data = jsonDecode(response.body);
    final String errorMessage = data['error'] ?? 'Unknown error';
    _showDisputeSnackBar2(context, token, errorMessage);  }
      }
    } catch (e) {
                if (mounted) {

      _fetchAndSetCredits();
         _showDisputeSnackBar(context, token);  }} finally {
                if (mounted) {

      setState(() {
        _isLoading = false;
      });}
    }
  }
     void _showDisputeSnackBar2(BuildContext context, String token, String error) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content:  Text("Something went wrong. $error."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
   }
  void _showDisputeSnackBar(BuildContext context, String token) {
    if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
    Future.delayed(const Duration(milliseconds: 20), () {if (!mounted) return;
    final banner = MaterialBanner(
      content: const Text("Experiencing issues? Check common problems."),
      actions: [
        TextButton(
          onPressed: () {
              if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
            _showCommonProblemsDialog(context);
          },
          child: const Text("Common Problems"),
        ),
      ],
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.all(8),
    );
                if (mounted) {

scaffoldMessengerKey.currentState?.showMaterialBanner(banner);
                }
    // Set timer to auto-dismiss the banner after 5 seconds
    Timer(const Duration(seconds: 11), () {
        if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
    });
  });
}

void _showCommonProblemsDialog(BuildContext context) {
  if (!mounted) return; // FIRST LINE inside _showCommonProblemsDialog

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Common Problems"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("1. Image Size: Ensure your image is below 5MB."),
            SizedBox(height: 8),
            Text("2. Format: Most heavily supported formats are PNG and JPG."),
            SizedBox(height: 8),
            Text("3. Network: Check your internet connection."),
            SizedBox(height: 8),
            Text("4. Usage: Is there text to remove?."),

            Text("Not working? Try different inputs."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  

  void _showMessage(String message) {
                if (mounted) {

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
  }
  


Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
    

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
}Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
  if (mounted) {
      Navigator.pushNamed(context, route);
  }
    
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
              fontWeight: FontWeight.bold,
              fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}

  void _navigateToHomePage(BuildContext context) {
                if (context.mounted) {

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
                }
  }

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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

void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
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
  
StreamSubscription<List<PurchaseDetails>>? _subscription;

void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // Show a loading or pending message to the user
        _showSnackBar(context, 'Purchase is pending. Please wait...');
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
        if (mounted) {
          _showSnackBar(context, 'Purchase was canceled.');
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}



void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {

    return false;
  }
}

  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }

  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
}
    Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
        _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
          _buildServiceTile('Remove Background',"assets/images/bgremoval.png", context, '/background-removal'),
          _buildServiceTile('Replace Background',"assets/images/bgreplace.png", context, '/background-replace'),
_buildServiceTile('Face Swap',"assets/images/mergefaces.png", context, '/merge-faces'),
          _buildServiceTile('Restore Face',"assets/images/resface.png", context, '/restore-face'),
_buildServiceTile('Remove Watermark',"assets/images/wmremoval.png", context, '/watermark-removal'),
 

_buildServiceTile('Text-> Image',"assets/images/txt2img.png", context, '/txt2img'),

_buildServiceTile('Image-> Image',"assets/images/img2img.png", context, '/img2img'),

_buildServiceTile('Text-> Video',"assets/images/txt2vid.png", context, '/txt2vid'),

_buildServiceTile('Image-> Video',"assets/images/img2vid.png", context, '/img2vid'),


_buildServiceTile('Size/Convert',"assets/images/convert.png", context, '/convert'),
        ],
      ),
    );
  }
Future<void> _downloadImage() async {
  if (_imageBytes == null) return;

  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
    try {
      // Save the image to the photo gallery.
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(_imageBytes!),
        quality: 100,
        name: "textremoval_image",
      );

      if (result['isSuccess']) {
                if (mounted) {

        _showMessage('Successfully saved to photos.');
                }
      } else {
                if (mounted) {

        _showMessage('Failed to save.');
                }
      }
    } catch (e) {
                if (mounted) {

      _showMessage('Failed to save.');
                }

    }
  } else {
                if (mounted) {

    _showMessage('Enable photo library permissions for this app in settings to download!');
                }
  }

}
  
    
    Widget _buildInformationSection() {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 16), // Adjust top and left padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:  [
        const Text(
          'Input:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Select an image with text visible.'),
        const SizedBox(height: 12),
        const Text(
          'Result:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Image without text.'),
        const SizedBox(height: 12),
              Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/pricing');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Pricing'),
          ),
        ),
        const SizedBox(height: 8),
        Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('More info'),
          ),
        ),
      ],
    ),
  );
}


  @override
Widget build(BuildContext context,{bool isHomePage = false}) {
  return Scaffold(
    appBar: AppBar(
       automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF5F5F5),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
            
        GestureDetector(
          onTap: () {
            if (!isHomePage) {
                if (mounted) {

              Navigator.pushReplacementNamed(context, '/home');
                }
            }
          },
          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
        IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
                if (mounted) {

          Navigator.pushNamed(context, '/settings');
                }
        },
      ),const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
          _buildLogoutButton(context),
        ],
      ),
    ),
     backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
      
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
       
          _buildHorizontalList(context),
          const SizedBox(height: 24),
            const Text(
              'Remove Text',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize:25,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),
          // Improved Image Container
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(2, 4), // Shadow position
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                      ),
                    )
                  : _imageBytes != null
                      ? Image.memory(
                          _imageBytes!,
                          fit: BoxFit.cover,
                        )
                      : _imageFile != null
                          ? Image.file(
                              _imageFile!,
                              fit: BoxFit.cover,
                            )
                          : const Center(
                              child: Text(
                                'Remove text from an image',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
            ),
          ),

          const SizedBox(height: 16),
          // Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Upload',
                    style: TextStyle(color: Colors.black),),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                
                  onPressed: _isLoading || _imageFile == null || !_isGenerateEnabled
                      ? null
                      : _generateTextRemovedImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Generate',
                    style: TextStyle(color: Colors.black, fontSize: 13.55)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _imageBytes == null
                      ? null
                      : _downloadImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Download',
                    style: TextStyle(color: Colors.black, fontSize: 12.59)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Cost Display
             ElevatedButton(
              onPressed: () {
                if (mounted) {

                setState(() {
                  _isInformationVisible = !_isInformationVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Information'),
            ),
            if (_isInformationVisible) _buildInformationSection(),
        ],
      ),
    ),
  );
}
}




class MergeFacePage extends StatefulWidget {
  const MergeFacePage({super.key}); // Super parameter syntax

  @override
  MergeFacePageState createState() => MergeFacePageState();
}

class MergeFacePageState extends State<MergeFacePage> with RouteAware {
  File? _baseImageFile;
File? _faceImageFile;

  bool _isInformationVisible = false;
bool _isGenerateEnabled = false; // Manage generate button state

String? _base64BaseImage;
String? _base64FaceImage;

  bool _isLoading = false;
  
  Uint8List? _imageBytes;
  bool _isLoggedIn = false;
  int? credits;
 
  final ApiService apiService = ApiService(); // Create instance

  @override
  void initState() {
    super.initState();

      _initializeInAppPurchaseListener();
    _checkLoginStatus();
   _fetchAndSetCredits(); // Fetch credits on initialization
  }
   
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  @override
  void dispose() {
  if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  } // Clear Material Banners
      _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
    if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
                if (mounted) {

    setState(() {
      _isLoggedIn = token != null;
      if (token != null){
        credits = null;
      }
    });
                }
  }
Future<void> _pickBaseImage() async {
  await _pickImage(isBaseImage: true);
}

Future<void> _pickFaceImage() async {
  await _pickImage(isBaseImage: false);
}

Future<void> _pickImage({required bool isBaseImage}) async {
  if (!mounted) return;
   final status = await Permission.photos.request();
  if (status.isGranted) {
  
  try {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1048,
      maxHeight: 1048,
      imageQuality: 75,
    );

    if (pickedFile != null) {
                if (mounted) {

      setState(() {
_isGenerateEnabled = true; // Enable the generate button
    _imageBytes = null;  // Store the result image bytes
        if (isBaseImage) {
          _baseImageFile = File(pickedFile.path);
          _base64BaseImage = base64Encode(_baseImageFile!.readAsBytesSync());

        } else {
          _faceImageFile = File(pickedFile.path);
          _base64FaceImage = base64Encode(_faceImageFile!.readAsBytesSync());
        }
      });
                }
    }
  } catch (e) {
                if (mounted) {
    
    _showMessage('Image too large, Max: 1024x1024px.');
                }
  }
     } else {
                if (mounted) {

    _showMessage('Enable photo library permissions for this app in settings to upload!');
                }
  }
}


void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
                if (mounted) {

              Navigator.pushNamed(context, '/login'); // Navigate to login
                }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}

  Future<void> _generateMergeFacesImage() async {
    if (!mounted) return;
    if (!_isLoggedIn) {
       _showLoginDialog(context);
      return;
    }
if (_base64BaseImage == null || _base64FaceImage == null) {
                if (mounted) {

  _showMessage('Please upload both a base face and a new face image!');
                }
  return;
}
                if (mounted) {

    setState(() {
      _isLoading = true;
    });
                }
      final token = await getToken();
      if (token == null) return;
    try {
  
      const String removebackground = 'merge_face';
      final response = await http.post(
  Uri.parse('https://www.aimaker.world/generate/'),
  headers: {'Authorization': 'Bearer $token'},
  body: jsonEncode({
    'image': _base64BaseImage,
    'face_image': _base64FaceImage,
    'task_type': removebackground
  }),
);

if (response.statusCode == 200) {
  final data = jsonDecode(response.body);
  
  
  // Get the new image as Base64 and decode it
  final String newImageBase64 = data['image'];
  Uint8List imageBytes = base64Decode(newImageBase64);
                if (mounted) {
  
  setState(() {
    _imageBytes = imageBytes;  // Store the result image bytes
    _baseImageFile = null;     // Clear the uploaded base image
    _faceImageFile = null;     // Clear the uploaded face image
  });

  _fetchAndSetCredits();
       setState(() {
   
    _isGenerateEnabled = false; // Disable the generate button
  });
                }
} else {
                if (mounted) {

  _fetchAndSetCredits();
     final data = jsonDecode(response.body);
    final String errorMessage = data['error'] ?? 'Unknown error';
    _showDisputeSnackBar2(context, token, errorMessage);}
}
     
    } catch (e) {
                if (mounted) {

      _fetchAndSetCredits();
       _showDisputeSnackBar(context, token);
       }  } finally {
                if (mounted) {

      setState(() {
        _isLoading = false;
      });
                }
    }
  }
     void _showDisputeSnackBar2(BuildContext context, String token, String error) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content:  Text("Something went wrong. $error."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
   }
  void _showDisputeSnackBar(BuildContext context, String token) {
    if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
    Future.delayed(const Duration(milliseconds: 20), () {if (!mounted) return;
    final banner = MaterialBanner(
      content: const Text("Experiencing issues? Check common problems."),
      actions: [
        TextButton(
          onPressed: () {
              if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
            _showCommonProblemsDialog(context);
          },
          child: const Text("Common Problems"),
        ),
      ],
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.all(8),
    );
                if (mounted) {

scaffoldMessengerKey.currentState?.showMaterialBanner(banner);
                }
    // Set timer to auto-dismiss the banner after 5 seconds
    Timer(const Duration(seconds: 11), () {
        if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
    });
  });
}

void _showCommonProblemsDialog(BuildContext context) {
  if (!mounted) return; // FIRST LINE inside _showCommonProblemsDialog

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Common Problems"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("1. Image Size: Ensure your image is below 5MB."),
            SizedBox(height: 8),
            Text("2. Format: Most heavily supported formats are PNG and JPG."),
            SizedBox(height: 8),
            Text("3. Network: Check your internet connection."),
            SizedBox(height: 8),
            Text("4. Usage: Are the faces the same? Are the faces visible?."),

            Text("Not working? Try different inputs."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  

  void _showMessage(String message) {
                if (mounted) {

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
  }
  


Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
    

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
}Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
        if (mounted) {
      Navigator.pushNamed(context, route);
        }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
              fontWeight: FontWeight.bold,
              fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}

  void _navigateToHomePage(BuildContext context) {
                if (context.mounted) {

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
                }
  }

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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

void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
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
  
StreamSubscription<List<PurchaseDetails>>? _subscription;
void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // Show a loading or pending message to the user
        _showSnackBar(context, 'Purchase is pending. Please wait...');
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
        if (mounted) {
          _showSnackBar(context, 'Purchase was canceled.');
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}



void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {

    return false;
  }
}

  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }

  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
}
    Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
        _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
          _buildServiceTile('Remove Background',"assets/images/bgremoval.png", context, '/background-removal'),
          _buildServiceTile('Replace Background',"assets/images/bgreplace.png", context, '/background-replace'),

          _buildServiceTile('Restore Face',"assets/images/resface.png", context, '/restore-face'),
_buildServiceTile('Remove Watermark',"assets/images/wmremoval.png", context, '/watermark-removal'),
        
        _buildServiceTile('Remove Text',"assets/images/txtremoval.png", context, '/text-removal'),


_buildServiceTile('Text-> Image',"assets/images/txt2img.png", context, '/txt2img'),

_buildServiceTile('Image-> Image',"assets/images/img2img.png", context, '/img2img'),

_buildServiceTile('Text-> Video',"assets/images/txt2vid.png", context, '/txt2vid'),

_buildServiceTile('Image-> Video',"assets/images/img2vid.png", context, '/img2vid'),


_buildServiceTile('Size/Convert',"assets/images/convert.png", context, '/convert'),
        ],
      ),
    );
  }
Future<void> _downloadImage() async {
  if (_imageBytes == null) return;

  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
    try {
      // Save the image to the photo gallery.
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(_imageBytes!),
        quality: 100,
        name: "mergefaces_image",
      );

      if (result['isSuccess']) {
                if (mounted) {

        _showMessage('Successfully saved to photos.');
                }
      } else {
                if (mounted) {

        _showMessage('Failed to save.');
                }
      }
    } catch (e) {
                if (mounted) {

      _showMessage('Failed to save.');
                }
    }
  } else {
                if (mounted) {

    _showMessage('Enable photo library permissions for this app in settings to download!');
                }
  }
}
 
    
   Widget _buildInformationSection() {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 16), // Adjust top and left padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:  [
        const Text(
          'Input:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Select a image with a visible face to use as the base face. Select a image with a visible face to merge onto the base.'),
        const SizedBox(height: 12),
        const Text(
          'Result:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Base image with faces merged.'),
         const SizedBox(height: 12),
              Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/pricing');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Pricing'),
          ),
        ),
        const SizedBox(height: 8),
        Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('More info'),
          ),
        ),
   
      ],
    ),
  );
}


  @override
Widget build(BuildContext context,{bool isHomePage = false}) {
  return Scaffold(
    appBar: AppBar(
       automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF5F5F5),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          
        GestureDetector(
          onTap: () {
            if (!isHomePage) {
                if (mounted) {

              Navigator.pushReplacementNamed(context, '/home');
                }
            }
          },
          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
        IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
                if (mounted) {

          Navigator.pushNamed(context, '/settings');
                }
        },
      ),const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
          _buildLogoutButton(context),
        ],
      ),
    ),
     backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
     
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHorizontalList(context),
          const SizedBox(height: 24),
            const Text(
              'Face Swap',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize:25,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),
          // Improved Image Container
         Container(
  height: 300,  // Height for the full image container
  width: double.infinity,
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: Colors.deepPurple, width: 2),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        spreadRadius: 2,
        blurRadius: 8,
        offset: const Offset(2, 4),  // Shadow position
      ),
    ],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
          )
        : _imageBytes != null
            ? Image.memory(
                _imageBytes!,
                fit: BoxFit.fill,  // Ensure the result image fills the container
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,  // Ensure both images stretch evenly
                children: [
                  // Base Image Half
                  Expanded(
                    child: Container(
                      child: _baseImageFile != null
                          ? FittedBox(
                              fit: BoxFit.fill,  // Force it to fill the space
                              child: Image.file(_baseImageFile!),
                            )
                          : const Center(
                              child: Text(
                                'Base Face',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                    ),
                  ),
                  // Face Image Half
                  Expanded(
                    child: Container(
                      child: _faceImageFile != null
                          ? FittedBox(
                              fit: BoxFit.fill,  // Force it to fill the space
                              child: Image.file(_faceImageFile!),
                            )
                          : const Center(
                              child: Text(
                                'New Face',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
  ),
),
          const SizedBox(height: 16),
          // Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

    const SizedBox(width: 8),
              Expanded(
               
      child: ElevatedButton(
        onPressed: _isLoading ? null : _pickBaseImage,
          style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Upload Base',
                    style: TextStyle(color: Colors.black),),
                ),
    ),
    const SizedBox(width: 8),
     Expanded(
                child: ElevatedButton(
                       
        onPressed: _isLoading ? null : _pickFaceImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Upload Face',
                    style: TextStyle(color: Colors.black),),
                ),
              ),
      ],
          ),
      Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                 onPressed: _isLoading || _baseImageFile == null || _faceImageFile == null || !_isGenerateEnabled
           
    ? null
    : _generateMergeFacesImage,

                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Generate',
                  
                    style: TextStyle(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _imageBytes == null
                      ? null
                      : _downloadImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Download',
                    style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          // Cost Display
             ElevatedButton(
              onPressed: () {
                if (mounted) {

                setState(() {
                  _isInformationVisible = !_isInformationVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Information'),
            ),
            if (_isInformationVisible) _buildInformationSection(),
        ],
      ),
    ),
  );
}
}
class DoodlePage extends StatefulWidget {
  const DoodlePage({super.key});

  @override
  DoodlePageState createState() => DoodlePageState();
}

class DoodlePageState extends State<DoodlePage> {
  final GlobalKey _canvasKey = GlobalKey();
  bool _isLoading = false;
  ui.Image? _loadedImage;
  bool _hasDrawn = false;
  double _sliderValue = 0.0;
  String prompt = '';
  int? credits;
  bool _isLoggedIn = false;
  late ui.PictureRecorder _recorder;
  late Canvas _canvas;
  ui.Picture? _picture;

  @override
  void initState() {
    super.initState();

      _checkLoginStatus();
     SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  }
 
@override
void dispose() {
 if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  } // Clear Material Banners
  // Reset to allow all orientations when leaving the page
  SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  
  super.dispose();
}
@override
void didChangeDependencies() {
  super.didChangeDependencies();

  // Initialize the canvas with the correct screen size
  _initializeCanvas();
}
void _initializeCanvas() {
  
  // Get screen size using MediaQuery
  const Size canvasSize = Size(1024, 1024); // Fixed canvas size

  _recorder = ui.PictureRecorder();
  _canvas = Canvas(
    _recorder,
    Rect.fromPoints(
      Offset.zero,
      Offset(canvasSize.width, canvasSize.height) // Use screen dimensions
    ),
  );

  // Set the background to white
  _canvas.drawColor(Colors.white, BlendMode.src);

  _picture = null;
  _hasDrawn = false;

                if (mounted) {

  setState(() {
    _loadedImage = null;
  });
                }
}

  Future<void> _downloadImage() async {
    if (_loadedImage == null) return;

    final status = await Permission.photos.request();
    if (status.isGranted) {
      try {
        final byteData =
            await _loadedImage!.toByteData(format: ui.ImageByteFormat.png);
        final Uint8List bytes = byteData!.buffer.asUint8List();

        final result = await ImageGallerySaver.saveImage(
          bytes,
          quality: 100,
          name: "doodle_image",
        );

        if (result['isSuccess']) {
                if (mounted) {

          _showMessage('Successfully saved to photos.');
                }
        } else {
                if (mounted) {

          _showMessage('Failed to save.');
                }
        }
      } catch (e) {
                if (mounted) {

        _showMessage('Failed to save.');
                }
      }
    } else {
                if (mounted) {

      _showMessage('Enable photo library permissions for this app in settings to download!');
                }
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  void _updateCanvas(Offset position) {
    _canvas.drawCircle(
      position,
      6.0,
      Paint()..color = Colors.black,
    );
                if (mounted) {

    setState(() {
      _picture = _recorder.endRecording();
      _recorder = ui.PictureRecorder();
      _canvas = Canvas(
        _recorder,
        Rect.fromPoints(Offset.zero, const Offset(1024, 1024)),
      );
      _canvas.drawPicture(_picture!);
    });
                }
  }
Future<void> _checkLoginStatus() async {
    if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
     if (mounted) {
    setState(() {
      _isLoggedIn = token != null;
      if (token != null){
        credits = null;
      }
    });
     }
  }
  Future<void> _generateImage() async {
    if (!mounted) return;
      if (!_isLoggedIn) {
     _showLoginDialog(context);
    return;
  }
    if (!_hasDrawn) {
                if (mounted) {

      _showMessage('Please draw something on the canvas to generate!');
      }
      return;
    }
                if (mounted) {

    setState(() {
      _isLoading = true;
    });
                }
  final token = await _getToken();
      if (token == null) {
       
        return;
      }
    try {
    

      final image = await _captureCanvas();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List imageBytes = byteData!.buffer.asUint8List();
      final String base64Image = base64Encode(imageBytes);
      if (prompt == ''){
                if (mounted) {

        setState(() {
        prompt = 'sunset';

        _showMessage('No prompt set! Default: "sunset".');
            });
                }
      }
      final response = await http.post(
        Uri.parse('https://www.aimaker.world/generate/'),
        headers: {'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'image': base64Image,
          'prompt': prompt,
          'similarity': _sliderValue,
          'task_type': 'doodle',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String newImageBase64 = data['image'];
        final Uint8List receivedImageBytes = base64Decode(newImageBase64);
        final loadedImage = await _loadImage(receivedImageBytes);
                if (mounted) {

clearCanvas;
        setState(() {
          _loadedImage = loadedImage;
        });
                }
      } else {
                if (mounted) {
final data = jsonDecode(response.body);
    final String errorMessage = data['error'] ?? 'Unknown error';
    _showDisputeSnackBar2(context, token, errorMessage);   }
      }
    } catch (e) {


                if (mounted) {
  
        _showDisputeSnackBar(context, token);  }
       }finally {
                if (mounted) {

      setState(() {
        _isLoading = false;
      });
        }
    }
  }
  void clearCanvas() {
  if (_recorder.isRecording) {
    _recorder.endRecording(); // End any current recording to reset the canvas
  }
  _recorder = ui.PictureRecorder();
  _canvas = Canvas(
    _recorder,
    Rect.fromPoints(Offset.zero, const Offset(1024, 1024)), // Define canvas size
  );
  _canvas.drawColor(Colors.white, BlendMode.src); // Set background color to white

  setState(() {
    _picture = null;
    _hasDrawn = false;
  });
}

   void _showDisputeSnackBar2(BuildContext context, String token, String error) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content:  Text("Something went wrong. $error."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
   }
void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
                if (mounted) {

              Navigator.pushNamed(context, '/login'); // Navigate to login
                }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}

void _showDisputeSnackBar(BuildContext context, String token) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
    Future.delayed(const Duration(milliseconds: 20), () {if (!mounted) return;
    final banner = MaterialBanner(
      content: const Text("Experiencing issues? Check common problems."),
      actions: [
        TextButton(
          onPressed: () {
              if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
            _showCommonProblemsDialog(context);
          },
          child: const Text("Common Problems"),
        ),
      ],
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.all(8),
    );
                if (mounted) {
scaffoldMessengerKey.currentState?.showMaterialBanner(banner);
   
                }
    // Set timer to auto-dismiss the banner after 5 seconds
    Timer(const Duration(seconds: 11), () {
        if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
    });
  });
}

void _showCommonProblemsDialog(BuildContext context) {
  if (!mounted) return; // FIRST LINE inside _showCommonProblemsDialog

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Common Problems"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("1. Image Size: Ensure your image is below 5MB."),
            SizedBox(height: 8),
            Text("2. Format: Most heavily supported formats are PNG and JPG."),
            SizedBox(height: 8),
            Text("3. Network: Check your internet connection."),
          
            Text("Not working? Try different inputs."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

  Future<ui.Image> _captureCanvas() async {
    _finishDrawing();
    return _picture!.toImage(1024, 1024);
  }

  void _finishDrawing() {
    if (_recorder.isRecording) {
      _picture = _recorder.endRecording();
    }
  }

  Future<ui.Image> _loadImage(Uint8List imageBytes) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  void _showMessage(String message) {
                if (mounted) {

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        
        title: const Center(
    child:  Text('Doodle'),
  ),
        actions: [
          if (_loadedImage != null || _hasDrawn)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _initializeCanvas,
            ),
          if (_loadedImage != null)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _downloadImage,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: RepaintBoundary(
                key: _canvasKey,
                child: GestureDetector(
                  onPanStart: (details) {
                if (mounted) {

                    setState(() {
                      _hasDrawn = true;
                    });

                }
                  },
                  onPanUpdate: (details) {
                    _updateCanvas(details.localPosition);
                  },
                  child: CustomPaint(
                    size: const Size(double.infinity, double.infinity),
                    painter: _loadedImage == null
                        ? CanvasPainter(_picture)
                        : ImagePainter(_loadedImage!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              
              onChanged: (value) => setState(() => prompt = value),
              decoration: InputDecoration(
                labelText: 'Enter prompt',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),

            const SizedBox(height: 8),
               const Text("Adjust similarity:"),
            Slider(
              value: _sliderValue,
              min: 0,
              max: 1.0,
              divisions: 10,
              label: _sliderValue.toStringAsFixed(1),
              onChanged: (value) {
                if (mounted) {

                setState(() {
                  _sliderValue = value;
                });
                }
              },
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _generateImage,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Generate'),
            ),
          ],
        ),
      ),
    );
  }
}

class CanvasPainter extends CustomPainter with RouteAware {
  final ui.Picture? picture;

  CanvasPainter(this.picture);

  @override
  void paint(Canvas canvas, Size size) {
    if (picture != null) {
      canvas.drawPicture(picture!);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class ImagePainter extends CustomPainter {
  final ui.Image image;

  ImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final fittedSize = applyBoxFit(
      BoxFit.cover,  
      Size(image.width.toDouble(), image.height.toDouble()),
      size,
    ).destination;
  final offset = Offset(
  (size.width - fittedSize.width) / 16,
  (size.height - fittedSize.height) / 16,
);


    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(offset.dx, offset.dy, fittedSize.width, fittedSize.height),
      Paint(),
    );
  }

 @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
class Txt2ImgPage extends StatefulWidget {
  const Txt2ImgPage({super.key}); // Super parameter syntax

  @override
  Txt2ImgPageState createState() => Txt2ImgPageState();
}

class Txt2ImgPageState extends State<Txt2ImgPage> with RouteAware {

  bool _isInformationVisible = false;
  bool _isLoading = false;
  Uint8List? _imageBytes;
  bool _isLoggedIn = false;
  int? credits;
  int width = 1024;
  int height = 1024;

  int? steps = 50;
  double guidanceScale = 7.5;
  double _sliderValue = 1.0;
  String _selectedModel = 'real';
  Timer? _pollingTimer;
  bool _isAdvancedVisible = false;
  String prompt = '';
  String negativeprompt = '';
  bool _isLastInputInvalid = false; //
 
  final ApiService apiService = ApiService(); // Create instance

  @override
  void initState() {
    super.initState();

      _initializeInAppPurchaseListener();
    _checkLoginStatus();
   _fetchAndSetCredits(); // Fetch credits on initialization
  }
    
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  
    @override
  void dispose() {
  if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  } // Clear Material Banners
   
    _pollingTimer?.cancel(); // Stop polling when leaving the page
    _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
                if (mounted) {
    
    setState(() {
        _isLoggedIn = token != null;
      if (token != null){
        credits = null;
      }
    });
                }
  }

void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
                if (mounted) {

              Navigator.pushNamed(context, '/login'); // Navigate to login
                }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}

Future<void> _generateTxt2ImgImage() async {
  if (!mounted) return;
  if (256> width || width > 2048 || 256> height || height > 2048){
                if (mounted) {

     _showMessage('Image too big or too small, Max: 2048x2048px, Min: 256x256px.');
                }
     return;
  }
  if (!_isLoggedIn) {
                if (mounted) {

     _showLoginDialog(context);
                }
    return;
  }
                if (mounted) {

  setState(() => _isLoading = true); // Set loading to true
                }
  final token = await getToken();
    if (token == null) return;
  try {
  

    final response = await http.post(
      Uri.parse('https://www.aimaker.world/generate/'),
      headers: {'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'scale': _sliderValue,
        'width': width,
        'height': height,
        
        'task_type': 'txt2img',
        'model': _getModelValue(),
        'steps': steps,
        'prompt': prompt,
        'negativeprompt': negativeprompt,
        'guidance_scale': guidanceScale,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final taskId = data['task_id'];
      if (taskId != 'error') {
        await _pollTaskResult(taskId, token);
      } else {
                if (mounted) {
  _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
  
        setState(() => _isLoading = false); // Stop loading if task fails
                }
      }
    } else {
                if (mounted) {
  _fetchAndSetCredits();
       final data = jsonDecode(response.body);
    final String errorMessage = data['error'] ?? 'Unknown error';
    _showDisputeSnackBar2(context, token, errorMessage);
  
      setState(() => _isLoading = false); // Stop loading on failure
                }
    }
  } catch (e) {
                if (mounted) {
  _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
  
    setState(() => _isLoading = false); // Stop loading on exception
                }
  }
}
   void _showDisputeSnackBar2(BuildContext context, String token, String error) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content:  Text("Something went wrong. $error."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
   }
void _showDisputeSnackBar(BuildContext context, String token) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
    Future.delayed(const Duration(milliseconds: 20), () {if (!mounted) return;
    final banner = MaterialBanner(
      content: const Text("Experiencing issues? Check common problems."),
      actions: [
        TextButton(
          onPressed: () {
              if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
            _showCommonProblemsDialog(context);
          },
          child: const Text("Common Problems"),
        ),
      ],
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.all(8),
    );
                if (mounted) {
scaffoldMessengerKey.currentState?.showMaterialBanner(banner);
   
                }
    // Set timer to auto-dismiss the banner after 5 seconds
    Timer(const Duration(seconds: 11), () {
        if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
    });
  });
}

void _showCommonProblemsDialog(BuildContext context) {
  if (!mounted) return; // FIRST LINE inside _showCommonProblemsDialog

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Common Problems"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("1. Image Size: Ensure your image is below 5MB."),
            SizedBox(height: 8),
            Text("2. Format: Most heavily supported formats are PNG and JPG."),
            SizedBox(height: 8),
            Text("3. Network: Check your internet connection."),

            Text("Not working? Try different inputs."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

Future<void> _pollTaskResult(String taskId, String token) async {
  if (!mounted) return;
  _pollingTimer?.cancel(); // Cancel any existing timer

  _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
    if (!mounted) {
      timer.cancel(); // Stop polling if widget is unmounted
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://www.aimaker.world/task_result/'),
        headers: {'Authorization': 'Bearer $token'},
        body: jsonEncode({'task_id': taskId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
  

        if (data['status'] == 'completed') {
          if (data['image_base64'] is List && data['image_base64'].isNotEmpty) {
            String base64String = data['image_base64'][0]; // Get the first item
            Uint8List imageBytes = base64Decode(base64String);
                if (mounted) {

            setState(() {
              _imageBytes = imageBytes;
              _isLoading = false; // Stop loading on success
            });
                }
            timer.cancel(); // Stop polling on success
            _fetchAndSetCredits();
      
          } else {
                if (mounted) {
             _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
  
            setState(() => _isLoading = false); // Stop loading on error
                }
            timer.cancel();
          }
        } else if (data['status'] != 'processing') {
                if (mounted) {
          _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
  
          setState(() => _isLoading = false); // Stop loading on failure
                }
          timer.cancel(); // Stop polling if not processing

        }
      } else {
                if (mounted) {
         _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
  
        setState(() => _isLoading = false); // Stop loading on error
                }
        timer.cancel(); // Stop polling on error response
      }
    } catch (e) {
                if (mounted) {
  _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
  
      setState(() => _isLoading = false); // Stop loading on exception
                }
      timer.cancel(); // Stop polling on exception
    }
  });
}

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  

  void _showMessage(String message) {
                if (mounted) {

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
                }
  }
 


Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
    

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
}Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
        if (mounted) {
      Navigator.pushNamed(context, route);
        }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
              fontWeight: FontWeight.bold,
              fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}

  void _navigateToHomePage(BuildContext context) {
                if (context.mounted) {
               

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
                }
  }

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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

void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
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
  
StreamSubscription<List<PurchaseDetails>>? _subscription;

void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // Show a loading or pending message to the user
        _showSnackBar(context, 'Purchase is pending. Please wait...');
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
        if (mounted) {
          _showSnackBar(context, 'Purchase was canceled.');
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}



void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {

    return false;
  }
}

  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }

  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
}
    Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
        _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
            _buildServiceTile('Remove Background',"assets/images/bgremoval.png", context, '/background-removal'),
  _buildServiceTile('Replace Background',"assets/images/bgreplace.png", context, '/background-replace'),
_buildServiceTile('Face Swap',"assets/images/mergefaces.png", context, '/merge-faces'),
 _buildServiceTile('Restore Face',"assets/images/resface.png", context, '/restore-face'),
  _buildServiceTile('Remove Watermark',"assets/images/wmremoval.png", context, '/watermark-removal'),
_buildServiceTile('Remove Text',"assets/images/txtremoval.png", context, '/text-removal'),


_buildServiceTile('Image-> Image',"assets/images/img2img.png", context, '/img2img'),

_buildServiceTile('Text-> Video',"assets/images/txt2vid.png", context, '/txt2vid'),

_buildServiceTile('Image-> Video',"assets/images/img2vid.png", context, '/img2vid'),


_buildServiceTile('Size/Convert',"assets/images/convert.png", context, '/convert'),
        ],
      ),
    );
  }
Future<void> _downloadImage() async {
  if (_imageBytes == null) return;

  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
    try {
      // Save the image to the photo gallery.
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(_imageBytes!),
        quality: 100,
        name: "txt2img_image",
      );

      if (result['isSuccess']) {
         if (mounted) {
        _showMessage('Successfully saved to photos.');
         }
      } else {
         if (mounted) {
        _showMessage('Failed to save.');
         }
      }
    } catch (e) {
       if (mounted) {
      _showMessage('Failed to save.');
       }
    }
  } else {
     if (mounted) {
     _showMessage('Enable photo library permissions for this app in settings to download!');
     }
  }
}
  
  
Widget buildSlider() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Adjust Size:',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Slider(
        value: _sliderValue,
        min: 1.0,
        max: 4.0,
        divisions: 30, // Increments of 0.1
        label: _sliderValue.toStringAsFixed(1),
        onChanged: (value) {
           if (mounted) {
          setState(() {
            _sliderValue = value;
          });
           }
        },
      ),
    ],
  );
}Widget buildDropdown() {
  return Center(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Center-align content within the column
      children: [
        const Center(
          child: Text(
            'Model:',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center, // Center-align the label text
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.deepPurple, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: Container(),
            value: _selectedModel,
            items: const [
              DropdownMenuItem(value: 'real', child: Center(child: Text('Realistic'))),
              DropdownMenuItem(value: 'cartoon', child: Center(child: Text('CartoonV1'))),
              DropdownMenuItem(value: 'cartoon2', child: Center(child: Text('CartoonV2'))),
              DropdownMenuItem(value: 'anime', child: Center(child: Text('AnimeV1'))),
              DropdownMenuItem(value: 'anime2', child: Center(child: Text('AnimeV2'))),
              DropdownMenuItem(value: 'dark', child: Center(child: Text('Dark'))),
            ],
            onChanged: (value) {
               if (mounted) {
              setState(() {
                _selectedModel = value!;
              });
               }
            },
           icon: const SizedBox.shrink(),
          ),
        ),
      ],
    ),
  );
}

  
  String _getModelValue() {
    switch (_selectedModel) {
      case 'cartoon':
        return '3';
      case 'cartoon2':
        return '16';
      case 'real':
        return '2';
      case 'dark':
        return '6';
        case 'anime':
        return '1';
        case 'anime2':
        return '5';
      default:
        return '3';
    }
  }
 Widget buildAdvancedOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

            const SizedBox(height: 8),
        buildTextField('Negative Prompt:', 'What should not appear?', (value) {
          setState(() => negativeprompt = value);
        }),
      buildNumberInput('Width:', width, 'Max: 2048 / Min: 256', (value) {
  int? val = int.tryParse(value);
  if (val != null && val >= 256 && val <= 2048) {
    setState(() => width = val);
  }
}),
buildNumberInput('Height:', height, 'Max: 2048 / Min: 256', (value) {
  int? val = int.tryParse(value);
  if (val != null && val >= 256 && val <= 2048) {
    setState(() => height = val);
  }
}),

        buildSliderInput('Steps:', steps?.toDouble() ?? 50.0, 1, 100, (value) {
  setState(() => steps = value.toInt());
}),

        buildSliderInput('Guidance Scale:', guidanceScale, 1.0, 30.0, (value) {
          setState(() => guidanceScale = value);
        }),
        buildDropdown(),
      ],
    );
  }
       Widget _buildInformationSection() {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 16), // Adjust top and left padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Input:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
       const  SizedBox(height: 4),
        const Text('Enter a prompt for the desired image.'),
        const SizedBox(height: 12),
        const Text(
          'Result:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
       const SizedBox(height: 4),
        const Text('Image made from text.'),
        const SizedBox(height: 12),
              Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/pricing');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Pricing'),
          ),
        ),
        const SizedBox(height: 8),
        Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('More info'),
          ),
        ),
      ],
    ),
  );
}



  @override
Widget build(BuildContext context,{bool isHomePage = false}) {
  return Scaffold(
    appBar: AppBar(
       automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF5F5F5),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          
         GestureDetector(
          onTap: () {
            if (!isHomePage) {
               if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
               }
            }
          },
          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
        IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
           if (mounted) {
          Navigator.pushNamed(context, '/settings');
           }
        },
      ),const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
          _buildLogoutButton(context),
        ],
      ),
    ),
     backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
   
        padding: const  EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        
          _buildHorizontalList(context),
          const SizedBox(height: 24),
            const Text(
              'Text -> Image',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize:25,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),

          // Improved Image Container
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(2, 4), // Shadow position
                ),
              ],
            ),
            child: ClipRRect(
  borderRadius: BorderRadius.circular(12),
  child: _isLoading
      ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
          ),
        )
      : _imageBytes != null
          ? Image.memory(
              _imageBytes!,
              fit: BoxFit.cover,
            )
          : const Center(
              child: Text(
                'Generate an image from text',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
),
          ),

          const SizedBox(height: 16),
    buildTextField('Prompt', 'Enter prompt', (value) {
        if (mounted) {
              setState(() => prompt = value);
        }
            }),
             const SizedBox(height: 16),
               
          // Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
           
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || prompt == "" 
                      ? null
                      : _generateTxt2ImgImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Generate',
                    style: TextStyle(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _imageBytes == null
                      ? null
                      : _downloadImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Download',
                    style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
 ElevatedButton(
              onPressed: () {
                 if (mounted) {
                setState(() {
                  _isAdvancedVisible = !_isAdvancedVisible;
                });
                 }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Advanced Options'),
            ),
            if (_isAdvancedVisible) buildAdvancedOptions(),
          
          const SizedBox(height: 16),
         
          // Cost Display
             ElevatedButton(
              onPressed: () {
                 if (mounted) {
                setState(() {
                  _isInformationVisible = !_isInformationVisible;
                });
                 } 
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Information'),
            ),
            if (_isInformationVisible) _buildInformationSection(),
        ],
      ),
    ),
  );
}
 Widget buildTextField(String label, String hint, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
Widget buildNumberInput(String label, int? value, String hint, Function(String) onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border:  const OutlineInputBorder(),
      ),
      onChanged: (input) {
        // Check if input is empty or a number
        if (input.isEmpty || int.tryParse(input) != null) {
          _isLastInputInvalid = false; // Reset the invalid flag
          onChanged(input); // Trigger callback for number or empty input
        } else if (!_isLastInputInvalid) {
          if (mounted) {
          _showMessage('Please enter a number.');
          }
          _isLastInputInvalid = true; // Mark as invalid to prevent further spam
        }
      },
    ),
  );
}


Widget buildSliderInput(String label, double currentValue, double min, double max, Function(double) onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center, // Center-align content within the column
    children: [
      Center( // Center-align the label text
        child: Text(
          label,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
      Slider(
        value: currentValue,
        min: min,
        max: max,
        divisions: max.toInt(),
        label: currentValue.toStringAsFixed(1),
        onChanged: onChanged,
      ),
    ],
  );
}



}
class Img2ImgPage extends StatefulWidget {
  const Img2ImgPage({super.key}); // Super parameter syntax

  @override
  Img2ImgPageState createState() => Img2ImgPageState();
}

class Img2ImgPageState extends State<Img2ImgPage> with RouteAware {
 bool _isGenerateEnabled = false; // Manage generate button state
 File? _imageFile;

  bool _isInformationVisible = false;
 bool _isLastInputInvalid = false; //
  bool _isLoading = false;
  Uint8List? _imageBytes;
  bool _isLoggedIn = false;
  int? credits;
  int width = 1024;
  int height = 1024;

  int? steps = 50;
  double guidanceScale = 7.5;
  String? _base64Image;
  double _sliderValue = 1.0;
  String _selectedModel = 'real';
  Timer? _pollingTimer;
  bool _isAdvancedVisible = false;
  String prompt = '';
  String negativeprompt = '';

 
  final ApiService apiService = ApiService(); // Create instance

  @override
  void initState() {
    super.initState();

      _initializeInAppPurchaseListener();
    _checkLoginStatus();
   _fetchAndSetCredits(); // Fetch credits on initialization
  }
    
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  
    @override
  void dispose() {
 if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  } // Clear Material Banners
   
    _pollingTimer?.cancel(); // Stop polling when leaving the page
    _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
    if (mounted) {
    setState(() {
        _isLoggedIn = token != null;
      if (token != null){
        credits = null;
      }
    });
    }
  }
void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
              if (mounted) {
              Navigator.pushNamed(context, '/login'); // Navigate to login
              }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}

Future<void> _generateImg2ImgImage() async {
  if (!mounted) return;
  if (256> width || width > 2048 || 256> height || height > 2048){
    if (mounted) {
     _showMessage('Image too big or too small, Max: 2048x2048px, Min: 256x256px.');
    }
     return;
  }
  if (prompt == ''){
if (mounted) {
     _showMessage('Please enter a prompt.');
}
    return;
  }
  if (!_isLoggedIn) {if (mounted) {
    _showLoginDialog(context);
  }
    return;
  }
if (mounted) {
  setState(() => _isLoading = true);
}
   final token = await getToken();
    if (token == null) return;
  try {
  

    final response = await http.post(
      Uri.parse('https://www.aimaker.world/generate/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
     

      body: jsonEncode({
        'scale': _sliderValue,
        'width': width,
        'height': height,
     
        'task_type': 'img2img',
        'model': _getModelValue(),
        'steps': steps,
        'prompt': prompt,
        'negativeprompt': negativeprompt,
        'guidance_scale': guidanceScale,
        'image': _base64Image,  // Send the image as base64 string
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _pollTaskResult(data['task_id'], token);
    } else {
    if (mounted) {
        final data = jsonDecode(response.body);
    final String errorMessage = data['error'] ?? 'Unknown error';
    _showDisputeSnackBar2(context, token, errorMessage);
    _fetchAndSetCredits();
      setState(() => _isLoading = false);
    }
    }
  } catch (e) {
  if (mounted) {
        _showDisputeSnackBar(context, token);
    _fetchAndSetCredits();
    setState(() => _isLoading = false);
  }
  }
}
   void _showDisputeSnackBar2(BuildContext context, String token, String error) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content:  Text("Something went wrong. $error."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
   }
void _showDisputeSnackBar(BuildContext context, String token) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
    Future.delayed(const Duration(milliseconds: 20), () {if (!mounted) return;
    final banner = MaterialBanner(
      content: const Text("Experiencing issues? Check common problems."),
      actions: [
        TextButton(
          onPressed: () {
              if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
            _showCommonProblemsDialog(context);
          },
          child: const Text("Common Problems"),
        ),
      ],
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.all(8),
    );
if (mounted) {
   scaffoldMessengerKey.currentState?.showMaterialBanner(banner);
   
}
    // Set timer to auto-dismiss the banner after 5 seconds
    Timer(const Duration(seconds: 11), () {
        if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
    });
  });
}

void _showCommonProblemsDialog(BuildContext context) {
  if (!mounted) return; // FIRST LINE inside _showCommonProblemsDialog

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Common Problems"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("1. Image Size: Ensure your image is below 5MB."),
            SizedBox(height: 8),
            Text("2. Format: Most heavily supported formats are PNG and JPG."),
            SizedBox(height: 8),
            Text("3. Network: Check your internet connection."),

            Text("Not working? Try different inputs."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

Future<void> _pollTaskResult(String taskId, String token) async {
  if (!mounted) return;
  _pollingTimer?.cancel(); // Cancel any existing timer

  _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
    if (!mounted) {
      timer.cancel(); // Stop polling if widget is unmounted
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://www.aimaker.world/task_result/'),
        headers: {'Authorization': 'Bearer $token'},
        body: jsonEncode({'task_id': taskId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
     
        if (data['status'] == 'completed') {
          if (data['image_base64'] is List && data['image_base64'].isNotEmpty) {
            String base64String = data['image_base64'][0]; // Get the first item
            Uint8List imageBytes = base64Decode(base64String);
if (mounted) {
            setState(() {
              _imageBytes = imageBytes;
              _isLoading = false;
              _imageFile = null; 
              _base64Image = null; 
              _isGenerateEnabled = false;
            });
            _fetchAndSetCredits();
}
            timer.cancel(); // Stop polling on success
  
          } else {
     if (mounted) {
        _showDisputeSnackBar(context, token);
  _fetchAndSetCredits();
     }
            _stopPolling(timer); // Ensure polling stops on error
          }
        } else if (data['status'] != 'processing') {
     if (mounted) {
        _showDisputeSnackBar(context, token);
        _fetchAndSetCredits();
     }
          _stopPolling(timer); // Stop polling on failure
        }
      } else {
      if (mounted) {
        _showDisputeSnackBar(context, token);
        _fetchAndSetCredits();
      }
        _stopPolling(timer); // Stop polling on non-200 response
      }
    } catch (e) {
       if (mounted) {
 _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
     
       }
       _stopPolling(timer); // Stop polling on exception
    }
  });
}
void _stopPolling(Timer timer) {
     if (mounted) {
  setState(() => _isLoading = false);
     }
  timer.cancel();
}
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  

  void _showMessage(String message) {
       if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
       }
  }
 


Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
    

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
}Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
      if (mounted) {
      Navigator.pushNamed(context, route);
      }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
              fontWeight: FontWeight.bold,
              fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}

  void _navigateToHomePage(BuildContext context) {
    if (context.mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
    }
  }

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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
void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
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
  
StreamSubscription<List<PurchaseDetails>>? _subscription;

void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // Show a loading or pending message to the user
        _showSnackBar(context, 'Purchase is pending. Please wait...');
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
        if (mounted) {
          _showSnackBar(context, 'Purchase was canceled.');
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}



void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {

    return false;
  }
}

  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }

  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
}
    Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
        _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
            _buildServiceTile('Remove Background',"assets/images/bgremoval.png", context, '/background-removal'),
  _buildServiceTile('Replace Background',"assets/images/bgreplace.png", context, '/background-replace'),
 _buildServiceTile('Face Swap',"assets/images/mergefaces.png", context, '/merge-faces'),
 _buildServiceTile('Restore Face',"assets/images/resface.png", context, '/restore-face'),
  _buildServiceTile('Remove Watermark',"assets/images/wmremoval.png", context, '/watermark-removal'),
_buildServiceTile('Remove Text',"assets/images/txtremoval.png", context, '/text-removal'),


_buildServiceTile('Text-> Image',"assets/images/txt2img.png", context, '/txt2img'),

_buildServiceTile('Text-> Video',"assets/images/txt2vid.png", context, '/txt2vid'),

_buildServiceTile('Image-> Video',"assets/images/img2vid.png", context, '/img2vid'),


_buildServiceTile('Size/Convert',"assets/images/convert.png", context, '/convert'),
        ],
      ),
    );
  }
Future<void> _downloadImage() async {
  if (_imageBytes == null) return;

  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
    try {
      // Save the image to the photo gallery.
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(_imageBytes!),
        quality: 100,
        name: "img2img_image",
      );

      if (result['isSuccess']) {
        if (mounted) {
        _showMessage('Successfully saved to photos.');
        }
      } else {
        if (mounted) {
        _showMessage('Failed to save.');
        }
      }
    } catch (e) {
      if (mounted) {
      _showMessage('Failed to save.');
      }
    }
  } else {
    if (mounted) {
     _showMessage('Enable photo library permissions for this app in settings to download!');
    }
  }
}
  

  
Widget buildSlider() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Adjust Size:',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Slider(
        value: _sliderValue,
        min: 1.0,
        max: 4.0,
        divisions: 30, // Increments of 0.1
        label: _sliderValue.toStringAsFixed(1),
        onChanged: (value) {
          if (mounted) {
          setState(() {
            _sliderValue = value;
          });
          }
        },
      ),
    ],
  );
}Widget buildDropdown() {
  return Center(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Center-align content within the column
      children: [
        const Center(
          child: Text(
            'Model:',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center, // Center-align the label text
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.deepPurple, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: Container(),
            value: _selectedModel,
            items: const [
              DropdownMenuItem(value: 'real', child: Center(child: Text('Realistic'))),
              DropdownMenuItem(value: 'cartoon', child: Center(child: Text('CartoonV1'))),
              DropdownMenuItem(value: 'cartoon2', child: Center(child: Text('CartoonV2'))),
              DropdownMenuItem(value: 'anime', child: Center(child: Text('AnimeV1'))),
              DropdownMenuItem(value: 'anime2', child: Center(child: Text('AnimeV2'))),
              DropdownMenuItem(value: 'dark', child: Center(child: Text('Dark'))),
            ],
            onChanged: (value) {
              if (mounted) {
              setState(() {
                _selectedModel = value!;
              });
              }
            },
           icon: const SizedBox.shrink(),
          ),
        ),
      ],
    ),
  );

}
  
  String _getModelValue() {
    switch (_selectedModel) {
      case 'cartoon':
        return '3';
      case 'cartoon2':
        return '16';
      case 'real':
        return '2';
      case 'dark':
        return '6';
        case 'anime':
        return '1';
        case 'anime2':
        return '5';
      default:
        return '3';
    }
  }
 Widget buildAdvancedOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      
            const SizedBox(height: 8),
     buildNumberInput('Width:', width, 'Max: 2048 / Min: 256', (value) {
  int? val = int.tryParse(value);
  if (val != null && val >= 256 && val <= 2048) {
    setState(() => width = val);
  }
}),
buildNumberInput('Height:', height, 'Max: 2048 / Min: 256', (value) {
  int? val = int.tryParse(value);
  if (val != null && val >= 256 && val <= 2048) {
    setState(() => height = val);
  }
}),

        buildSliderInput('Steps:', steps?.toDouble() ?? 50.0, 1, 100, (value) {
  setState(() => steps = value.toInt());
}),

       
        buildDropdown(),
      ],
    );
  }
     Widget _buildInformationSection() {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 16), // Adjust top and left padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:  [
        const Text(
          'Input:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
       const SizedBox(height: 4),
        const Text('Select an image. Enter a prompt for the new image.'),
        const SizedBox(height: 12),
       const Text(
          'Result:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Another version of the image.'),
    const SizedBox(height: 12),
              Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/pricing');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Pricing'),
          ),
        ),
        const SizedBox(height: 8),
        Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('More info'),
          ),
        ),
        
      ],
    ),
  );
}



  @override
Widget build(BuildContext context,{bool isHomePage = false}) {
  return Scaffold(
    appBar: AppBar(
       automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF5F5F5),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
      
         GestureDetector(
          onTap: () {
            if (!isHomePage) {
              if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
              }
            }
          },
          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
        IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          if (mounted) {
          Navigator.pushNamed(context, '/settings');
          }
        },
      ),const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
          _buildLogoutButton(context),
        ],
      ),
    ),
     backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
      
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
       
          _buildHorizontalList(context),
          const SizedBox(height: 24),
            const Text(
              'Image -> Image',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize:25,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),

          // Improved Image Container
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(2, 4), // Shadow position
                ),
              ],
            ),
             child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
          )
        : _imageBytes != null
            ? Image.memory(
                _imageBytes!,
                fit: BoxFit.cover,
              )
            : _imageFile != null
                ? Image.file(
                    _imageFile!,
                    fit: BoxFit.cover,
                  )
                : const Center(
                    child: Text(
                      'Generate an image from an image',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
  ),
),
            const SizedBox(height: 16),
    buildTextField('Prompt', 'Enter prompt', (value) {
      if (mounted) {
              setState(() => prompt = value);
      }
            }),
          const SizedBox(height: 16),
      Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Upload',
                    style: TextStyle(color: Colors.black),),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  
                  onPressed: _isLoading || _imageFile == null || !_isGenerateEnabled
                      ? null
                      : _generateImg2ImgImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Generate',
                    style: TextStyle(color: Colors.black, fontSize: 13.55)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _imageBytes == null
                      ? null
                      : _downloadImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Download',
                    style: TextStyle(color: Colors.black, fontSize: 12.59)),
                ),
              ),
            ],
          ),
             const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                setState(() {
                  _isAdvancedVisible = !_isAdvancedVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Advanced Options'),
            ),
            if (_isAdvancedVisible) buildAdvancedOptions(),
              
          const SizedBox(height: 16),
          // Button Row
        

          // Cost Display
             ElevatedButton(
              onPressed: () {
                if (mounted) {
                setState(() {
                  _isInformationVisible = !_isInformationVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Information'),
            ),
            if (_isInformationVisible) _buildInformationSection(),
        ],
      ),
    ),
  );
}
 Widget buildTextField(String label, String hint, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
 Widget buildNumberInput(String label, int? value, String hint, Function(String) onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (input) {
        // Check if input is empty or a number
        if (input.isEmpty || int.tryParse(input) != null) {
          _isLastInputInvalid = false; // Reset the invalid flag
          onChanged(input); // Trigger callback for number or empty input
        } else if (!_isLastInputInvalid) {
          if (mounted) {
          _showMessage('Please enter a number.');
          }
          _isLastInputInvalid = true; // Mark as invalid to prevent further spam
        }
      },
    ),
  );
}


Future<void> _pickImage() async {
  if (!mounted) return;
   final status = await Permission.photos.request();
  if (status.isGranted) {
  
  try {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85, // Reduce size for compatibility
    );

    if (pickedFile != null) {
      final decodedImage = await decodeImageFromList(await pickedFile.readAsBytes());
      if (decodedImage.width < 128 || decodedImage.height < 128) {
        // Show a message if the image is too small
        if (mounted) {
         _showMessage('Image too small, Min: 128x128px');
        }
      } else {
        if (mounted) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _imageBytes = null;
        _base64Image = base64Encode(_imageFile!.readAsBytesSync());
        _isGenerateEnabled = true; // Enable the generate button
      });
        }
    }
    }
  } catch (e) {
    if (mounted) {
    _showMessage('Image too large, Max: 1024x1024px');
    }
  }
   } else {
    if (mounted) {
    _showMessage('Enable photo library permissions for this app in settings to upload!');
    }
  }
}




Widget buildSliderInput(String label, double currentValue, double min, double max, Function(double) onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center, // Center-align content within the column
    children: [
      Center( // Center-align the label text
        child: Text(
          label,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
      Slider(
        value: currentValue,
        min: min,
        max: max,
        divisions: max.toInt(),
        label: currentValue.toStringAsFixed(1),
        onChanged: onChanged,
      ),
    ],
  );
}



}

class Txt2VidPage extends StatefulWidget {
  const Txt2VidPage({super.key}); // Super parameter syntax

  @override
  Txt2VidPageState createState() => Txt2VidPageState();
}

class Txt2VidPageState extends State<Txt2VidPage> with RouteAware {

  bool _isLoading = false;
  bool _isLoggedIn = false;
  int? credits;

  bool _isInformationVisible = false;
  
  int width = 512;
  int height = 512;
  bool _isLastInputInvalid = false; //
  int? steps = 20;
  double guidanceScale = 7.5;
  double _sliderValue = 1.0;
  String _selectedModel = '1';
  Timer? _pollingTimer;
  bool _isAdvancedVisible = false;
  String prompt = '';
  String negativeprompt = '';

  Uint8List? _videoBytes;
  VideoPlayerController? _videoController;
 
  final ApiService apiService = ApiService(); // Create instance

  @override
  void initState() {
    super.initState();

      _initializeInAppPurchaseListener();
    _checkLoginStatus();
   _fetchAndSetCredits(); // Fetch credits on initialization
  }
    
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  
    @override
  void dispose() {
 if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  } // Clear Material Banners
  
    _pollingTimer?.cancel(); // Stop polling when leaving the page
    _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
    if (mounted) {
    setState(() {
        _isLoggedIn = token != null;
      if (token != null){
        credits = null;
      }
    });
    }
  }

void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
              if (mounted) {
              Navigator.pushNamed(context, '/login'); // Navigate to login
              }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}

Future<void> _generateTxt2VidImage() async {
  if (!mounted) return;
    if (256> width || width > 1024 || 256> height || height > 1024){
      if (mounted) {
     _showMessage('Please try again with a smaller height and width! Max: 1024x1024px, Min: 256x256px');
      }
    return;
  }
  if (!_isLoggedIn) {
    if (mounted) {
     _showLoginDialog(context);
    }
    return;
  }
if (mounted) {
  setState(() => _isLoading = true); // Set loading to true
}
  final token = await getToken();
    if (token == null) return;
  try {
   

    final response = await http.post(
      Uri.parse('https://www.aimaker.world/generate/'),
      headers: {'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'scale': guidanceScale,
        'width': width,
        'height': height,
       
        'task_type': 'txtgen_video',
        'model': _getModelValue(),
        'steps': steps,
        'prompt': prompt,
        'negativeprompt': negativeprompt,
        
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final taskId = data['task_id'];
      if (taskId != 'error') {
        await _pollTaskResult(taskId, token);
      } else {
       if (mounted) {
          _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
        setState(() => _isLoading = false); // Stop loading if task fails
       }
      }
    } else {
      if (mounted) {
          _fetchAndSetCredits();
       final data = jsonDecode(response.body);
    final String errorMessage = data['error'] ?? 'Unknown error';
    _showDisputeSnackBar2(context, token, errorMessage);
      setState(() => _isLoading = false); // Stop loading on failure
      }
    }
  } catch (e) {
     if (mounted) {
        _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
    setState(() => _isLoading = false); // Stop loading on exception
     }
  }
}
   void _showDisputeSnackBar2(BuildContext context, String token, String error) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content:  Text("Something went wrong. $error."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
   }
Future<void> _pollTaskResult(String taskId, String token) async {
  if (!mounted) return;
  _pollingTimer?.cancel(); // Cancel any existing timer

  _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (!mounted) {
      timer.cancel(); // Stop polling if widget is unmounted
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://www.aimaker.world/task_result/'),
        headers: {'Authorization': 'Bearer $token'},
        body: jsonEncode({'task_id': taskId}),
      );

      if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['status'] == 'completed') {
           if (data['video_base64'] != null && data['video_base64'] is String) {
           
  String base64String = data['video_base64'];
  Uint8List videoBytes = base64Decode(base64String);
  _setVideoBytes(videoBytes);
  timer.cancel();
  _fetchAndSetCredits();
} else {
 if (mounted) {
    _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
  setState(() => _isLoading = false);
 }
  timer.cancel();
}

          } else if (data['status'] != 'processing') {
            if (mounted) {
                _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
            setState(() => _isLoading = false);
            }
            timer.cancel();
          }
        } else {
        if (mounted) {
            _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
          setState(() => _isLoading = false);
        }
          timer.cancel();
        }
      } catch (e) {
       if (mounted) {
          _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
        setState(() => _isLoading = false);
       }
        timer.cancel();
      }
    });
  }
  void _showDisputeSnackBar(BuildContext context, String token) {
    if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
    Future.delayed(const Duration(milliseconds: 20), () {if (!mounted) return;
    final banner = MaterialBanner(
      content: const Text("Experiencing issues? Check common problems."),
      actions: [
        TextButton(
          onPressed: () {
              if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
            _showCommonProblemsDialog(context);
          },
          child: const Text("Common Problems"),
        ),
      ],
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.all(8),
    );
if (mounted) {
   scaffoldMessengerKey.currentState?.showMaterialBanner(banner);
   
}
    // Set timer to auto-dismiss the banner after 5 seconds
    Timer(const Duration(seconds: 11), () {
        if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
    });
  });
}

void _showCommonProblemsDialog(BuildContext context) {
  if (!mounted) return; // FIRST LINE inside _showCommonProblemsDialog

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Common Problems"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("1. Image Size: Ensure your image is below 5MB."),
            SizedBox(height: 8),
            Text("2. Format: Most heavily supported formats are PNG and JPG."),
            SizedBox(height: 8),
            Text("3. Network: Check your internet connection."),

            Text("Not working? Try different inputs."),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

void _setVideoBytes(Uint8List videoBytes) async {
  if (!mounted) return;
  if (mounted) {
  setState(() => _isLoading = false);
  }
  _videoBytes = videoBytes;
  
  final directory = await getTemporaryDirectory();
  final path = '${directory.path}/temp_video.mp4';
  final file = File(path);
  await file.writeAsBytes(videoBytes);

  _videoController?.dispose();
  _videoController = VideoPlayerController.file(file)
    ..initialize().then((_) {
   
     if (mounted) {
      setState(() {});
      _videoController?.play();
   }
    }
);
}




  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  

  void _showMessage(String message) {
    if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
 


Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
    

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
}Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
      if (mounted) {
      Navigator.pushNamed(context, route);
      }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
              fontWeight: FontWeight.bold,
              fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}

  void _navigateToHomePage(BuildContext context) {
    if (context.mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
    }
  }

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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

void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
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
  
StreamSubscription<List<PurchaseDetails>>? _subscription;

void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // Show a loading or pending message to the user
        _showSnackBar(context, 'Purchase is pending. Please wait...');
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
        if (mounted) {
          _showSnackBar(context, 'Purchase was canceled.');
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}



void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {

    return false;
  }
}

  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }

  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
}
    Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
        _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
            _buildServiceTile('Remove Background',"assets/images/bgremoval.png", context, '/background-removal'),
  _buildServiceTile('Replace Background',"assets/images/bgreplace.png", context, '/background-replace'),
 _buildServiceTile('Face Swap',"assets/images/mergefaces.png", context, '/merge-faces'),
 _buildServiceTile('Restore Face',"assets/images/resface.png", context, '/restore-face'),
  _buildServiceTile('Remove Watermark',"assets/images/wmremoval.png", context, '/watermark-removal'),
_buildServiceTile('Remove Text',"assets/images/txtremoval.png", context, '/text-removal'),


_buildServiceTile('Text-> Image',"assets/images/txt2img.png", context, '/txt2img'),
_buildServiceTile('Image-> Image',"assets/images/img2img.png", context, '/img2img'),

_buildServiceTile('Image-> Video',"assets/images/img2vid.png", context, '/img2vid'),


_buildServiceTile('Size/Convert', "assets/images/convert.png", context, '/convert'),
        ],
      ),
    );
  }
 Future<void> _downloadVideo() async {
  if (_videoBytes == null) return;

  final status = await Permission.photos.request();
  if (status.isGranted) {
    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/generated_video.mp4';
      final file = File(path);
      await file.writeAsBytes(_videoBytes!);

      final result = await ImageGallerySaver.saveFile(file.path, name: "generated_video");
      if (result['isSuccess']) {
       if (mounted) {
        _showMessage('Successfully saved to photos.');
       }
      } else {
        if (mounted) {
        _showMessage('Failed to save.');
        }
      }
    } catch (e) {
      if (mounted) {
       _showMessage('Failed to save.');
      }
    }
  } else {
    if (mounted) {
    _showMessage('Enable photo library permissions for this app in settings to download!');
    }
  }
}

 

  
Widget buildSlider() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Adjust Size:',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Slider(
        value: _sliderValue,
        min: 1.0,
        max: 4.0,
        divisions: 30, // Increments of 0.1
        label: _sliderValue.toStringAsFixed(1),
        onChanged: (value) {
          if (mounted) {
          setState(() {
            _sliderValue = value;
          });
          }
        },
      ),
    ],
  );
}Widget buildDropdown() {
  return Center(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Center-align content within the column
      children: [
        const Center(
          child: Text(
            'Model:',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center, // Center-align the label text
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.deepPurple, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: Container(),
            value: _selectedModel,
            items: const [
              DropdownMenuItem(value: '1', child: Center(child: Text('1'))),
              DropdownMenuItem(value: '2', child: Center(child: Text('2'))),
              DropdownMenuItem(value: '3', child: Center(child: Text('3'))),
              DropdownMenuItem(value: '4', child: Center(child: Text('4'))),
            ],
            onChanged: (value) {
              if (mounted) {
              setState(() {
                _selectedModel = value!;
              });
              }
            },
         icon: const SizedBox.shrink(),
          ),
        ),
      ],
    ),
  );

}
  String _getModelValue() {
    switch (_selectedModel) {
      case '1':
        return '9';
      case '2':
        return '7';
      case '3':
        return '8';
      case '4':
        return '10';
      
      default:
        return '9';
    }
  }
 Widget buildAdvancedOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

            const SizedBox(height: 8),
        buildTextField('Negative Prompt:', 'What should not appear?', (value) {
          setState(() => negativeprompt = value);
        }),
      buildNumberInput('Width:', width, 'Max: 1024 / Min: 256', (value) {
  int? val = int.tryParse(value);
  if (val != null && val >= 256 && val <= 1024) {
    setState(() => width = val);
  }
}),
buildNumberInput('Height:', height, 'Max: 1024 / Min: 256', (value) {
  int? val = int.tryParse(value);
  if (val != null && val >= 256 && val <= 1024) {
    setState(() => height = val);
  }
}),

        buildSliderInput('Steps:', steps?.toDouble() ?? 50.0, 1, 50, (value) {
  setState(() => steps = value.toInt());
}),

        buildSliderInput('Guidance Scale:', guidanceScale, 1.0, 30.0, (value) {
          setState(() => guidanceScale = value);
        }),
        buildDropdown(),
      ],
    );
  }  void _togglePlayPause() {
    if (mounted) {
    setState(() {
     
        _videoController!.play();
    });
    }
  }
Widget buildNumberInput(String label, int? value, String hint, Function(String) onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (input) {
        // Check if input is empty or a number
        if (input.isEmpty || int.tryParse(input) != null) {
          _isLastInputInvalid = false; // Reset the invalid flag
          onChanged(input); // Trigger callback for number or empty input
        } else if (!_isLastInputInvalid) {
          if (mounted) {
          _showMessage('Please enter a number.');
          }
          _isLastInputInvalid = true; // Mark as invalid to prevent further spam
        }
      },
    ),
  );
}
   Widget _buildInformationSection() {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 16), // Adjust top and left padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:  [
        const Text(
          'Input:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Enter a prompt for the desired video.'),
        const SizedBox(height: 12),
        const Text(
          'Result:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Video made from text.'),
       const SizedBox(height: 12),
              Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/pricing');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Pricing'),
          ),
        ),
        const SizedBox(height: 8),
        Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('More info'),
          ),
        ),
      
      ],
    ),
  );
}



  @override
Widget build(BuildContext context,{bool isHomePage = false}) {
  return Scaffold(
    appBar: AppBar(
       automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF5F5F5),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           
         GestureDetector(
          onTap: () {
            if (!isHomePage) {
              if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
              }
            }
          },
          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
        IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {if (mounted) {
          Navigator.pushNamed(context, '/settings');
        }
        },
      ),const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
          _buildLogoutButton(context),
        ],
      ),
    ),
     backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
     
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
    
          _buildHorizontalList(context),
          const SizedBox(height: 24),
            const Text(
              'Text -> Video',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize:25,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),
          // Improved Image Container
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(2, 4), // Shadow position
                ),
              ],
            ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                        ),
                      )
                    : _videoController != null && _videoController!.value.isInitialized
                     ? GestureDetector(
                      onTap: _togglePlayPause, // Toggle play/pause on tap
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  
                        : const Center(
                            child: Text(
                              'Generate a video from text',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
              ),
            ),
            
          const SizedBox(height: 16),
    buildTextField('Prompt', 'Enter prompt', (value) {
      if (mounted) {
              setState(() => prompt = value);
      }
            }),
        
              
          const SizedBox(height: 16),
          // Button Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
           
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || prompt == "" 
                      ? null
                      : _generateTxt2VidImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Generate',
                    style: TextStyle(color: Colors.black)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _videoBytes == null
                      ? null
                      : _downloadVideo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Download',
                    style: TextStyle(color: Colors.black)),
                ),
              ),
            ],
          ),
     const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                setState(() {
                  _isAdvancedVisible = !_isAdvancedVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Advanced Options'),
            ),
            if (_isAdvancedVisible) buildAdvancedOptions(),
          const SizedBox(height: 16),
          // Cost Display
             ElevatedButton(
              onPressed: () {
                if (mounted) {
                setState(() {
                  _isInformationVisible = !_isInformationVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Information'),
            ),
            if (_isInformationVisible) _buildInformationSection(),
        ],
      ),
    ),
  );
}
 Widget buildTextField(String label, String hint, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }





Widget buildSliderInput(String label, double currentValue, double min, double max, Function(double) onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center, // Center-align content within the column
    children: [
      Center( // Center-align the label text
        child: Text(
          label,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
      Slider(
        value: currentValue,
        min: min,
        max: max,
        divisions: max.toInt(),
        label: currentValue.toStringAsFixed(1),
        onChanged: onChanged,
      ),
    ],
  );
}





}


class Img2VidPage extends StatefulWidget {
  const Img2VidPage({super.key}); // Super parameter syntax

  @override
  Img2VidPageState createState() => Img2VidPageState();
}

class Img2VidPageState extends State<Img2VidPage> with RouteAware {

  bool _isLoading = false;
  bool _isLoggedIn = false;
  int? credits;
  
  bool _isInformationVisible = false;
  bool _isGenerateEnabled = false; // Manage generate button state
  File? _imageFile;
  String? _base64Image;
  int? steps = 20;
  Timer? _pollingTimer;
  bool _isAdvancedVisible = false;

  Uint8List? _videoBytes;
  VideoPlayerController? _videoController;
 
  final ApiService apiService = ApiService(); // Create instance

  @override
  void initState() {
    super.initState();

      _initializeInAppPurchaseListener();
    _checkLoginStatus();
   _fetchAndSetCredits(); // Fetch credits on initialization
  }
    
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  
    @override
  void dispose() {

 if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
  }
    _pollingTimer?.cancel(); // Stop polling when leaving the page
    _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
    if (mounted) {
    setState(() {
        _isLoggedIn = token != null;
      if (token != null){
        credits = null;
      }
    });
    }
  }

void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
              if (mounted) {
              Navigator.pushNamed(context, '/login'); // Navigate to login
              }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}

Future<void> _generateImg2VidImage() async {
  
  if (!_isLoggedIn) {
     _showLoginDialog(context);
    return;
  }
if (mounted) {
  setState(() => _isLoading = true); // Set loading to true
}
  final token = await getToken();
    if (token == null) return;
  try {
 

    final response = await http.post(
      Uri.parse('https://www.aimaker.world/generate/'),
      headers: {'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'image': _base64Image,
        'task_type': 'imggen_video',
        'steps': steps,
        
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final taskId = data['task_id'];
      if (taskId != 'error') {
        await _pollTaskResult(taskId, token);
      } else {
       if (mounted) {
     _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
        setState(() => _isLoading = false); // Stop loading if task fails
       }
      }
    } else {
    if (mounted) {
        _fetchAndSetCredits();
       final data = jsonDecode(response.body);
    final String errorMessage = data['error'] ?? 'Unknown error';
    _showDisputeSnackBar2(context, token, errorMessage);
      setState(() => _isLoading = false); // Stop loading on failure
    }
    }
  } catch (e) {
  if (mounted) {
       _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
    setState(() => _isLoading = false); // Stop loading on exception
  }
  }
}
   void _showDisputeSnackBar2(BuildContext context, String token, String error) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content:  Text("Something went wrong. $error."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}
   }
Future<void> _pollTaskResult(String taskId, String token) async {
  if (!mounted) return;
  _pollingTimer?.cancel(); // Cancel any existing timer

  _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
    if (!mounted) {
      timer.cancel(); // Stop polling if widget is unmounted
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('https://www.aimaker.world/task_result/'),
        headers: {'Authorization': 'Bearer $token'},
        body: jsonEncode({'task_id': taskId}),
      );

      if (response.statusCode == 200) {
          final data = jsonDecode(response.body);

          if (data['status'] == 'completed') {
           if (data['video_base64'] != null && data['video_base64'] is String) {
           
  String base64String = data['video_base64'];
  Uint8List videoBytes = base64Decode(base64String);
  _setVideoBytes(videoBytes);
  timer.cancel();
  if (mounted) {
  _fetchAndSetCredits();
      setState(() {
   _imageFile = null;
   _base64Image = null;
    _isGenerateEnabled = false; // Disable the generate button
  });
  }
} else {
if (mounted) {
    _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
  setState(() => _isLoading = false);
}
  timer.cancel();
  
}

          } else if (data['status'] != 'processing') {
           if (mounted) {
       _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
            setState(() => _isLoading = false);
           }
            timer.cancel();
          }
        } else {
          if (mounted) {
              _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
          setState(() => _isLoading = false);
          }
          timer.cancel();
        }
      } catch (e) {
        if (mounted) {
            _fetchAndSetCredits();
        _showDisputeSnackBar(context, token);
        setState(() => _isLoading = false);
        }
        timer.cancel();
      }
    });
  }
  void _showDisputeSnackBar(BuildContext context, String token) {
    if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=$token');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
    Future.delayed(const Duration(milliseconds: 20), () {if (!mounted) return;
    final banner = MaterialBanner(
      content: const Text("Experiencing issues? Check common problems."),
      actions: [
        TextButton(
          onPressed: () {
              if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
            _showCommonProblemsDialog(context);
          },
          child: const Text("Common Problems"),
        ),
      ],
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.all(8),
    );
if (mounted) {
   scaffoldMessengerKey.currentState?.showMaterialBanner(banner);
   
}
    // Set timer to auto-dismiss the banner after 5 seconds
    Timer(const Duration(seconds: 11), () {
        if (mounted) { // Check inside Timer before hiding the banner
    ScaffoldMessenger.of(context).hideCurrentMaterialBanner();}
 
    });
  });
}

void _showCommonProblemsDialog(BuildContext context) {
  if (!mounted) return; // FIRST LINE inside _showCommonProblemsDialog

  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Common Problems"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("1. Image Size: Ensure your image is below 5MB."),
            SizedBox(height: 8),
            Text("2. Format: Most heavily supported formats are PNG and JPG."),
            SizedBox(height: 8),
            Text("3. Network: Check your internet connection."),

            Text("Not working? Try different inputs."),
            
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

void _setVideoBytes(Uint8List videoBytes) async {
  if (!mounted) return;
  if (mounted) {
  setState(() => _isLoading = false);
  }
  _videoBytes = videoBytes;
  
  final directory = await getTemporaryDirectory();
  final path = '${directory.path}/temp_video.mp4';
  final file = File(path);
  await file.writeAsBytes(videoBytes);

  _videoController?.dispose();
  _videoController = VideoPlayerController.file(file)
 
    ..initialize().then((_) {
   if (mounted) {
      setState(() {});
      _videoController?.play();
   }
    }
);
}



  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  

  void _showMessage(String message) {
    if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }
 


Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
    

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
}Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
      if (mounted) {
      Navigator.pushNamed(context, route);
      }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
              fontWeight: FontWeight.bold,
              fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}

  void _navigateToHomePage(BuildContext context) {
    if (context.mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
    }
  }

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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

void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
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
  
StreamSubscription<List<PurchaseDetails>>? _subscription;

void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // Show a loading or pending message to the user
        _showSnackBar(context, 'Purchase is pending. Please wait...');
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
        if (mounted) {
          _showSnackBar(context, 'Purchase was canceled.');
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}



void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {

    return false;
  }
}

  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }

  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
}
    Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
        _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
            _buildServiceTile('Remove Background',"assets/images/bgremoval.png", context, '/background-removal'),
  _buildServiceTile('Replace Background',"assets/images/bgreplace.png", context, '/background-replace'),
 _buildServiceTile('Face Swap',"assets/images/mergefaces.png", context, '/merge-faces'),
 _buildServiceTile('Restore Face',"assets/images/resface.png", context, '/restore-face'),
  _buildServiceTile('Remove Watermark',"assets/images/wmremoval.png", context, '/watermark-removal'),
_buildServiceTile('Remove Text',"assets/images/txtremoval.png", context, '/text-removal'),


_buildServiceTile('Text-> Image',"assets/images/txt2img.png", context, '/txt2img'),
_buildServiceTile('Image-> Image',"assets/images/img2img.png", context, '/img2img'),

_buildServiceTile('Text-> Video',"assets/images/txt2vid.png", context, '/txt2vid'),

_buildServiceTile('Size/Convert',"assets/images/convert.png", context, '/convert'),
        ],
      ),
    );
  }
 Future<void> _downloadVideo() async {
  if (_videoBytes == null) return;

  final status = await Permission.photos.request();
  if (status.isGranted) {
    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/generated_video.mp4';
      final file = File(path);
      await file.writeAsBytes(_videoBytes!);

      final result = await ImageGallerySaver.saveFile(file.path, name: "generated_video");
      if (result['isSuccess']) {
        if (mounted) {
        _showMessage('Video saved to Photos!');
        }
      } else {
        if (mounted) {
        _showMessage('Failed to save video!');
        }
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Failed to save video!');
      }
    }
  } else {
    if (mounted) {
    _showMessage('Enable photo library permissions for this app in settings to download!');
    }
  }
}

 
  

 
 Widget buildAdvancedOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       
            const SizedBox(height: 8),
        buildSliderInput('Steps:', steps?.toDouble() ?? 50.0, 1, 50, (value) {
  setState(() => steps = value.toInt());
}),

       
      ],
    );
  }  void _togglePlayPause() {
    setState(() {
     
        _videoController!.play();
    });
  }
      Widget _buildInformationSection() {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 16), // Adjust top and left padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:  [
        const Text(
          'Input:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Select an image.'),
        const SizedBox(height: 12),
        const Text(
          'Result:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Video made from image.'),
         const SizedBox(height: 12),
              Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/pricing');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Pricing'),
          ),
        ),
        const SizedBox(height: 8),
        Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('More info'),
          ),
        ),
      
      ],
    ),
  );
}




  @override
Widget build(BuildContext context,{bool isHomePage = false}) {
  return Scaffold(
    appBar: AppBar(
       automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF5F5F5),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
     
         GestureDetector(
          onTap: () {
            if (!isHomePage) {
              if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
              }
            }
          },
          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
        IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          if (mounted) {
          Navigator.pushNamed(context, '/settings');
          }
        },
      ),const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
          _buildLogoutButton(context),
        ],
      ),
    ),
     backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
   
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         
          _buildHorizontalList(context),
          const SizedBox(height: 24),
           const Text(
              'Image -> Video',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize:25,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),
          // Improved Image Container
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(2, 4), // Shadow position
                ),
              ],
            ),
              child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
          )
        : _imageFile != null
            ? Image.file(
                _imageFile!,
                fit: BoxFit.cover,
              )
            : _videoController != null && _videoController!.value.isInitialized
                ? GestureDetector(
                    onTap: _togglePlayPause, // Toggle play/pause on tap
                    child: AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    ),
                  )
                : const Center(
                    child: Text(
                      'Generate a video from an image',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
  ),
),

          
          const SizedBox(height: 16),
          // Button Row
          Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Expanded(
      child: ElevatedButton(
        onPressed: _isLoading ? null : _pickImage,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 134, 92, 207),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Upload',
          style: TextStyle(color: Colors.black),
        ),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: ElevatedButton(
        onPressed: _isLoading || !_isGenerateEnabled ? null : _generateImg2VidImage,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 134, 92, 207),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Generate',
          style: TextStyle(color: Colors.black, fontSize: 13.55),
        ),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: ElevatedButton(
        onPressed: _isLoading || _videoBytes == null ? null : _downloadVideo,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 134, 92, 207),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: const Text(
          'Download',
          style: TextStyle(color: Colors.black, fontSize: 12.59),
        ),
      ),
    ),
  ],
),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                setState(() {
                  _isAdvancedVisible = !_isAdvancedVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Advanced Options'),
            ),
            if (_isAdvancedVisible) buildAdvancedOptions(),
              

          const SizedBox(height: 16),
          // Cost Display
             ElevatedButton(
              onPressed: () {
                if (mounted) {
                setState(() {
                  _isInformationVisible = !_isInformationVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Information'),
            ),
            if (_isInformationVisible) _buildInformationSection(),
        ],
      ),
    ),
  );
}
 Widget buildTextField(String label, String hint, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }

  
Future<void> _pickImage() async {
  if (!mounted) return;
    final status = await Permission.photos.request();
  if (status.isGranted) {
  
  try {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2024,
      maxHeight: 2024,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85, // Reduce size for compatibility
    );

    if (pickedFile != null) {
      // Check the dimensions of the image
     if (mounted) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _videoBytes = null;
          _base64Image = base64Encode(_imageFile!.readAsBytesSync());
          _isGenerateEnabled = true; // Enable the generate button
        });
     }
    }
  } catch (e) {
    if (mounted) {
    _showMessage('Image too large, Max: 2024x2024px');
    }
  }
     } else {
      if (mounted) {
    _showMessage('Enable photo library permissions for this app in settings to upload!');
      }
  }
}



Widget buildSliderInput(String label, double currentValue, double min, double max, Function(double) onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center, // Center-align content within the column
    children: [
      Center( // Center-align the label text
        child: Text(
          label,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
      Slider(
        value: currentValue,
        min: min,
        max: max,
        divisions: max.toInt(),
        label: currentValue.toStringAsFixed(1),
        onChanged: onChanged,
      ),
    ],
  );
}




}class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
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
          _buildSettingsOption(
            context,
            'Help',
            () => _launchURL('https://www.aimaker.world/help'),
          ),
           const SizedBox(height: 16),
          _buildSettingsOption(
            context,
            'Pricing',
            () => _launchURL('https://www.aimaker.world/pricing'),
          ),
          const SizedBox(height: 16),
          _buildSettingsOption(
            context,
            'Contact Us',
            () => _launchURL('https://www.aimaker.world/contact'),
          ),

         
          const SizedBox(height: 16),
          _buildSettingsOption(
            context,
            'Terms Of Service',
            () => _launchURL('https://www.aimaker.world/terms'),
          ),
          const SizedBox(height: 16),
          _buildSettingsOption(
            context,
            'Privacy Policy',
            () => _launchURL('https://www.aimaker.world/terms'),
          ),
         
        
          const SizedBox(height: 16),
          _buildSettingsOption(
            context,
            'Delete Account',
            () => _confirmDeleteAccount(context),
          ),
        ],
      ),
    );
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
      Uri.parse('https://www.aimaker.world/user/delete'),
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


class ConvertPage extends StatefulWidget {
  const ConvertPage({super.key}); // Super parameter syntax

  @override
  ConvertPageState createState() => ConvertPageState();
}

class ConvertPageState extends State<ConvertPage> with RouteAware {
 bool _isGenerateEnabled = false; // Manage generate button state
 File? _imageFile;

  bool _isInformationVisible = false;
 bool _isLastInputInvalid = false; //
  bool _isLoading = false;
  Uint8List? _imageBytes;
  bool _isLoggedIn = false;
  int? credits;
  int width = 1024;
  int height = 1024;

  String _selectedModel = '1';
  bool _isAdvancedVisible = false;

 
  final ApiService apiService = ApiService(); // Create instance

  @override
  void initState() {
    super.initState();

      _initializeInAppPurchaseListener();
    _checkLoginStatus();
   _fetchAndSetCredits(); // Fetch credits on initialization
  }
    
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }
@override
  void didPopNext() {
    // This method is called when the user returns to this page.
   
    _fetchAndSetCredits(); // Reload credits
  }
  
    @override
  void dispose() {
 if (mounted) {
  scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
  scaffoldMessengerKey.currentState?.hideCurrentMaterialBanner(); // Clear any remaining SnackBars
   
  } // Clear Material Banners
   _subscription?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }
  Future<void> _fetchAndSetCredits() async {
    if (!mounted) return;
    credits = await apiService._fetchCredits();
    if (mounted) {
      setState(() {
        credits = credits;
      });
    }
  }

  Future<void> _checkLoginStatus() async {
if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
    if (mounted) {
    setState(() {
        _isLoggedIn = token != null;
      if (token != null){
        credits = null;
      }
    });
    }
  }
void _showLoginDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Login Required"),
        content: const Text("Please log in to use this feature."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Dismiss the dialog
              if (mounted) {
              Navigator.pushNamed(context, '/login'); // Navigate to login
              }
            },
            child: const Text("Log In"),
          ),
        ],
      );
    },
  );
}

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  
Future<void> _generateConvertImage() async {
  if (!_isLoggedIn) {
    _showLoginDialog(context);
    return;
  }

  if (_imageFile == null) {
    _showMessage('No image selected!');
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    final token = await getToken();
    if (token == null) return;

    // Build multipart request
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://www.aimaker.world/convert-resize/'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('image', _imageFile!.path));

    // Add dimensions and format
    request.fields['width'] = width.toString();
    request.fields['height'] = height.toString();
    request.fields['format'] = _getModelValue();

    // Send request
    final response = await request.send();
    final responseData = await response.stream.toBytes();

    if (response.statusCode == 200) {
      // Update image bytes with the converted image
      setState(() {
        _imageBytes = responseData;
        _isGenerateEnabled = false; // Disable Generate button
        _imageFile = null; // Clear uploaded image
      });
      _showMessage('Image resized and converted successfully!');
    } else {
      _showMessage('Failed to process the image. Try again.');
    }
  } catch (e) {
    _showMessage('Error: ${e.toString()}');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

  void _showMessage(String message) {
       if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
       }
  }
 


Widget _buildLogoutButton(BuildContext context) {
    return FutureBuilder<bool>(
      future: apiService.isLoggedIn(),
      builder: (context, snapshot) {
    

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
}Widget _buildServiceTile(String title, String imagePath, BuildContext context, String route) {
  return GestureDetector(
    onTap: () {
      if (mounted) {
      Navigator.pushNamed(context, route);
      }
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circular image container
        Container(
          width: 70,
          height: 65,
          margin: const EdgeInsets.symmetric(horizontal: 8.0),  // Horizontal spacing only
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: ClipOval(
            child: imagePath.endsWith('.png')
                ? Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  )
                : SvgPicture.asset(
                    imagePath,
                    fit: BoxFit.contain,
                    width: 50,
                    height: 50,
                  ),
          ),
        ),
        // Title below the circle with custom font
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            title.replaceAll(' ', '\n'),  // Replaces spaces with line breaks
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,  // Small font size
              fontWeight: FontWeight.bold,
              fontFamily: 'CustomFontName',  // Use your font family here
            ),
          ),
        ),
      ],
    ),
  );
}

  void _navigateToHomePage(BuildContext context) {
    if (context.mounted) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const HomePage(), // Navigate to HomePage
      ),
    );
    }
  }

void _navigateToLoginPage(BuildContext context) {
  // Ensure widget is still mounted before navigating
  if (context.mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false, // Remove all routes to prevent back navigation
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
        if (context.mounted) {
          _navigateToHomePage(context); // Navigate after login
        }
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
void _showCreditOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 100 Credits option
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/images/credits.png',
                  width: 60,
                  height: 60,
                ),
                const SizedBox(width: 12),
                const Text(
                  '250 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.99', // Adjusted price for alignment
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit');
            },
          ),
          
          // 1000 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'More credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '650 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '4.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit2');
            },
          ),

          // 2500 Credits option with 25% better deal icon
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/credits.png',
                      width: 60,
                      height: 60,
                    ),
                    Positioned(
                      top: 1,
                      right: 1,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Most Credits+',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 7,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                const Text(
                  '1800 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '14.99',
                  style: TextStyle(fontSize: 16),
                ),
                const Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('credit1');
            },
          ),
        ],
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
  
StreamSubscription<List<PurchaseDetails>>? _subscription;

void _initializeInAppPurchaseListener() {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {

      _listenToPurchaseUpdated(purchaseDetailsList);
    },
    onDone: () => _subscription?.cancel(),
    onError: (error) {
        if (mounted) {
      _showSnackBar(context, 'Purchase error: $error');
        }
    },
  );
}
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        // Show a loading or pending message to the user
        _showSnackBar(context, 'Purchase is pending. Please wait...');
        break;
        
      case PurchaseStatus.purchased:
        _handlePurchaseSuccess(purchaseDetails);
        break;
        
      case PurchaseStatus.error:
        if (mounted) {
          _showDisputeSnackBar3(context);
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      case PurchaseStatus.canceled:
        if (mounted) {
          _showSnackBar(context, 'Purchase was canceled.');
        }
        InAppPurchase.instance.completePurchase(purchaseDetails); // Clear canceled purchase
        break;
        
      default:
        break;
    }
  }
}



void _showDisputeSnackBar3(BuildContext context) {
  if (!mounted) return;
  final snackBar = SnackBar(
    content: const Text("Something went wrong. If you believe you shouldn't have been charged, please contact us."),
    action: SnackBarAction(
      label: "Contact",
      onPressed: () async {
        final url = Uri.parse('https://www.aimaker.world/contact?subject=');
        if (await canLaunchUrl(url)) {
          await launchUrl(
            url,
            mode: LaunchMode.inAppWebView, // Opens in-app web view
          );
        } else {
          throw 'Could not launch $url';
        }
      },
    ),
    duration: const Duration(seconds: 5),
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
  );

  if (mounted) { // Check right before showing the SnackBar
  ScaffoldMessenger.of(context).showSnackBar(snackBar);
}

  // Show "Common Problems" banner with a timer for automatic dismissal
   
}
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt);

    if (success) {
      if (mounted) {
        _fetchAndSetCredits(); // Refresh credits if validation succeeds
        _showCelebrationWidget(context); // Show celebration widget
      }
    } else {
      if (mounted && !_isCelebrationActive) {
        _showDisputeSnackBar3(context);
      }
    }
  } else {
    if (mounted && !_isCelebrationActive) {
      _showDisputeSnackBar3(context);
    }
  }

  InAppPurchase.instance.completePurchase(purchaseDetails); // Mark purchase complete
}

Future<bool> _sendReceiptToBackend(String receipt) async {
  final token = await apiService.getToken(); // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.aimaker.world/validate_receipt/'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token', // Include token if required
    },
    body: jsonEncode({
      'receipt_data': receipt, // Only send receipt data
    }),
  );

  // Check if the backend confirms the purchase based on status code
  if (response.statusCode == 200) {
    // Purchase validation succeeded
    return true;
  } else {

    return false;
  }
}

  void _buyCredits(String productId) async {
  await InAppPurchase.instance.restorePurchases();

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }

  // Define product identifiers
  const Set<String> productIds = {'credit', 'credit2', 'credit1'};
  final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(productIds);

  if (response.notFoundIDs.isNotEmpty) {
    if (mounted) {
    _showSnackBar(context, 'Product not found.');
    }
    return;
  }

  // Identify the correct product details for the requested ID
  final ProductDetails productDetails = response.productDetails.firstWhere((product) => product.id == productId);
  final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);

  // Initiate purchase
  InAppPurchase.instance.buyConsumable(purchaseParam: purchaseParam);
}
    Widget _buildHorizontalList(BuildContext context) {
    return SizedBox(
      height: 103,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
     _buildServiceTile('Doodle',"assets/images/doodle.png", context, '/doodle'),
            _buildServiceTile('Remove Background',"assets/images/bgremoval.png", context, '/background-removal'),
  _buildServiceTile('Replace Background',"assets/images/bgreplace.png", context, '/background-replace'),
 _buildServiceTile('Face Swap',"assets/images/mergefaces.png", context, '/merge-faces'),
 _buildServiceTile('Restore Face',"assets/images/resface.png", context, '/restore-face'),
  _buildServiceTile('Remove Watermark',"assets/images/wmremoval.png", context, '/watermark-removal'),
_buildServiceTile('Remove Text',"assets/images/txtremoval.png", context, '/text-removal'),


_buildServiceTile('Text-> Image',"assets/images/txt2img.png", context, '/txt2img'),
_buildServiceTile('Image-> Image',"assets/images/img2img.png", context, '/img2img'),

_buildServiceTile('Image-> Video',"assets/images/img2vid.png", context, '/img2vid'),

_buildServiceTile('Text-> Video',"assets/images/txt2vid.png", context, '/txt2vid'),

        ],
      ),
    );
  }
Future<void> _downloadImage() async {
  if (_imageBytes == null) return;

  // Request photo library permission.
  final status = await Permission.photos.request();
  if (status.isGranted) {
    try {
      // Save the image to the photo gallery.
      final result = await ImageGallerySaver.saveImage(
        Uint8List.fromList(_imageBytes!),
        quality: 100,
        name: "COVERTED_image",
      );

      if (result['isSuccess']) {
        if (mounted) {
        _showMessage('Successfully saved to photos.');
        }
      } else {
        if (mounted) {
        _showMessage('Failed to save.');
        }
      }
    } catch (e) {
      if (mounted) {
      _showMessage('Failed to save.');
      }
    }
  } else {
    if (mounted) {
     _showMessage('Enable photo library permissions for this app in settings to download!');
    }
  }
}
  
Widget buildDropdown() {
  return Center(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.center, // Center-align content within the column
      children: [
        const Center(
          child: Text(
            'Model:',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center, // Center-align the label text
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.deepPurple, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 5,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: DropdownButton<String>(
            isExpanded: true,
            underline: Container(),
            value: _selectedModel, // Ensure this matches one of the items
            items: const [
              DropdownMenuItem(value: '1', child: Center(child: Text('PNG'))),
              DropdownMenuItem(value: '2', child: Center(child: Text('JPEG'))),
              DropdownMenuItem(value: '3', child: Center(child: Text('WEBP'))),
            ],
            onChanged: (value) {
              if (value != null && mounted) {
                setState(() {
                  _selectedModel = value;
                });
              }
            },
            icon: const SizedBox.shrink(),
          ),
        ),
      ],
    ),
  );
}
  
 String _getModelValue() {
  switch (_selectedModel) {
    case '1':
      return 'PNG';
    case '2':
      return 'JPEG';
    case '3':
      return 'WEBP';
    default:
      return 'PNG'; // Default to PNG if no valid option is selected
  }
}

 Widget buildAdvancedOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
      
            const SizedBox(height: 8),
     buildNumberInput('Width:', width, 'Max: 2048 ', (value) {
  int? val = int.tryParse(value);
  if (val != null && val <= 2048) {
    setState(() => width = val);
  }
}),
buildNumberInput('Height:', height, 'Max: 2048 ', (value) {
  int? val = int.tryParse(value);
 if (val != null && val > 0 && val <= 2048) {
  setState(() => width = val);
} else {
  _showMessage('Value must be between 1 and 2048.');
}

}),

 
       
        buildDropdown(),
      ],
    );
  }
     Widget _buildInformationSection() {
  return Padding(
    padding: const EdgeInsets.only(top: 8, left: 16), // Adjust top and left padding
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:  [
        const Text(
          'Input:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
       const SizedBox(height: 4),
        const Text('Select an image. Enter a desized format and size.'),
        const SizedBox(height: 12),
       const Text(
          'Result:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text('Resized and Converted image.'),
    const SizedBox(height: 12),
              Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/pricing');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('Pricing'),
          ),
        ),
        const SizedBox(height: 8),
        Center(  // Center the button within the column
          child: ElevatedButton(
            onPressed: () async {
              final url = Uri.parse('https://www.aimaker.world/help');
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.inAppWebView,
                );
              } else {
                throw 'Could not launch $url';
              }
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(40),
            ),
            child: const Text('More info'),
          ),
        ),
        
      ],
    ),
  );
}



  @override
Widget build(BuildContext context,{bool isHomePage = false}) {
  return Scaffold(
    appBar: AppBar(
       automaticallyImplyLeading: false,
      backgroundColor: const Color(0xFFF5F5F5),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
      
         GestureDetector(
          onTap: () {
            if (!isHomePage) {
              if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
              }
            }
          },
          child: Image.asset(
                'assets/images/logo.png',
                height: 40,fit: BoxFit.contain,
              ),
        ),
        IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          if (mounted) {
          Navigator.pushNamed(context, '/settings');
          }
        },
      ),const Spacer(),
          
          if (credits != null)
            ElevatedButton(
              onPressed: () {
                _showCreditOptions(context);
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Colors.white,
                foregroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Credits: ${credits ?? 0}'),
            ),

          const Spacer(),
          _buildLogoutButton(context),
        ],
      ),
    ),
     backgroundColor: const Color(0xFFF5F5F5),
    body: SingleChildScrollView(
      
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
       
          _buildHorizontalList(context),
          const SizedBox(height: 24),
            const Text(
              'Resize and Convert',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'CustomFontName',  // Use your custom font here
                fontSize:25,                  // Adjust font size as needed
                fontWeight: FontWeight.bold,
              ),
            ),
             const SizedBox(height: 3),

          // Improved Image Container
          Container(
            height: 300,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(2, 4), // Shadow position
                ),
              ],
            ),
             child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
            ),
          )
        : _imageBytes != null
            ? Image.memory(
                _imageBytes!,
                fit: BoxFit.cover,
              )
            : _imageFile != null
                ? Image.file(
                    _imageFile!,
                    fit: BoxFit.cover,
                  )
                : const Center(
                    child: Text(
                      'Resize/Convert an image',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
  ),
),
           
          const SizedBox(height: 16),
      Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Upload',
                    style: TextStyle(color: Colors.black),),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  
                  onPressed: _isLoading || _imageFile == null || !_isGenerateEnabled
                      ? null
                      : _generateConvertImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Generate',
                    style: TextStyle(color: Colors.black, fontSize: 13.55)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading || _imageBytes == null
                      ? null
                      : _downloadImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 134, 92, 207),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Download',
                    style: TextStyle(color: Colors.black, fontSize: 12.59)),
                ),
              ),
            ],
          ),
             const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (mounted) {
                setState(() {
                  _isAdvancedVisible = !_isAdvancedVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Advanced Options'),
            ),
            if (_isAdvancedVisible) buildAdvancedOptions(),
              
          const SizedBox(height: 16),
          // Button Row
        

          // Cost Display
             ElevatedButton(
              onPressed: () {
                if (mounted) {
                setState(() {
                  _isInformationVisible = !_isInformationVisible;
                });
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Information'),
            ),
            if (_isInformationVisible) _buildInformationSection(),
        ],
      ),
    ),
  );
}
 Widget buildTextField(String label, String hint, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextField(
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
      ),
    );
  }
 Widget buildNumberInput(String label, int? value, String hint, Function(String) onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: TextField(
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      onChanged: (input) {
        // Check if input is empty or a number
        if (input.isEmpty || int.tryParse(input) != null) {
          _isLastInputInvalid = false; // Reset the invalid flag
          onChanged(input); // Trigger callback for number or empty input
        } else if (!_isLastInputInvalid) {
          if (mounted) {
          _showMessage('Please enter a number.');
          }
          _isLastInputInvalid = true; // Mark as invalid to prevent further spam
        }
      },
    ),
  );
}


Future<void> _pickImage() async {
  if (!mounted) return;
   final status = await Permission.photos.request();
  if (status.isGranted) {
  
  try {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2048,
      maxHeight: 2048,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85, // Reduce size for compatibility
    );

    if (pickedFile != null) {
     
        if (mounted) {
    setState(() {
  _imageFile = File(pickedFile.path);
  _imageBytes = null;
  _isGenerateEnabled = true; // Enable the generate button
});

        
    }
    }
  } catch (e) {
    if (mounted) {
    _showMessage('Image too large, Max: 1024x1024px');
    }
  }
   } else {
    if (mounted) {
    _showMessage('Enable photo library permissions for this app in settings to upload!');
    }
  }
}




Widget buildSliderInput(String label, double currentValue, double min, double max, Function(double) onChanged) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center, // Center-align content within the column
    children: [
      Center( // Center-align the label text
        child: Text(
          label,
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ),
      Slider(
        value: currentValue,
        min: min,
        max: max,
        divisions: max.toInt(),
        label: currentValue.toStringAsFixed(1),
        onChanged: onChanged,
      ),
    ],
  );
}



}
