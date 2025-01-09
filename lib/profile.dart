import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ProfileModal extends StatefulWidget {
  final String jwtToken;

  const ProfileModal({super.key, required this.jwtToken});

  @override
  State<ProfileModal> createState() => _ProfileModalState();
}

class _ProfileModalState extends State<ProfileModal> {
  bool _isLoading = true;
  bool _isSaved = false;

  // A GlobalKey to manage the Form widget’s state
  final _formKey = GlobalKey<FormState>();


  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _specialAdditionController =
      TextEditingController();

  double _age = 25;
  String? _selectedGender;
  String? _selectedVoice;
  String? _accent;
  String? _fastness;
  String? _loudness;
  String? _tone;

  late Map<String, dynamic> _initialValues;

  final List<String> _genders = ['He', 'She'];
  final List<String> _voices = [
    'Alloy',
    'Echo',
    'Shimmer',
    'Ash',
    'Ballad',
    'Coral',
    'Sage',
    'Verse',
  ];
final List<String> _accents = [
  'Neutral',
  'American',
  'British',
 
  'Indian',
  'Irish',
  'Canadian',
  'South African',
  'New Zealander',
  'Scottish',

  'Texan',
  'New Yorker',
 
  'Jamaican',
  'Nigerian',
 
  'Egyptian',
  'Brazilian',
  'Mexican',
  'Spanish',
  
  'Portuguese',
  'French',
  
  'German',
  'Italian',
  'Dutch',
  'Norwegian',
  'Swedish',
  'Danish',
  'Russian',
  'Turkish',
  'Arabic',
 
  'Thai',
  'Vietnamese',
  'Filipino',
  'Indonesian',
  'Chinese',

  'Japanese',
  'Korean',

];

  final List<String> _fastnessOptions = [
    'Very Slow',
    'Slow',
    'Normal',
    'Fast',
    'Very Fast',
  ];
  final List<String> _loudnessOptions = [
    'Very Quiet',
    'Quiet',
    'Normal',
    'Loud',
    'Very Loud',
  ];
  final List<String> _tones = [
    'Neutral',
    'Calm',
    'Serious',
    'Playful',
    'Excited',
    'Happy',
    'Bored',
    'Mad',
    'Charming',
    'Sarcastic',
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  Future<void> _fetchUserInfo() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final url = Uri.parse("https://www.hearme.services/user/info/get");
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.jwtToken}',
          'Content-Type': 'application/json',
        },
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isLoading = false;

          _age = (data['age'] is num && data['age'] >= 1 && data['age'] <= 100)
              ? data['age'].toDouble()
              : 25;
          _nameController.text = (data['new_name'] ?? '').isEmpty ? '' : data['new_name'];

          _specialAdditionController.text = data['specialaddition'] ?? '';
          _selectedGender = _genders.contains(data['gender'])
              ? data['gender']
              : _genders[0];
          _selectedVoice = _voices.contains(data['voice'])
              ? data['voice']
              : _voices[0];
          _accent = _accents.contains(data['accent'])
              ? data['accent']
              : _accents[0];
          _fastness = _fastnessOptions.contains(data['fastness'])
              ? data['fastness']
              : _fastnessOptions[2];
          _loudness = _loudnessOptions.contains(data['loudness'])
              ? data['loudness']
              : _loudnessOptions[2];
          _tone = _tones.contains(data['tone'])
              ? data['tone']
              : _tones[0];

          _backupInitialValues();
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _backupInitialValues() {
    _initialValues = {
      'name': _nameController.text,
      'specialAddition': _specialAdditionController.text,
      'age': _age,
      'gender': _selectedGender,
      'voice': _selectedVoice,
      'accent': _accent,
      'fastness': _fastness,
      'loudness': _loudness,
      'tone': _tone,
    };
  }

  void _restoreInitialValues() {
    if (!mounted) return;
    setState(() {
      _nameController.text = _initialValues['name'];
      _specialAdditionController.text = _initialValues['specialAddition'];
      _age = _initialValues['age'];
      _selectedGender = _initialValues['gender'];
      _selectedVoice = _initialValues['voice'];
      _accent = _initialValues['accent'];
      _fastness = _initialValues['fastness'];
      _loudness = _initialValues['loudness'];
      _tone = _initialValues['tone'];
    });
  }

  Future<void> _saveUserInfo() async {
    // Call FormState.validate(), which runs all validators
    if (!_formKey.currentState!.validate()) {
      return; // If form is invalid, do nothing
    }

    if (mounted) setState(() => _isLoading = true);

    const baseUrl = "https://www.hearme.services/user/info/set";

    final body = <String, dynamic>{
      'name': _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      'age': _age.toInt(),
      'gender': _selectedGender,
      'voice': _selectedVoice,
      'accent': _accent,
      'fastness': _fastness,
      'loudness': _loudness,
      'tone': _tone,
      'specialaddition': _specialAdditionController.text.trim().isEmpty
          ? null
          : _specialAdditionController.text.trim(),
    };

    body.removeWhere((key, value) => value == null);

    try {
      final response = await http.post(
        Uri.parse(baseUrl),
        headers: {
          'Authorization': 'Bearer ${widget.jwtToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
      if (!mounted) return;

      if (response.statusCode == 200) {
        _isSaved = true;
        Navigator.of(context).pop(); // Close the modal
      }
    } catch (e) {
      // Handle any errors
    } finally {
      if (mounted) setState(() => _isLoading = false);
      _fetchUserInfo();
    }
  }

  ///
  /// Info icon helper
  ///
  void _showInfo(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
     
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  ///
  /// Build text form field with immediate validation
  ///
  Widget _buildValidatedTextField({
    required TextEditingController controller,
    required String labelText,
    required String infoText,
    required String? Function(String?) validator,
    int? maxLength,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      autovalidateMode: AutovalidateMode.always, // <= immediate validation
      validator: validator, // Called whenever the user types or the form is saved
      decoration: InputDecoration(
        labelText: labelText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        suffixIcon: IconButton(
          icon: const Icon(Icons.info_outline, size: 16),
          onPressed: () => _showInfo(infoText),
          splashRadius: 16,
        ),
      ),
    );
  }

  ///
  /// Build a Dropdown with a validator
  ///
  Widget _buildValidatedDropdown({
    required String label,
    required String infoMessage,
    required List<String> items,
    required String? value,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return DropdownButtonFormField<String>(
      value: items.contains(value) ? value : items[0],
      onChanged: onChanged,
      autovalidateMode: AutovalidateMode.always,
      validator: validator, // Called on every selection
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      borderRadius: BorderRadius.circular(12.0),
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        suffixIcon: IconButton(
          icon: const Icon(Icons.info_outline, size: 16),
          onPressed: () => _showInfo(infoMessage),
        ),
      ),
    );
  }

  ///
  /// Build the entire profile form
  ///
  Widget _buildProfileForm() {

  final mediaQuery = MediaQuery.of(context);
    return Form(
      key: _formKey, // Connect to our GlobalKey
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        elevation: 4,
        margin: const EdgeInsets.all(16.0),
         child: Container(
          
          constraints: BoxConstraints(
            maxHeight: mediaQuery.size.height * 0.8,
          ),
        child: Padding(
          padding: const EdgeInsets.all(16.0).copyWith(bottom: 24),
          child: SingleChildScrollView(
            
            child: Column(
              
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ///
                /// Row with "Assistant Profile" + (i) icon
                ///
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Text(
                      "Speech Persona",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 18),
                      onPressed: () => _showInfo(
                        "Configure the voice and persona used for speech/persona. For use in 'Manual' and 'Buddy'.",

                        
                      ),
                      splashRadius: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Name Field
                _buildValidatedTextField(
                  controller: _nameController,
                  labelText: "Name",
                  maxLength: 30,
                  infoText: "Enter a name for Buddy with 3-30 characters. E.g., 'Your name'. *Not used in manual mode*",
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) {
                      return "Name cannot be empty.";
                    } else if (text.length < 3) {
                      return "Name must be at least 3 characters.";
                    } else if (text.length > 30) {
                      return "Name cannot exceed 30 characters.";
                    } else if (!RegExp(r"^[A-Za-z0-9 _-]+$")
                        .hasMatch(text)) {
                      return "Only letters, numbers, spaces, underscores, and hyphens.";
                    }
                    return null; // no error
                  },
                ),
                const SizedBox(height: 16),

                // Personality
                _buildValidatedTextField(
                  controller: _specialAdditionController,
                  labelText: "Personality",
                  maxLength: 100,
                  infoText:
                      "How Buddy will engage; e.g. 'Try to make jokes...' or 'You love sports...' *Not used in manual mode*",
                  validator: (value) {
                    // Personality can be optional, so no minimum length check
                    // But let's do an example: max 100 chars
                    final text = value?.trim() ?? '';
                    if (text.length > 100) {
                      return "Max 100 characters allowed.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Age Dropdown
                DropdownButtonFormField<int>(
                  autovalidateMode: AutovalidateMode.always,
                  value: _age.toInt(),
                  decoration: InputDecoration(
                    labelText: "Select Age",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.info_outline, size: 16),
                      splashRadius: 16,
                      onPressed: () => _showInfo(
                        "Choose an age for Buddy. *Not used in manual mode*",
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value < 1 || value > 100) {
                      return "Age must be between 1 and 100.";
                    }
                    return null;
                  },
                  items: List.generate(
                    100,
                    (index) => DropdownMenuItem(
                      value: index + 1,
                      child: Text((index + 1).toString()),
                    ),
                  ),
                  onChanged: (value) {
                    if (mounted) {
                      setState(() => _age = value?.toDouble() ?? 25);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Gender Dropdown
                _buildValidatedDropdown(
                  label: "Gender",
                  infoMessage: "Set Buddy's pronoun. *Not used in manual mode*",
                  items: _genders,
                  value: _selectedGender,
                  onChanged: (value) => setState(() => _selectedGender = value),
                  validator: (value) {
                    if (value == null || !_genders.contains(value)) {
                      return "Invalid gender selected.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Voice Dropdown
                _buildValidatedDropdown(
                  label: "Voice",
                  infoMessage: "Select a voice style for speech.",
                  items: _voices,
                  value: _selectedVoice,
                  onChanged: (value) => setState(() => _selectedVoice = value),
                  validator: (value) {
                    if (value == null || !_voices.contains(value)) {
                      return "Invalid voice selected.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Accent Dropdown
                DropdownButtonFormField<String>(
                  autovalidateMode: AutovalidateMode.always,
                  value: _accents.contains(_accent) ? _accent : _accents[0],
                  onChanged: (value) => setState(() => _accent = value),
                  items: _accents.map((item) {
                    return DropdownMenuItem(value: item, child: Text(item));
                  }).toList(),
                  borderRadius: BorderRadius.circular(12.0),
                  decoration: InputDecoration(
                    labelText: "Accent",
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.info_outline, size: 16),
                      splashRadius: 16,
                      onPressed: () => _showInfo(
                        "Regional accent for speech.",
                      ),
                    ),
                  ),
                  // No strict validation for accent needed
                ),
                const SizedBox(height: 16),

                // Fastness Dropdown
                DropdownButtonFormField<String>(
                  autovalidateMode: AutovalidateMode.always,
                  value: _fastnessOptions.contains(_fastness)
                      ? _fastness
                      : _fastnessOptions[2],
                  onChanged: (value) => setState(() => _fastness = value),
                  items: _fastnessOptions.map((item) {
                    return DropdownMenuItem(value: item, child: Text(item));
                  }).toList(),
                  borderRadius: BorderRadius.circular(12.0),
                  decoration: InputDecoration(
                    labelText: "Speech rate",
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.info_outline, size: 16),
                      splashRadius: 16,
                      onPressed: () => _showInfo(
                        "How fast speech will talk.",
                      ),
                    ),
                  ),
                  // Typically no strict validation on speech rate
                ),
                const SizedBox(height: 16),

                // Loudness Dropdown
                DropdownButtonFormField<String>(
                  autovalidateMode: AutovalidateMode.always,
                  value: _loudnessOptions.contains(_loudness)
                      ? _loudness
                      : _loudnessOptions[2],
                  onChanged: (value) => setState(() => _loudness = value),
                  items: _loudnessOptions.map((item) {
                    return DropdownMenuItem(value: item, child: Text(item));
                  }).toList(),
                  borderRadius: BorderRadius.circular(12.0),
                  decoration: InputDecoration(
                    labelText: "Volume",
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.info_outline, size: 16),
                      splashRadius: 16,
                      onPressed: () => _showInfo(
                        "Volume level for speech.",
                      ),
                    ),
                  ),
                  // No strict validation
                ),
                const SizedBox(height: 16),

                // Tone Dropdown
                DropdownButtonFormField<String>(
                  autovalidateMode: AutovalidateMode.always,
                  value: _tones.contains(_tone) ? _tone : _tones[0],
                  onChanged: (value) => setState(() => _tone = value),
                  items: _tones.map((item) {
                    return DropdownMenuItem(value: item, child: Text(item));
                  }).toList(),
                  borderRadius: BorderRadius.circular(12.0),
                  decoration: InputDecoration(
                    labelText: "Tone",
                    border:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.info_outline, size: 16),
                      splashRadius: 16,
                      onPressed: () => _showInfo(
                        "The emotional tone speech will use.",
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveUserInfo,
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Save"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
         ),
      ),
    );
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

  ///
  /// The main entry point for this widget. Tapping the avatar
  /// opens a bottom sheet with the profile form.
@override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: () {
      if (widget.jwtToken.trim().isEmpty) {
        // Show login-required dialog if jwtToken is empty
        _showInfoDialog(context, "Login Required", "Please login to use this feature.");
        return;
      }

    
      _backupInitialValues();

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: _buildProfileForm(),
        ),
      ).whenComplete(() {
        // Revert changes if the user closes the sheet without saving
        if (!_isSaved && mounted) {
          _restoreInitialValues();
        }
      });
    },
    child: Image.asset(
      'assets/images/profileicon.png',
      width: 30,
      height: 30,
    ),
  );
}
}