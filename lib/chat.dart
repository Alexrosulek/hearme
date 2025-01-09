// ignore_for_file: empty_catches

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:collection';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'audio_visualizer.dart';
import 'home.dart';
const int kBlockSize = 131072; // 128 KB


const int kSampleRate = 24000; // Start with 20 KB

enum ChatMode { off, translation, gptAudio, talkManual }

class ChatModule extends StatefulWidget {
  final String title;
  final VoidCallback onNavigateToLogin; // callback type
  const ChatModule({super.key, required this.title,   required this.onNavigateToLogin,});



  @override
  ChatModuleState createState() => ChatModuleState();
}

class ChatModuleState extends State<ChatModule> {
  final RecorderController _recorderController = RecorderController();


  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
 
  final FlutterSoundPlayer _soundPlayer = FlutterSoundPlayer();
  bool _isTimedObjective = false;
  final Uuid _uuid = const Uuid();
  WebSocketChannel? _activeSocket; // State to manage the sticky button press
  int _reconnectAttempts = 0;
  final Queue<Uint8List> _audioBufferQueue = Queue<Uint8List>(); // Queue to hold audio chunks
  bool _isFeedingAudio = false; // Flag to prevent concurrent playback
  final int _maxReconnectAttempts = 3;
  bool _isRecorderInitialized = false;
  FlutterSoundRecorder? _audioRecorder;
  Timer? _pollingTimer;
  final TextEditingController _responseController = TextEditingController(); // Controller for the second input
Timer? _resumeListenerTimer; // Timer to handle delayed resumption
  ChatMode _currentMode = ChatMode.off;
  bool _isListening = false; // Toggle for audio streaming
  final List<Map<String, String>> _messages = [];
  bool _isLoading = true;
bool _isListeningPaused = false; // Pauses listening when playing audio or modal
bool _isPlayingAudio = false;    // Indicates if an audio chunk is currently playing
bool _isSwitchingRoutes = false;
bool _isSending = false;
  bool _isInQueue = false;
  String _connectionStatus = "disconnected";
  String? _jwtToken;
  String _roomName = "";

  bool _stickyButtonPressed = false; 
  
@override
void initState() {
  super.initState();
  _initialize();
    _initAudioRecorder();
}
@override
void dispose() {
  _stopAudioStreaming(); // Stop streaming

  _activeSocket?.sink.close(); // Close WebSocket
  _recorderController.dispose(); // Dispose recorder
  _audioRecorder?.closeRecorder(); // Close audio recorder
  _soundPlayer.closePlayer(); // Close sound player
  _resumeListenerTimer?.cancel(); // Cancel any timers

  _stopPollingForOffState();

  super.dispose();
}



Future<void> _initSoundPlayer() async {
  if (!_soundPlayer.isOpen()) {
    await _soundPlayer.openPlayer();
  }
}

  Future<void> _initialize() async {
    if (mounted) {

    setState(() => _isLoading = true);
        // Update your state here
 
}
    _jwtToken = await _getToken();
    _jwtToken ??= '';

    _roomName = _generateRoomName();
    
    if (_currentMode != ChatMode.off && _activeSocket == null) await _connectToPool();
      if (mounted) {
    setState(() => _isLoading = false);

}
    _initAudioRecorder();
  }
  
void _startAudioStreaming() async {
  if (!_isRecorderInitialized || _activeSocket == null || _currentMode == ChatMode.off ) return;
  try {

     await _recorderController.record(); // Fix: Start recording visualization

    StreamController<Food> controller = StreamController<Food>();
    controller.stream.listen((data) {
      if (data is FoodData) {
        final base64Audio = base64Encode(data.data!);
        _activeSocket?.sink.add(jsonEncode({'type': 'audio', 'audio': base64Audio}));
      }
    });

    await _audioRecorder!.startRecorder(
      toStream: controller.sink,
      codec: Codec.pcm16,
      sampleRate: 24000,
      numChannels: 1,
    );
      if (mounted) {
    setState(() => _isListening = true);
      }
  } catch (e) {
  }
}



void _stopAudioStreaming() async {
  try {
    await _recorderController.stop(); // Stop recording visualization
    await _audioRecorder?.stopRecorder();
  if (mounted) {
    setState(() {
      _isListening = false;
    });
  }
  } catch (e) {
  }
}


  String _generateRoomName() => _uuid.v4();

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  

  Future<void> _connectToPool() async {
      if ( _currentMode == ChatMode.off || _activeSocket != null) {
    return;
  }

    final route = _currentMode == ChatMode.gptAudio
    ? 'gpt-audio'
    : _currentMode == ChatMode.talkManual
        ? 'duo'
        : 'translate';

    final wsUrl = "wss://www.hearme.services/wss/pool/$route/$_roomName/$_jwtToken/en/";
    _connectWebSocket(wsUrl);
  }
void _connectWebSocket(String url) {
 

   _activeSocket= WebSocketChannel.connect(Uri.parse(url));

  _activeSocket?.stream.listen(
    (message) => _handleWebSocketMessage(jsonDecode(message)),
    onError: (error) {
      if (!_isSwitchingRoutes) _handleReconnect(); // Ignore errors during route switching
    },
    onDone: () {
      
    },
    cancelOnError: true,
  );
}


void _handleModeChange(ChatMode mode) async {

   if (mode != ChatMode.off) {
    // Ensure no reconnections
    _stopPollingForOffState();
   
  }
   if (mode == ChatMode.off) {
  _startPollingForOffState();
   }
  // Perform cleanup
    _stopAudioStreaming();
    await _soundPlayer.stopPlayer();
    _activeSocket?.sink.close();
        _activeSocket = null;
    _audioBufferQueue.clear();

  
  
  if (mounted) {
  setState(() {
    _isTimedObjective == false;
    _currentMode = mode;
    _messages.clear();
        _isListeningPaused = false;
   
    _stickyButtonPressed = false;
     _isListening = false;
    _isFeedingAudio = false;
    _isPlayingAudio = false;
    
    _connectionStatus = "disconnected";
    _isInQueue = false;
    _reconnectAttempts = 0;
  });
  }
    // If switching to off, do not reconnect
  if (mode == ChatMode.off) {
     if (mounted) {
  setState(() {
    _reconnectAttempts = 20;
  });
     }
    // Make absolutely sure no reconnects are triggered
    return;
  }

  if (_jwtToken == '' || _jwtToken == null){
    _handleModeChange(ChatMode.off);
_showErrorPopup("Please login to use this feature.");

  }

  // Re-initialize WebSocket for active modes
  if (mode == ChatMode.translation || mode == ChatMode.gptAudio || mode == ChatMode.talkManual) {
    await _initialize();
  }
}


  void _handleWebSocketMessage(Map<String, dynamic> message) {
    switch (message['type']) {
      case 'queue':
        if (mounted) {
        setState(() {
          _isInQueue = true;
          _connectionStatus = "pool";
        });
        }
        break;
      case 'route':

        _handleRouting(message['consumer']);
        
        break;
      case 'connected':
        if (mounted) {
   setState(() {
          _connectionStatus = "connected";
          _isInQueue = false;
        });
        }
        break;
      case 'reconnect':
        _handleReconnectToPool();
        break;
      case 'transcript':
        _addMessage(message['role'], message['transcript']);
        break;
      case 'audio':
      _playPCMBase64Audio(message['audio']);
      break;
      case 'error':

        _addMessage('assistant', message['message']);
        _showErrorPopup(message['message']);
        _handleModeChange(ChatMode.off);
          if (mounted) {
        setState(() {
          _connectionStatus = "disconnected";
          _isInQueue = false;
        });
          }
        break;
      case 'ask_question':
        _handleAskQuestion(message['question']);
        break;
     case 'getobjective': 
  bool isTimed = message['extra']?['timed'] == true;
  _handleGetObjective(isTimed: isTimed);
  break;



      default:
    }
  }
void _handleGetObjective({bool isTimed = false}) async {
  setState(() => _isTimedObjective = true);

  final TextEditingController objectiveController = TextEditingController();
  final TextEditingController buddyGoalController = TextEditingController();

  final TextEditingController buddyGoal2Controller = TextEditingController();

  bool disconnected = false;
  int timeLeft = 25; // Timeout duration
  Timer? countdownTimer;
  String? errorMessageObjective;
  String? errorMessageBuddyGoal;

  String? errorMessageBuddyGoal2;
  // Start a timer if the input is timed
  if (isTimed) {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          timeLeft--;
        });
      }
      if (timeLeft == 0) {
        timer.cancel();
        Navigator.of(context, rootNavigator: true).pop(); // Close dialog
      }
    });
  }

  // Show a popup dialog for input
  await showDialog(
    context: context,
    barrierDismissible: true, // Allow dismissal by clicking outside
    builder: (_) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text("What’s the objective?"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isTimed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SizedBox(
                      height: 50,
                      width: 50,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CircularProgressIndicator(
                            value: timeLeft / 25,
                            strokeWidth: 6,
                            color: Colors.blueAccent,
                            backgroundColor: Colors.grey.shade300,
                          ),
                          Center(
                            child: Text(
                              "$timeLeft",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Main Objective Input
                TextFormField(
                  controller: objectiveController,
                  maxLines: 5, // Make the text box larger
                  maxLength: 200, // Limit input size
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        errorMessageObjective = "This field cannot be empty.";
                      } else if (value.length > 200) {
                        errorMessageObjective = "Input exceeds 200 characters.";
                      } else {
                        errorMessageObjective = null;
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Whats your goal?. Ex: 'I need help ordering food...'.",
                    border: const OutlineInputBorder(),
                    errorText: errorMessageObjective, // Show error dynamically
                  ),
                ),
                const SizedBox(height: 16),
                // Buddy's Goal Input
                TextFormField(
                  controller: buddyGoalController,
                  maxLines: 3,
                  maxLength: 150,
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        errorMessageBuddyGoal = "This field cannot be empty.";
                      } else if (value.length > 150) {
                        errorMessageBuddyGoal = "Input exceeds 150 characters.";
                      } else {
                        errorMessageBuddyGoal = null;
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Describe buddy's goal. Ex: 'Talk to the person at the counter to take my order...'.",
                    border: const OutlineInputBorder(),
                    errorText: errorMessageBuddyGoal,
                  ),
                ),
                 TextFormField(
                  controller: buddyGoal2Controller,
                  maxLines: 3,
                  maxLength: 150,
                  onChanged: (value) {
                    setState(() {
                      if (value.isEmpty) {
                        errorMessageBuddyGoal2 = "This field cannot be empty.";
                      } else if (value.length > 150) {
                        errorMessageBuddyGoal2 = "Input exceeds 150 characters.";
                      } else {
                        errorMessageBuddyGoal2 = null;
                      }
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Describe where you are. Ex: 'I'm in front of the counter and restraunt employee ...'.",
                    border: const OutlineInputBorder(),
                    errorText: errorMessageBuddyGoal2,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                disconnected = true;
                if (countdownTimer != null) countdownTimer.cancel();
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Leave"),
            ),
            TextButton(
              onPressed: () {
                if (countdownTimer != null) countdownTimer.cancel();
                if (objectiveController.text.isEmpty) {
                  setState(() {
                    errorMessageObjective = "This field cannot be empty.";
                  });
                  return;
                }
                if (buddyGoalController.text.isEmpty) {
                  setState(() {
                    errorMessageBuddyGoal = "This field cannot be empty.";
                  });
                  return;
                }
                 if (buddyGoal2Controller.text.isEmpty) {
                  setState(() {
                    errorMessageBuddyGoal = "This field cannot be empty.";
                  });
                  return;
                }
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Join"),
            ),
          ],
        );
      },
    ),
  ).then((_) {
    setState(() => _isTimedObjective = false);

    // Handle dismissal without valid input
    if (!disconnected &&
        (objectiveController.text.isEmpty ||
            buddyGoalController.text.isEmpty || buddyGoal2Controller.text.isEmpty ||
            errorMessageObjective != null ||
            errorMessageBuddyGoal != null || errorMessageBuddyGoal2 != null)) {
      _handleModeChange(ChatMode.off);
    } else if (objectiveController.text.isNotEmpty &&
        buddyGoalController.text.isNotEmpty && buddyGoal2Controller.text.isNotEmpty &&
        errorMessageObjective == null &&
        errorMessageBuddyGoal == null && errorMessageBuddyGoal2 == null) {
      // Send combined input
      _activeSocket?.sink.add(jsonEncode({
        'type': 'objective',
        'prompt': "OWNER objective: ${objectiveController.text}, ASSISTANT Goal: ${buddyGoalController.text}, WORLD location: ",
      }));
    }
  });

  // Cancel the timer if it is still running
  countdownTimer?.cancel();

  setState(() => _isTimedObjective = false);
  // Handle the transition to the `off` state if disconnected
  if (disconnected) {
    _handleModeChange(ChatMode.off);
  }
}

 void _handleRouting(String consumerPath) {

  // Mark that this is an intentional route switch
  _isSwitchingRoutes = true;

 
  // Delay the connection slightly to allow clean closure
  Future.delayed(const Duration(milliseconds: 300), () {
    _connectWebSocket(consumerPath);
    _isSwitchingRoutes = false; // Reset the flag after switching
  });

}Future<void> _playPCMBase64Audio(String base64Audio) async {
  try {
    await _initSoundPlayer();

    final Uint8List pcmBytes = base64Decode(base64Audio);

    // Pause streaming while playing
    if (_isListening) {
      _stopAudioStreaming();
      _isListeningPaused = true;
    }

    // Add PCM data to the queue
    _audioBufferQueue.add(pcmBytes);

    // Set playback state
    if (!_isPlayingAudio) {
      _isPlayingAudio = true;
      await _feedAudioBuffer();
    }

    // Wait until playback finishes
    while (_isPlayingAudio) {
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Restart streaming if paused
    if (_isListeningPaused) {
      _isListeningPaused = false;
      _startAudioStreaming();
    }
  } catch (e) {
   
  }
}

Future<void> _feedAudioBuffer() async {
  if (_isFeedingAudio) return; // Prevent concurrent feeding
  _isFeedingAudio = true;

  try {
    // Start player stream if not already started
    if (!_soundPlayer.isPlaying) {
      await _soundPlayer.startPlayerFromStream(
        codec: Codec.pcm16,
        sampleRate: kSampleRate,
        whenFinished: () {
          // Handle playback finish
          if (_audioBufferQueue.isNotEmpty) {
            _feedAudioBuffer(); // Continue processing
          } else {
            _isPlayingAudio = false; // Stop playback state
          }
        },
      );
    }

    // Feed PCM audio chunks to the player
    while (_audioBufferQueue.isNotEmpty) {
      final Uint8List audioChunk = _audioBufferQueue.removeFirst();
      int offset = 0;

      // Feed chunks of audio data to the player
      while (offset < audioChunk.length) {
        final int size = (audioChunk.length - offset > kBlockSize)
            ? kBlockSize
            : audioChunk.length - offset;
        await _soundPlayer.feedFromStream(audioChunk.sublist(offset, offset + size));
        offset += size;
      }
    }
  } catch (e) {
  } finally {
    _isFeedingAudio = false; // Ensure feeding state is reset
  }
}


Future<void> _initAudioRecorder() async {

  if (_audioRecorder != null || _isRecorderInitialized) return;
  _audioRecorder = FlutterSoundRecorder();
  await _audioRecorder!.openRecorder();
  _audioRecorder!.setSubscriptionDuration(const Duration(milliseconds: 50));
  _isRecorderInitialized = true;
}


  void _handleReconnectToPool() {
    
    _activeSocket?.sink.close();
    _activeSocket = null;
    _reconnectAttempts = 0;
  if (_currentMode == ChatMode.off) return;
    _connectToPool();
  }Future<void> _handleAskQuestion(String question) async {

  setState(() => _isTimedObjective = true);
  bool skipped = false;
  String userInput = "";
  int timeLeft = 25; // Timeout in seconds
  Timer? countdownTimer;

  // Pause listening only if it was active
  if (_isListening) {
    _stopAudioStreaming();
    _isListeningPaused = true;
  }

  // Show dialog with countdown
  await showDialog(
    context: context,
    barrierDismissible: true, // Allow dismissal by clicking outside
    builder: (_) => StatefulBuilder(
     builder: (context, setState) {
  // Start countdown timer if not already started
  countdownTimer ??= Timer.periodic(const Duration(seconds: 1), (timer) {
    if (timeLeft > 0) {
      setState(() {
        timeLeft--;
      });
    } else {
      timer.cancel();
      Navigator.of(context, rootNavigator: true).pop(); // Close modal
    }
  });

        return AlertDialog(
          title: const Text("Question"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(question),
              const SizedBox(height: 8),
              SizedBox(
                height: 50,
                width: 50,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: timeLeft / 20, // Adjust for countdown range
                      strokeWidth: 6,
                      color: Colors.blueAccent,
                      backgroundColor: Colors.grey.shade300,
                    ),
                    Center(
                      child: Text(
                        "$timeLeft", // Display countdown
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (value) => userInput = value,
                decoration: const InputDecoration(
                  hintText: "Type your response...",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                skipped = true;
                countdownTimer?.cancel();
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Skip"),
            ),
            TextButton(
              onPressed: () {
                countdownTimer?.cancel();
                Navigator.of(context).pop(); // Close the dialog
              },
              child: const Text("Send"),
            ),
          ],
        );
      },
    ),
  ).then((_) {

  setState(() => _isTimedObjective = false);
    // Send skip response if dismissed without input
    if (!skipped && userInput.isEmpty) {
      _activeSocket?.sink.add(jsonEncode({'type': 'skip'}));
    }
  });

  // Ensure timer is canceled
  countdownTimer?.cancel();

  // Resume listening only if it was paused earlier
  if (_isListeningPaused && !_isPlayingAudio) {
    _isListeningPaused = false;
    _startAudioStreaming();
  }

  setState(() => _isTimedObjective = false);
  // Send user response if provided
  if (!skipped && userInput.isNotEmpty) {
    _activeSocket?.sink.add(jsonEncode({'type': 'question_response', 'content': userInput}));
  }
}



  

void _handleReconnect() {
    if (_currentMode == ChatMode.off) return;
  if (_isSwitchingRoutes) return;

  if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (mounted) {
    setState(() {
      _connectionStatus = "disconnected";
      _isInQueue = false;
    });
      }
    return;
  }

  int delaySeconds = 2 * (1 << _reconnectAttempts); // 2, 4, 8...
  _reconnectAttempts++;

  Future.delayed(Duration(seconds: delaySeconds), () {
    _connectToPool();
    _reconnectAttempts = 0; // Reset if successful
  });
}




void _addMessage(String role, String content, {String? reaction}) {
  if (content.trim().isEmpty) {
    // If content is empty or only whitespace, do not add the message
    return;
  }

  setState(() {
    bool messageUpdated = false;

    if (reaction != null) {
      for (var message in _messages.reversed) {
        if (message['content'] == content && message['role'] == role) {
          message['reaction'] = reaction;
          message['reactionSent'] = 'true';
          messageUpdated = true;
          break;
        }
      }
    }

    if (!messageUpdated) {
      _messages.add({
        'role': role,
        'content': content,
        'reaction': reaction ?? '',
        'reactionSent': 'false', // Default to false
      });
    }
  });
}




void _toggleStickyButton() {
  
  setState(() {
    _stickyButtonPressed = !_stickyButtonPressed;

    if (_stickyButtonPressed) {
      // Start listening
      _startAudioStreaming();
    } else {
      // Stop listening and send "notlistening" message
      _stopAudioStreaming();

        _activeSocket?.sink.add(jsonEncode({'type': 'notlistening'}));
      
    }
  });
}



  void _showErrorPopup(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
       
        content: Text(message),
        actions: [TextButton(onPressed: Navigator.of(context).pop, child: const Text("Okay"))],
      ),
    );
  }

  void _sendMessage() {
     if (_isSending) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

  setState(() => _isSending = true);

    _addMessage('owner', text);
    
    _activeSocket?.sink.add(jsonEncode({'type': 'text', 'prompt': text, 'role': 'system'}));
    
    _inputController.clear();
    
    setState(() => _isSending = false);
  }Widget _buildReactionOptions(String messageContent, String role, String? reactionSent, String? selectedReaction) {
  if (reactionSent == 'true' && selectedReaction != null) {
    // Show only the selected emoji in gray
    return Row(
      mainAxisAlignment: role == 'user' ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            selectedReaction,
            style: const TextStyle(fontSize: 20, color: Colors.grey), // Grayed-out emoji
          ),
        ),
      ],
    );
  }

  // Show emoji options if no reaction has been sent
  final emojiMap = {'angry': '😡', 'sad': '😢', 'excited': '🤩'};
  return Row(
    mainAxisAlignment: role == 'user' ? MainAxisAlignment.end : MainAxisAlignment.start,
    children: emojiMap.entries.map((entry) {
      return GestureDetector(
        onTap: () => _sendReaction(entry.key, messageContent, role),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            entry.value,
            style: const TextStyle(fontSize: 20),
          ),
        ),
      );
    }).toList(),
  );
}



Widget _buildUserMessage(String content, {String? reaction, String? reactionSent}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.end, // Aligns content to the left
    children: [
      if (_currentMode != ChatMode.translation) // Exclude "User" label in translation mode
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Text(
            "World",
            style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
          ),
        ),
      Container(
        
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        padding: const EdgeInsets.all(14.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: const BoxDecoration(
          color:  Colors.lightBlue,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(content, style: const TextStyle(color: Colors.black87, fontSize: 15)),
      ),
      if (_currentMode == ChatMode.gptAudio) // Emojis only for GPT-Audio
        _buildReactionOptions(content, 'user', reactionSent, reaction),
    ],
  );
}
Widget _buildAssistantMessage(String content, {String? reaction, String? reactionSent}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start, // Aligns content to the left
    
    children: [
      Padding(
  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
  child: Text(
    _currentMode == ChatMode.gptAudio ? "Buddy" : "User",
    style: TextStyle(
      color: Colors.grey[600],
      fontSize: 12,
      fontStyle: FontStyle.italic,
    ),
  ),
),

      Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        padding: const EdgeInsets.all(14.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(content, style: const TextStyle(color: Colors.black87, fontSize: 15)),
      ),
      if (_currentMode == ChatMode.gptAudio) // Emojis only for GPT-Audio
        _buildReactionOptions(content, 'assistant', reactionSent, reaction),
    ],
  );
}

Widget _buildOwnerMessage(String content, {String? reaction, String? reactionSent}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start, // Aligns content to the left
    
    children: [
       Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
        child: Text(
        "User",
          style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
        ),
      ),
      Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 12.0),
        padding: const EdgeInsets.all(14.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(content, style: const TextStyle(color: Colors.black87, fontSize: 15)),
      ),
      
    ],
  );
}



void _sendReaction(String emotion, String message, String role) {
  final emojiMap = {'angry': '😡', 'sad': '😢', 'excited': '🤩'};
  final emoji = emojiMap[emotion] ?? '🙂';
  if (mounted) {
  setState(() {
    final index = _messages.indexWhere((msg) => msg['content'] == message && msg['role'] == role);
    if (index != -1) {
      _messages[index]['reaction'] = emoji; // Save selected emoji
      _messages[index]['reactionSent'] = 'true'; // Mark reaction as sent
    }
  });
  }
  _activeSocket?.sink.add(jsonEncode({
    'type': 'reaction',
    'prompt': "$emoji $emotion about \"$message\"",
    'role': 'system'
  }));
}



  void _sendResponse() {
    final text = _responseController.text.trim();
    if (text.isEmpty) return;

    _activeSocket?.sink.add(jsonEncode({
      'type': 'issue_response',
      'prompt': text,
    }));

    _responseController.clear(); // Clear the input after sending
  }
Future<void> _startPollingForOffState() async {
  int elapsedMilliseconds = 0;

  // Create a periodic timer for rapid polling
  _pollingTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) async {
    elapsedMilliseconds += 500;

    // If the mode is not "off," stop the timer
    if (_currentMode != ChatMode.off) {
      _stopPollingForOffState();
      return;
    }

    // If the mode is "off," perform cleanup operations
    if (_currentMode == ChatMode.off) {
      _stopAudioStreaming();
      await _soundPlayer.stopPlayer();
      _activeSocket?.sink.close();
      _activeSocket = null;
      _audioBufferQueue.clear();

      if (mounted) {
        setState(() {
          _isTimedObjective = false;
          _currentMode = ChatMode.off;
          _messages.clear();
          _isListeningPaused = false;
          _stickyButtonPressed = false;
          _isListening = false;
          _isFeedingAudio = false;
          _isPlayingAudio = false;
          _connectionStatus = "disconnected";
          _isInQueue = false;
          _reconnectAttempts = 0;
        });
      }
    }

    // Switch to slower polling after 15 seconds
    if (elapsedMilliseconds >= 30000) {
      timer.cancel();
      _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        if (_currentMode != ChatMode.off) {
          _stopPollingForOffState();
          return;
        }

        // Perform cleanup operations again during slower polling
        _stopAudioStreaming();
        await _soundPlayer.stopPlayer();
        _activeSocket?.sink.close();
        _activeSocket = null;
        _audioBufferQueue.clear();

        if (mounted) {
          setState(() {
            _isTimedObjective = false;
            _currentMode = ChatMode.off;
            _messages.clear();
            _isListeningPaused = false;
            _stickyButtonPressed = false;
            _isListening = false;
            _isFeedingAudio = false;
            _isPlayingAudio = false;
            _connectionStatus = "disconnected";
            _isInQueue = false;
            _reconnectAttempts = 0;
          });
        }
      });
    }
  });
}
void _stopPollingForOffState() {
  // Cancel the polling timer
  _pollingTimer?.cancel();
  _pollingTimer = null;
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
    return Scaffold(
      
      appBar: AppBar(
  titleSpacing: 0, // Remove extra spacing for clean alignment
  title: Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
    decoration: BoxDecoration(
      color: Colors.grey[200], // Unified background color
      borderRadius: BorderRadius.circular(12), // Rounded corners
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween, // Align items across the row
      children: [
        // "Off" and "Translate" buttons
        ToggleButtons(
          isSelected: [
            _currentMode == ChatMode.off,
            _currentMode == ChatMode.translation,
          ],
          onPressed: (index) {
            final modes = [ChatMode.off, ChatMode.translation];
            _handleModeChange(modes[index]);
          },
          borderRadius: BorderRadius.circular(12), // Rounded corners
          color: Colors.black87, // Unselected text color
          selectedColor: Colors.white, // Text color when selected
          fillColor: Colors.blueAccent, // Blue fill for selected buttons
          constraints: const BoxConstraints(minWidth: 60, minHeight: 40), // Button size
          renderBorder: false, // Removes borders
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.0),
              child: Text("Off",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.0),
              child: Text("Transcribe",
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
           
            
          ],
        ),
        const SizedBox(width: 4),
        if (!_isListening)
Icon(
              Icons.circle,
              size: 30,
              color: _connectionStatus == "connected"
                  ? Colors.green
                  : _connectionStatus == "pool"
                      ? Colors.yellow
                      : Colors.red,
            ),
    const Spacer(),
            const SizedBox(width: 2),
   SizedBox(
           
              child: CircularAudioVisualizer(
                recorderController: _recorderController,
                isListening: _isListening,
                isActive: _isPlayingAudio,
              ),
            ),
                const Spacer(),
            const SizedBox(width: 4),
        // Translate & Talk Section
       Container(
  width: 130,
  padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            "Transcribe & Talk",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13, // Smaller font for the main text
              fontWeight: FontWeight.bold,
              color: Colors.black, // Black text for header
            ),
          ),
          const SizedBox(width: 6), // Add some space between text and icon
          GestureDetector(
            behavior: HitTestBehavior.opaque, // Ensure gestures are captured
            onTap: () => _showInfoDialog(
              context,
              "Manual Vs. Buddy",
              "Both transcribe & talk. Both transcribe but one is speech issued by the user, the other autonomous personalized speech and situational handling. Manual: Transcribe and type what you want said in realtime. Buddy: Transcribe and have Buddy autonomously handle the conversation in realtime. Both follow the speech settings. *See Who is 'Buddy'? for more.*",
            ),
            child: const Icon(
              Icons.info_outline,
              size: 14, // Slightly larger for usability
              color: Colors.blueAccent,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4), // Space between title and buttons
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _handleModeChange(ChatMode.talkManual),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                decoration: BoxDecoration(
                  color: _currentMode == ChatMode.talkManual
                      ? Colors.blueAccent
                      : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.blueAccent, width: 1), // Subtle border
                ),
                child: Text(
                  "Manual",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: _currentMode == ChatMode.talkManual
                        ? Colors.white
                        : Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _handleModeChange(ChatMode.gptAudio),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                decoration: BoxDecoration(
                  color: _currentMode == ChatMode.gptAudio
                      ? Colors.blueAccent
                      : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: Colors.blueAccent, width: 1), // Subtle border
                ),
                child: Text(
                  "Buddy",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: _currentMode == ChatMode.gptAudio
                        ? Colors.white
                        : Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
),


        

        // Unified section for Icon and Visualizer
      
      ],
    ),
  ),
),




      body: Stack(
       
  children: [
     
    _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
          
            

       if (_currentMode != ChatMode.off && _isTimedObjective == false) 
          
   
        
                 // Sticky button for audio control
             Padding(
  padding: const EdgeInsets.all(8.0),
  child: ElevatedButton(
    onPressed: (_connectionStatus == "connected")
        ? _toggleStickyButton
        : null, // Disabled if not connected
    style: ElevatedButton.styleFrom(
      backgroundColor: (_connectionStatus == "connected")
          ? (_stickyButtonPressed ? Colors.green : Colors.blueAccent) // Active colors
          : Colors.grey, // Greyed out when disabled
      minimumSize: const Size(double.infinity, 50), // Full-width button
    ),
    child: Text(
      _stickyButtonPressed ? "Stop" : "Listen",
      style: TextStyle(
        color: (_connectionStatus == "connected") ? Colors.white : Colors.black38, // Greyed-out text
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    ),
  ),
),




                 
          if (_isInQueue)
  const Padding(
    padding: EdgeInsets.all(8.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
         Text(
          "Queued ",
          style:  TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
       SizedBox(width: 10),
         SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.blueAccent,
          ),
        ),
      
      ],
    ),
  ),


    Expanded(
  child: ListView.builder(
    reverse: true, // Show latest messages at the bottom
    controller: _scrollController,
    itemCount: _messages.length,
 itemBuilder: (_, index) {
      final msg = _messages[_messages.length - 1 - index];

    
      return msg['role'] == 'user'
      ? _buildUserMessage(
          msg['content'] ?? '',
          reaction: msg['reaction'],
          reactionSent: msg['reactionSent'],
        )
      : msg['role'] == 'assistant'
          ? _buildAssistantMessage(
              msg['content'] ?? '',
              reaction: msg['reaction'],
              reactionSent: msg['reactionSent'],
            )
          : _buildOwnerMessage(
              msg['content'] ?? '',
              reaction: msg['reaction'],
              reactionSent: msg['reactionSent'],
            );
},
  ),


                ),
                if (_currentMode == ChatMode.gptAudio && _connectionStatus == "connected" && _isTimedObjective == false)
  Container(
    padding: const EdgeInsets.all(8.0),
    
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Text Input Field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                 BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset:  Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _inputController,
              style: const TextStyle(fontSize: 16),
              decoration: const InputDecoration(
                hintText: "Tell Buddy...",
                hintStyle: TextStyle(color: Colors.grey),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send Button
        Container(
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: const Icon(Icons.send, color: Colors.white),
            onPressed: _sendMessage,
            tooltip: "Send",
          ),
        ),
      ],
    ),
  ),
 // Second Input Field: "Make me respond ..."
 
   if (_currentMode == ChatMode.gptAudio && _connectionStatus == "connected" && _isTimedObjective == false || _currentMode == ChatMode.talkManual && _connectionStatus == "connected")
   
                Container(
                  margin: const EdgeInsets.only(bottom: 30.0),
                  
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 6,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _responseController,
                            style: const TextStyle(fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: "Speak... ",
                              hintStyle: TextStyle(color: Colors.grey),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendResponse,
                          tooltip: "Send",
                        ),
                      ),
                    ],
                  ),
                ),   // Positioned ProfileModal
  
      ],
    ),
    if (_currentMode == ChatMode.off)
            
                 HomePage(jwt:_jwtToken!,  onNavigateToLogin: widget.onNavigateToLogin) // HomePage is rendered directly
             ]
     ) );
}
  
}
