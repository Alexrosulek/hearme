import 'dart:convert';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'knowledge.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_animate/flutter_animate.dart';

import 'profile.dart';
import 'dart:async'; // Import for Timer
import 'dart:ui';
class HomePage extends StatefulWidget {
  final String jwt;
  const HomePage({super.key, required this.jwt});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Whether user is new: true=new, false=not new, null=loading
  bool? _isNewUser;
bool _isonboarded = false;
  /// Whether user is on a “free” subscription or not
  bool? _isFreeSubscription;

  /// Control whether to show the celebration animation
  final bool _showCelebration = false;

  @override
  void initState() {
    super.initState();
  
    _fetchUserData();
      SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }
 @override
  void dispose() {
    // Unlock orientation when leaving HomePage
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }
  /// Fetches user data from the server
  Future<void> _fetchUserData() async {
    setState(() {
      _isNewUser = null;
      _isFreeSubscription = null;
    });

    try {
      // 1) Check if user is new
      final responseIsNew = await http.get(
        Uri.parse('https://www.hearme.services/user/isnew/'),
        headers: {'Authorization': 'Bearer ${widget.jwt}'},
      );

      // 2) Check subscription
      final responseSubscription = await http.get(
        Uri.parse('https://www.hearme.services/user/subscription'),
        headers: {'Authorization': 'Bearer ${widget.jwt}'},
      );

      // Evaluate responses
      if ((responseIsNew.statusCode == 200 || responseIsNew.statusCode == 201) &&
          responseSubscription.statusCode == 200) {
        final isNew = (responseIsNew.statusCode == 200);
        final jsonSub = jsonDecode(responseSubscription.body);
        final isFree = (jsonSub['subscription'] == 'free');

        setState(() {
          _isNewUser = isNew;
          _isFreeSubscription = isFree;
        });
      } else {
        // Fallback if status codes are unexpected
        setState(() {
          _isNewUser = false;
          _isFreeSubscription = true;
        });
      }
    } catch (e) {
      // On network error, treat user as not new & free
      setState(() {
        _isNewUser = false;
        _isFreeSubscription = true;
      });
    }
  }

  /// Called after the last onboarding slide.  
  /// Briefly show a celebration, then remove it.
  void _onOnboardingComplete() {
    setState(() {
      _isNewUser = false;
     
      _isonboarded = true;
    });

    // Hide celebration after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
       
        _isonboarded = false;
        
      });
    });
  }




  @override
  Widget build(BuildContext context) {
    // 1) Still loading user info
    if (_isNewUser == null || _isFreeSubscription == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 2) If we’re currently showing the celebration
    if (_showCelebration) {
      return Scaffold(
        body: Stack (children: [
          // Background content (image grid)
          _buildImageGrid(context, widget.jwt),

          // Celebration Dialog (conditionally displayed)
          CelebrationDialog(
            isonboarded: _isonboarded,
            onDismiss: () {
              setState(() {
                _isonboarded = true;
              });
            },
          ),
        ],)
        
      );
    }

    // 3) If user is new => show full-screen onboarding
    if (_isNewUser == true) {
      return OnboardingFlow(
        showExtraAds: !_isFreeSubscription!,
        onComplete: _onOnboardingComplete,
      );
    }
else{
    // 4) Otherwise => show ONLY the full-screen grid
    return Scaffold(
      // Remove the AppBar if you want truly full screen
      body: Center(
        child: _buildImageGrid(context, widget.jwt),
      ),
    );
  }
  }
}

class InfoTextBox extends StatelessWidget {
  const InfoTextBox({super.key});


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 12),
              Text(
                "We offer two primary services: transcription and speech; With a third special option, Buddy.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "1️⃣ Transcription",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "- Transcription is offered for free to all users.\n"
                "- It captures spoken words and converts them into text in real-time.\n"
                "- Seamless and accurate to ensure you don’t miss any details.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.6,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "2️⃣ Speech",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "- Speech can be issued in real-time as transcription occurs.\n"
                "- The speech is personalizeable from a customizeable persona, tone, speech pace, etc.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.6,
                ),
              ),
              SizedBox(height: 16),
              Text(
                "3️⃣ Buddy",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "- This mode can do all of the previous modes at once.\n"
                "- Knowledge base you can enter to give Buddy persona context.\n"
                "- Tell Buddy things on the fly.\n"
                "- Buddy can ask you a question during conversation if it needs help.\n"
                "- Change Buddy's personality, tone, speech pace, etc.\n"
                "- Enter a goal and let Buddy loose to conversate for you.",
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OnboardingFlow extends StatefulWidget {
  final VoidCallback onComplete;
  final bool showExtraAds;

  const OnboardingFlow({
    super.key,
    required this.onComplete,
    required this.showExtraAds,
  });

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  late AnimationController _animationController;


  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  
    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  List<Widget> get _pages {
    return [
      
          _page1(),
      _finalPage(),
    ];
  }
  
Widget _finalPage() {
  return Container(
    decoration: _buildBackgroundGradient(Colors.blueAccent),
    child: SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Header section
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 16),
                   Text(
                    'Here is the rundown.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // InfoTextBox section
          const Expanded(
            flex: 3,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: InfoTextBox(),
            ),
          ),

          // Comparison Chart section
          Expanded(
            flex: 3,
            child: _buildComparisonChart(),
          ),

          // Button section
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: widget.onComplete,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.purpleAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Start'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _page1() {
  
 

  

  return Container(
    decoration: _buildBackgroundGradient(Colors.blueAccent),
    child: SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Header Section
          Expanded(
            flex: 2,
            child: Container(
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.waving_hand, size: 80, color: Colors.white),
                  SizedBox(height: 24),
                  Text(
                    'Glad you could make it, Watch us in action!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
          // GIF Section
          Expanded(
            flex: 3,
            child: Image.asset(
              'assets/video.gif',
              fit: BoxFit.cover,
            ),
          ),
          // Next Button
          _nextButton(),
        ],
      ),
    ),
  );
}

Widget _buildComparisonChart() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow:const [
        BoxShadow(
          color: Colors.black12,
          blurRadius: 10,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        
          const SizedBox(height: 10),
          Table(
            border: const TableBorder(
              horizontalInside: BorderSide(color: Colors.black12, width: 1),
            ),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              _buildHeaderRow(['Mode','Transcribe', 'Speech', 'Autonomous', ]),
              _buildFeatureRowWithInfo('Transcribe',  true, false, false, 'Transcribe speech to text.'),
              _buildFeatureRowWithInfo('Manual',true,   true, false,  'Transcribe speech to text and type what you want to say, your "Buddy" persona will speak it.'),
              _buildFeatureRowWithInfo('Buddy', true, true, true, 'Transcribe speech to text and an AI agent, Buddy, will handle the conversating automatically. Buddy can ask you questions with popups and will use its objective to talk to the conversee and help you.'),

            ],
          ),
          
          
         
          const SizedBox(height: 10),
          Table(
            border: const TableBorder(
              horizontalInside: BorderSide(color: Colors.black12, width: 1),
            ),
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
              4: FlexColumnWidth(1),
              5: FlexColumnWidth(1),
            },
            children: [
              _buildHeaderRow(['Feature', 'Free', 'Bronze', 'Silver', 'Gold', 'Diamond']),
                            _buildFeatureRowWithInfo2('All Modes', true,  true, true, true, true,'All modes are available to everyone and cost credits. "Free" users are only refreshed transcribe credits.'),
                               _buildFeatureRowWithInfo2('Realtime', true,  true, true, true, true,'All modes process faster than required enableding realtime conversations and listening.'),
       
              _buildSubscriptionRowWithInfo('Queue Priority', '5', '4', '3', '2', '1', 'If there is a line for a room, you will be queued first over higher numbered users.'),
              _buildSubscriptionRowWithInfo('Daily Credits', '200', '500', '1250', '3000', '5000', 'Daily refresh of the users credits. "Free" users are only refreshed transcribe credits.'),

         
            ],
          ),
        ],
      ),
    ),
  );
}

TableRow _buildHeaderRow(List<String> headers) {
  return TableRow(
    children: headers.map((header) {
      return Padding(
        padding: const EdgeInsets.all(0.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              header,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 8,
                color: Colors.black87,
              ),
            ),
          
          ],
        ),
      );
    }).toList(),
  );
}

TableRow _buildFeatureRowWithInfo2(String mode, bool realtime, bool speechToText, bool manual, bool aiAssist,bool aiAssist2, String info) {
  return TableRow(
    children: [
      Padding(
        padding: const EdgeInsets.all(1.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                mode,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                ),
                
              ),
            ),
            IconButton(
          
              icon: const Icon(Icons.info_outline, size: 10, color: Colors.black),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
             
                    content: Text(info),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child:const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
       _buildIconCell(realtime),
      _buildIconCell(speechToText),
      _buildIconCell(manual),
      _buildIconCell(aiAssist),
        _buildIconCell(aiAssist2),
    ],
  );
}
TableRow _buildFeatureRowWithInfo(String mode, bool speechToText, bool manual, bool aiAssist, String info) {
  return TableRow(
    children: [
      Padding(
        padding: const EdgeInsets.all(1.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                mode,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                ),
                
              ),
            ),
            IconButton(
          
              icon: const Icon(Icons.info_outline, size: 10, color: Colors.black),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    
                    content: Text(info),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
     
      _buildIconCell(speechToText),
      _buildIconCell(manual),
      _buildIconCell(aiAssist),
    ],
  );
}

TableRow _buildSubscriptionRowWithInfo(String mode, String free, String bronze, String silver, String gold, String diamond, String info) {
  return TableRow(
    children: [
      Padding(
        padding: const EdgeInsets.all(0.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Flexible(
              child: Text(
                mode,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black87,
                ),
              
              ),
            ),
            IconButton(
           
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.info_outline, size: 10, color: Colors.black),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                   
                    content: Text(info),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
      _buildCell(free),
      _buildCell(bronze),
      _buildCell(silver),
      _buildCell(gold),
      _buildCell(diamond),
    ],
  );
}

Widget _buildIconCell(bool available) {
  return Padding(
    padding: const EdgeInsets.only(top: 18.8), // Adjust the top padding to move the icon down
    child: Center(
      child: Icon(
        available ? Icons.check_circle : Icons.cancel,
        color: available ? Colors.green : Colors.red,
        size: 11,
      ),
    ),
  );
}

Widget _buildCell(String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 16.5), // Adjust the top padding to move the text down
    child: Center(
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
      ),
    ),
  );
}



  BoxDecoration _buildBackgroundGradient(Color color) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withOpacity(0.8), color],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
  }

  Widget _nextButton() {
    return ElevatedButton(
      onPressed: _nextPage,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text('Next'),
    );
  }

  void _nextPage() {
    if (_currentIndex < _pages.length - 1) {
      setState(() {
        _animationController.reset();
        _animationController.forward();
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
              _animationController.reset();
              _animationController.forward();
            },
            children: _pages,
          ),
         
        ],
      ),
    );
  }
    }
double _calculateChildAspectRatio(BuildContext context) {
  final screenHeight = MediaQuery.of(context).size.height;

  // Baseline height of 844px returns an aspect ratio of 0.6
  const double baselineHeight = 844.0;
  const double baselineAspectRatio = 0.55;

  // Calculate the aspect ratio based on screen height
  final aspectRatio = (screenHeight / baselineHeight) * baselineAspectRatio;

  // Clamp the aspect ratio to prevent extreme values
  return aspectRatio.clamp(0.5, 0.85);
}





Widget _buildImageGrid(BuildContext context, String jwtToken) {
  final List<Map<String, dynamic>> gridItems = [
    {'type': 'widget', 'widget': _CreditsWidget(jwt: jwtToken)}, // Credits Widget
  {'type': 'widget', 'widget':  LanguageWidget(
            jwtToken: jwtToken
          ),
       
  
}

,   
      
   {
      'type': 'widget',
      'widget': GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/settings'),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset:  Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Image.asset(
          'assets/images/settingicon.png',
          width: 40,
          height: 40,
        ),
        ),
      ),
    },   
          {'type': 'widget', 'widget': Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child:ProfileModal(jwtToken: jwtToken)    ),
         }, // Credits Widget
   
      {'type': 'widget', 'widget': Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),

          child:
          KnowledgeBaseModal(jwtToken: jwtToken)    ),},
               {'type': 'widget', 'widget': 
 BuyCreditsWidget(
     jwtToken:jwtToken)
        },   
   {'type': 'combined', 'widget':  const WhoIsBuddyWidget(), } ,{'type': 'combined', 'widget':  const WhoIsBuddy2Widget(), }

  ];

  return Stack(
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
          color: Colors.transparent,
        ),
      ),
      // Foreground Grid
      Column(
        children: [
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: _calculateChildAspectRatio(context),
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: gridItems.length,
              itemBuilder: (context, index) {
                final item = gridItems[index];
                if (item['type'] == 'image') {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, item['route']!);
                    },
                    child: Image.asset(
                      item['path']!,
                      fit: BoxFit.cover,
                    ),
                  );
                } else if (item['type'] == 'widget') {
                  return Container(
                    padding: const EdgeInsets.all(8.0),
                    child: item['widget'] as Widget,
                  );
                } else if (item['type'] == 'combined') {
                  return Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: item['widget'] as Widget,
                      ),
                    ],
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        ],
      ),
    ],
  );
}



class _CreditsWidget extends StatefulWidget {
  final String jwt; // Pass the JWT token
  const _CreditsWidget({required this.jwt});

  @override
  __CreditsWidgetState createState() => __CreditsWidgetState();
}

class __CreditsWidgetState extends State<_CreditsWidget> {
  int credits = 0; // Current credits
  String subscription = ""; // Current subscription tier
  int refreshAmount = 0; // Refresh amount
  String timeUntilNextRefill = "00:00:00"; // Formatted time until next refill
  Timer? _pollingTimer; // Timer for polling refresh interval
  Timer? _localTimer;

  @override
  void initState() {
    super.initState();
    _initializeData(); // Initialize data from the server
    _startPolling(); // Start polling for refresh interval
    _startLocalTimer(); // Start local increment timer
  }

  @override
  void dispose() {
    _pollingTimer?.cancel(); // Clean up polling timer
    _localTimer?.cancel(); // Cancel local timer
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _fetchSubscriptionData();
    await _fetchAndSetRefreshTimer();
  }

  void _startLocalTimer() {
    _localTimer?.cancel();
    _localTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _incrementTime();
        });
      }
    });
  }
  
  /// Build an animated section with optional sub-items
  Widget _buildAnimatedSection( String value,
      {List<Widget>? subItems}) {
    return Container(
        decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
   
    
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
     
const SizedBox(height: 10),
Text(
  value,
  style: const TextStyle(
    color: Colors.black54,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  ),
).animate().fadeIn(delay: 500.ms).scale(),

      
          if (subItems != null) ...subItems,
        ],
      ),
    
    );
  }
  void _incrementTime() {
    List<String> parts = timeUntilNextRefill.split(':');
    int hours = int.parse(parts[0]);
    int minutes = int.parse(parts[1]);
    int seconds = int.parse(parts[2]);

    seconds--;
    if (seconds < 0) {
      seconds = 59;
      minutes--;
      if (minutes < 0) {
        minutes = 59;
        hours--;
        if (hours < 0) {
          hours = 0;
          minutes = 0;
          seconds = 0;
        }
      }
    }

    timeUntilNextRefill =
        "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchSubscriptionData() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.hearme.services/user/subscription'),
        headers: {'Authorization': 'Bearer ${widget.jwt}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          credits = data['credits'] ?? 0;
          subscription = data['subscription'] ?? "Unknown";
          refreshAmount = data['refreshamount'] ?? 0;
        });
      } else {
        debugPrint('Failed to fetch subscription data: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error fetching subscription data: $e');
    }
  }

  Future<void> _fetchAndSetRefreshTimer() async {
    try {
      final response = await http.get(
        Uri.parse('https://www.hearme.services/refresh_interval'),
        headers: {'Authorization': 'Bearer ${widget.jwt}'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final timeData = data['time_until_next_refill'];

        setState(() {
          timeUntilNextRefill = "${timeData['hours'].toString().padLeft(2, '0')}:"
              "${timeData['minutes'].toString().padLeft(2, '0')}:"
              "${timeData['seconds'].toString().padLeft(2, '0')}";
        });
      }
    } catch (e) {
      debugPrint('Error fetching refresh interval: $e');
    }
  }

  void _startPolling({Duration interval = const Duration(minutes: 1)}) {
    _pollingTimer?.cancel();

    _pollingTimer = Timer.periodic(interval, (_) async {
      await _fetchAndSetRefreshTimer(); // Sync the timer periodically
    });
  }

  void _showInfoDialog(String title, String description) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Okay"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blueAccent, Colors.lightBlueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          _buildAnimatedBox("Credits", "$credits", "Your total credits."),
          const SizedBox(height: 20),
          _buildAnimatedSection( subscription, subItems: [
           
            _buildSubItem("Next Refill", timeUntilNextRefill,
                description: "The time remaining until your credits refill."),
                 _buildSubItem("Refill", "$refreshAmount",
                description: "The number of credits you will receive up to per refill."),
           
          ]),
        ],
      ),
    );
  }

  Widget _buildAnimatedBox(String title, String value, String description) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.blueAccent),
            onPressed: () => _showInfoDialog(title, description),
          ),
        ],
      ),
    );
  }

  Widget _buildSubItem(String title, String value, {String? description}) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.blueAccent),
            onPressed: () => _showInfoDialog(title, description ?? ""),
          ),
        ],
      ),
    );
  }
}


class CelebrationDialog extends StatelessWidget {
  final VoidCallback onDismiss;
  final bool isonboarded;
  const CelebrationDialog({super.key,required this.isonboarded, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child:  Stack(
        alignment: Alignment.center,
        children: [
          // Placeholder for animated balloons or confetti
         
         if (isonboarded)
          const Positioned(
            child: Text(
              "🎉 Hope you enjoy! 🎉",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          )
        else
          const Positioned(
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

class Celebration2Dialog extends StatelessWidget {
  final VoidCallback onDismiss;

  const Celebration2Dialog({super.key, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated Balloons
          Positioned(
            top: 0,
            child: _buildBalloons(),
          ),

          // Celebration Text
          Positioned(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "🎉 Welcome! 🎉",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                 const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: onDismiss,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalloons() {
    return Stack(
      children: [
        _animatedBalloon(Colors.red, -60),
        _animatedBalloon(Colors.blue, -20),
        _animatedBalloon(Colors.green, 20),
        _animatedBalloon(Colors.yellow, 60),
      ],
    );
  }

  Widget _animatedBalloon(Color color, double offsetX) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 1.5, end: -0.5),
      duration: const Duration(seconds: 5),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(offsetX, value * 300),
          child: Icon(
            Icons.circle,
            size: 50,
            color: color,
          ),
        );
      },
    );
  }
}

class BuyCreditsWidget extends StatefulWidget {
  final String jwtToken;

  const BuyCreditsWidget({super.key, required this.jwtToken});

  @override
  BuyCreditsWidgetState createState() => BuyCreditsWidgetState();
}

class BuyCreditsWidgetState extends State<BuyCreditsWidget> {
  bool _isLoading = false;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
Set<String> productIds = {'monthly_subscription', 'annual_subscription'};

  @override
  void initState() {
    super.initState();
    _initializeInAppPurchaseListener(widget.jwtToken, context);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleTap() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      _showCreditOptions(context);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  void _showSubscriptionOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Bronze Option
          ListTile(
            title: const Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.star,
                  color: Colors.brown,
                  size: 24,
                ),
                 SizedBox(width: 8),
               Text(
                  'Bronze',
                  style: TextStyle(fontSize: 24),
                ),
                Spacer(),
                Text(
                  '\$1.99',
                  style: TextStyle(fontSize: 16),
                ),
                 Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('bronze1', context);
            },
          ),

          // Silver Option
          ListTile(
            title: const Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.star,
                  color: Colors.grey,
                  size: 24,
                ),
                 SizedBox(width: 8),
                 Text(
                  'Silver',
                  style: TextStyle(fontSize: 24),
                ),
                 Spacer(),
                 Text(
                  '\$3.99',
                  style: TextStyle(fontSize: 16),
                ),
                 Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('silver1', context);
            },
          ),

          // Gold Option
          ListTile(
            title: const Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.star,
                  color: Colors.amber,
                  size: 24,
                ),
                 SizedBox(width: 8),
                 Text(
                  'Gold',
                  style: TextStyle(fontSize: 24),
                ),
                Spacer(),
                Text(
                  '\$9.99',
                  style: TextStyle(fontSize: 16),
                ),
                 Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('gold1', context);
            },
          ),

          // Diamond Option
          ListTile(
            title: const Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(
                  Icons.star,
                  color: Colors.blueAccent,
                  size: 24,
                ),
               SizedBox(width: 8),
                 Text(
                  'Diamond',
                  style: TextStyle(fontSize: 24),
                ),
                 Spacer(),
               Text(
                  '\$14.99',
                  style: TextStyle(fontSize: 16),
                ),
                 Icon(
                  Icons.attach_money,
                  size: 24,
                ),
              ],
            ),
            onTap: () {
              Navigator.pop(context);
              _buyCredits('diamond1', context);
            },
          ),
        ],
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
                  '500 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '.49', // Adjusted price for alignment
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
              _buyCredits('1credit', context);
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
                  '1500 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '1.29',
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
              _buyCredits('2credit', context);
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
                  '3500 credits',
                  style: TextStyle(fontSize: 24),
                ),
                const Spacer(),
                const Text(
                  '2.99',
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
              _buyCredits('3credit', context);
            },
          ),
        ],
      );
    },
  );
}


void _initializeInAppPurchaseListener(String token, BuildContext context) {
  _subscription = InAppPurchase.instance.purchaseStream.listen(
    (List<PurchaseDetails> purchaseDetailsList) {
      if (mounted) {
        _listenToPurchaseUpdated(purchaseDetailsList, token, context);
      }
    },
    onDone: () {
      _subscription?.cancel();
    },
    onError: (error) {
      if (mounted) {
        _showSnackBar(context, 'Purchase error: $error');
      }
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
void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList, String token, BuildContext context) {
  for (var purchaseDetails in purchaseDetailsList) {
    switch (purchaseDetails.status) {
      case PurchaseStatus.pending:
        _showSnackBar(context, 'Subscription is pending. Please wait...');
        break;

      case PurchaseStatus.purchased:
       
          _handlePurchaseSuccess(purchaseDetails, token, context);
        
        break;

      case PurchaseStatus.error:
        _showDisputeSnackBar3(context);
        InAppPurchase.instance.completePurchase(purchaseDetails);
        break;

      case PurchaseStatus.canceled:
        _showSnackBar(context, 'Subscription was canceled.');
        InAppPurchase.instance.completePurchase(purchaseDetails);
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
        final url = Uri.parse('https://www.hearme.services/contact?subject=');
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
void _handlePurchaseSuccess(PurchaseDetails purchaseDetails, String token,BuildContext context) async {
  if (purchaseDetails.verificationData.serverVerificationData.isNotEmpty) {
    final receipt = purchaseDetails.verificationData.serverVerificationData;

    // Send receipt to the backend for validation
    final success = await _sendReceiptToBackend(receipt, token);

    if (success) {
      if (mounted) {
        
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

bool _isCelebrationActive = false;

void _showCelebrationWidget(BuildContext context) {
  if (_isCelebrationActive) return; // Avoid showing multiple celebrations
  _isCelebrationActive = true;

  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Celebration2Dialog(
        onDismiss: () {
          _isCelebrationActive = false;
          Navigator.of(context).pop(); // Close the dialog
        },
      );
    },
  );
}

Future<bool> _sendReceiptToBackend(String receipt, String token) async {
   // Retrieve user’s authentication token

  final response = await http.post(
    Uri.parse('https://www.hearme.services/validate_receipt/'),
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


  void _buyCredits(String productId,BuildContext context) async {

  final bool available = await InAppPurchase.instance.isAvailable();
  if (!available) {
     if (mounted) {
     
    _showSnackBar(context, 'In-App Purchases are not available.');
     }
    return;
  }
  // Define product identifiers

  const Set<String> productIds = {'credit1', 'credit2', 'credit3','Bronze', 'Silver', 'Gold', 'Diamond'};
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
@override
Widget build(BuildContext context) {
  return AnimatedContainer(
    duration: const Duration(seconds: 1),
    curve: Curves.easeInOut,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Colors.orangeAccent, Color.fromARGB(255, 151, 64, 251)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12),
      boxShadow:const[
         BoxShadow(
          color: Colors.black26,
          blurRadius: 8,
          offset:  Offset(0, 4),
        ),
      ],
    ),
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Need Credits?",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Image.asset(
          'assets/images/credits.png',
          height: 80,
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 23),
        // Button for Buying Credits
        Stack(
          alignment: Alignment.center,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _handleTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shadowColor: Colors.black45,
                elevation: 5,
              ),
              child: _isLoading
                  ? const SizedBox(
                        
                      height: 20,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                      ),
                    )
                  : const Row(
                     mainAxisSize: MainAxisSize.min,
                      children:  [
                        
                        Icon(Icons.credit_card, size: 18, color: Colors.black),
                        SizedBox(width: 5),
                        Text(
                          "Credits",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
            Positioned(
              left: 96.8,
              child: GestureDetector(
                onTap: () => _showInfoDialog(
                  context,
                  "",
                  "Tap the button for a one time credit refill. Credits purchased here can be used for translate & talk. *This is not a subscription and is one time purchase of credits*",
                ),
                child: const Icon(
                  Icons.info_outline,
                  size: 13,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Button for Subscriptions
        Stack(
          alignment: Alignment.centerRight,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : () => _showSubscriptionOptions(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shadowColor: Colors.black45,
                elevation: 5,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Color.fromARGB(255, 62, 130, 246)),
                      ),
                    )
                  : const Row(
                    mainAxisSize: MainAxisSize.min,
                      children:  [
     
                   
                        Text(
                          "Subscriptions",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
            Positioned(
              left: 117,
              child: GestureDetector(
                onTap: () => _showInfoDialog(
                  context,
                  "",
                  "Click for a subscription; It will last one month from purchase, non-recurring, purchase again once gone if needed. You will receive an increase in daily credit refill amount, priority queueing, and make your credit refill grant talk type credits. Use the chart at the bottom of the page.",
                ),
                child: const Icon(
                  Icons.info_outline,
                  size: 13,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Okay"),
            ),
          ],
        );
      },
    );
  }
}
class WhoIsBuddyWidget extends StatelessWidget {
  const WhoIsBuddyWidget({super.key});


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isLandscape = constraints.maxWidth > constraints.maxHeight;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.blueAccent, Colors.lightBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow:const  [
               BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset:  Offset(0, 4),
              ),
            ],
          ),
          child: Flex(
            direction: isLandscape ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Buddy Avatar
              const CircleAvatar(
                radius: 35,
                backgroundImage: AssetImage('assets/images/buddy-icon.png'),
              ),
              const SizedBox(height: 10, width: 16),

              // Description Section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Who is 'Buddy'?",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Explanation of Buddy
                    const Text(
                      "Buddy is a personalized conversational assistant. Buddy is smart and has a lot of tools at its disposal to effectively help handle the world around you.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Learn More Button
                    ElevatedButton(
                      onPressed: () => _showDialog(context), // Updated function call
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        "Learn More",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Function to show dialog alert
  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "What can buddy do?",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text(
            "Buddy can change how you interact. Buddy will listen and speak for you. We'll give Buddy an objective and a persona; Try giving Buddy your own identity as its persona. Then Buddy can automatically converse with the conversees around. *Buddy will find information by choosing to ask you a question, searching your knowledge base, and more.",
            textAlign: TextAlign.justify,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Okay"),
            ),
          ],
        );
      },
    );
  }
}

class WhoIsBuddy2Widget extends StatefulWidget {

  const WhoIsBuddy2Widget({super.key});


  @override
  State<WhoIsBuddy2Widget> createState() => _WhoIsBuddy2WidgetState();
}

class _WhoIsBuddy2WidgetState extends State<WhoIsBuddy2Widget> {
  Widget _buildComparisonChart(BoxConstraints constraints) {
    double availableWidth = constraints.maxWidth;

    // Scaling factors
    double fontSize = availableWidth * 0.038; // Scaled font size
    double iconSize = availableWidth * 0.07; // Scaled icon size
    double cellPadding = 1; // Scaled padding for cells

    return SingleChildScrollView(
      child: Container(
     margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: EdgeInsets.all(cellPadding),
        
        decoration: const BoxDecoration(
          color: Colors.white,
         
          boxShadow:  [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
               const Text(
          "How it works.",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
   const SizedBox(height: 20),
            // Vertical Table 1
            _buildVerticalTable(
              '',
              ['', 'Transcribe', 'Speech', 'Autonomous'],
              [
                _buildFeatureRow('Transcribe', [true, false, false], fontSize, iconSize),
                _buildFeatureRow('Manual', [ true, true, false], fontSize, iconSize),
                _buildFeatureRow('Buddy', [true, true, true], fontSize, iconSize),
              ],
            ),
   const SizedBox(height: 16),
            SizedBox(height: cellPadding),

            // Vertical Table 2
            _buildVerticalTable(
              '',
              ['','Free', 'Bronze', 'Silver', 'Gold', 'Diamond'],
              [
                    _buildFeatureRow('All Modes', [true, true, true, true, true], fontSize, iconSize),
                        _buildFeatureRow('Real Time', [true, true, true, true, true], fontSize, iconSize),
                   
                _buildSubscriptionRow('Queue Priority', ['5', '4', '3', '2', '1'], fontSize),
                _buildSubscriptionRow('Daily Credits', ['200', '500', '1250', '3k', '5K'], fontSize),
                
              ],
            ),
          ],
        ),
      ),
    );
  }

Widget _buildVerticalTable(String title, List<String> headers, List<Widget> rows) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (title.isNotEmpty) ...[
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      ],
      const Divider(color: Colors.black12, thickness: 1),
      Row(
        children: headers.asMap().entries.map((entry) {
          int index = entry.key;
          String header = entry.value;

          // Check for "/" in the first header and split
          if (index == 0 && header.contains('/')) {
            final parts = header.split('/');
            return Expanded(
              child: Column(
                children: parts.map((part) {
                  return Text(
                    part,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 8,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  );
                }).toList(),
              ),
            );
          }

          // Normal header rendering for other headers
          return Expanded(
            child: Text(
              header,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: index == 0 ? 7 : 6.5, // Conditional font size
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              softWrap: false, // Prevent wrapping
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
      ),
      const Divider(color: Colors.black12, thickness: 1),
      ...rows,
    ],
  );
}

Widget _buildFeatureRow(String mode, List<bool> features, double fontSize, double iconSize) {
  final words = mode.split(' ');
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      children: [
        Expanded(
          flex: 1,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: words.isNotEmpty ? words[0] : '',
                  style: TextStyle(fontSize: fontSize, color: Colors.black87),
                ),
                if (words.length > 1)
                  TextSpan(
                    text: '\n${words.sublist(1).join(' ')}',
                    style: TextStyle(fontSize: fontSize, color: Colors.black87),
                  ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        ...features.map((available) => Expanded(
              child: Center(
                child: Icon(
                  available ? Icons.check_circle : Icons.cancel,
                  color: available ? Colors.green : Colors.red,
                  size: iconSize,
                ),
              ),
            )),
      ],
    ),
  );
}

Widget _buildSubscriptionRow(String feature, List<String> values, double fontSize) {
  final words = feature.split(' ');
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      children: [
        Expanded(
          flex: 1,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: words.isNotEmpty ? words[0] : '',
                  style: TextStyle(fontSize: fontSize, color: Colors.black87),
                ),
                if (words.length > 1)
                  TextSpan(
                    text: '\n${words.sublist(1).join(' ')}',
                    style: TextStyle(fontSize: fontSize, color: Colors.black87),
                    
                  ),
                  
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        ...values.map((value) => Expanded(
              child: Center(
                child: Text(
                  value,
                  style: TextStyle(fontSize: fontSize, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                
              ),
            )),
      ],
    ),
  );
}


  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return  _buildComparisonChart(constraints);
         
      },
    );
  }
}

class LanguageWidget extends StatefulWidget {
  final String jwtToken;

  const LanguageWidget({super.key, required this.jwtToken});
@override
LanguageWidgetState createState() => LanguageWidgetState();

}

class LanguageWidgetState extends State<LanguageWidget> {
  final Map<String, String> supportedLanguages = {
    "en": "English",
    "es": "Spanish",
    "fr": "French",
    "zh": "Chinese",
    "ar": "Arabic",
  };

  String? _currentLanguage;
  String? _targetLanguage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentLangResponse = await _getLanguage('/getlang');
      final targetLangResponse = await _getLanguage('/gettargetlang');

      setState(() {
        _currentLanguage = currentLangResponse;
        _targetLanguage = targetLangResponse;
      });
    } catch (e) {
      debugPrint("Error loading languages: $e");
           if (mounted) {
      _showSnackBar(context, "Failed to load languages.");
           }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<String> _getLanguage(String endpoint) async {
    final response = await http.post(
      Uri.parse('https://www.hearme.services$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.jwtToken}',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['language'] ?? "en"; // Default to English
    } else {
      throw Exception("Failed to fetch language");
    }
  }

  Future<void> _setLanguage(String endpoint, String languageKey) async {
    final response = await http.post(
      Uri.parse('https://www.hearme.services$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.jwtToken}',
      },
      body: jsonEncode({'language': languageKey}),
    );

    if (response.statusCode == 200) {
      
    } else {
      throw Exception("Failed to update language");
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _updateCurrentLanguage(String languageKey) async {
    try {
      await _setLanguage('/setlang', languageKey);
      setState(() {
        _currentLanguage = languageKey;
      });
    } catch (e) {
      debugPrint("Error updating current language: $e");
           if (mounted) {
      _showSnackBar(context, "Failed to update language.");
           }
    }
  }

  void _updateTargetLanguage(String languageKey) async {
    try {
      await _setLanguage('/settargetlang', languageKey);
      setState(() {
        _targetLanguage = languageKey;
      });
    } catch (e) {
      debugPrint("Error updating target language: $e");
           if (mounted) {
      _showSnackBar(context, "Failed to update target language.");
           }
    }
  }

  void _showInfoDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Okay"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Center(
            child: Card(
              elevation: 5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "Language",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: "Transcribe",
                      value: _currentLanguage,
                      onChanged: (value) {
                        if (value != null) _updateCurrentLanguage(value);
                      },
                      infoMessage: "The language transcription is looking for; Setting transcription language will increase accuracy but it is not required.",
                    ),
                    const SizedBox(height: 16),
                    _buildSection(
                      title: "Talk",
                      value: _targetLanguage,
                      onChanged: (value) {
                        if (value != null) _updateTargetLanguage(value);
                      },
                      infoMessage:
                          "The language speech will be spoken in; English if unset.",
                    ),
                  ],
                ),
              ),
            ),
          );
  }

  Widget _buildSection({
    required String title,
    required String? value,
    required ValueChanged<String?> onChanged,
    required String infoMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showInfoDialog(context, title, infoMessage),
              child:  Icon(
                Icons.info_outline,
                size: 14,
                color:  Colors.grey[250],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded: true,
          hint: const Text("Select a language"),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: onChanged,
          items: supportedLanguages.entries
              .map(
                (entry) => DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value ,  style: const TextStyle(fontSize: 12),),
               
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}