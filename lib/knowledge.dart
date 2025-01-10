import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class KnowledgeBaseModal extends StatefulWidget {
  final String jwtToken;

  const KnowledgeBaseModal({super.key, required this.jwtToken});

  @override
  State<KnowledgeBaseModal> createState() => _KnowledgeBaseModalState();
}

class _KnowledgeBaseModalState extends State<KnowledgeBaseModal> {
  bool _isLoading = false;
  final Map<String, String?> _errors = {};
  final TextEditingController _textController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _knowledgeEntries = []; // List of entries
  
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
     if (widget.jwtToken.trim().isNotEmpty) {
    _fetchKnowledgeEntries(); // Load existing entries initially
     }
  }

  /// Info icon dialog helper
  void _showInfo(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        
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

  /// Saves the knowledge entry (called by "Add" button)
  Future<void> _saveKnowledgeEntry() async {
    // First, re-fetch the existing entries to catch newly added duplicates
    await _fetchKnowledgeEntries();

    // Next, run the Form's built-in validator
    if (!_formKey.currentState!.validate()) {
      // If built-in validation fails, do NOT pop the sheet
      return;
    }

    // Then run your custom `_validateInputs()` to check duplicates, etc.
    if (!_validateInputs()) {
      // If there's an error (like "This entry already exists"), do NOT pop
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errors.remove('general'); // Clear any old general errors
      });
    }

    final url = Uri.parse("https://www.hearme.services/user/knowledge/set");
    final body = {
      'category': _selectedCategory,
      'text': _textController.text.trim(),
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.jwtToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        // Successfully saved, so refresh list again
        await _fetchKnowledgeEntries();
        // Now that it's 100% success, we can pop the sheet
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) {
          setState(() {
            _errors['general'] =
                "Failed to save knowledge entry. Status: ${response.statusCode}";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errors['general'] = "An error occurred: $e";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Fetch the knowledge entries from the server
  Future<void> _fetchKnowledgeEntries() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    final url = Uri.parse("https://www.hearme.services/user/knowledge/get");
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.jwtToken}',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _knowledgeEntries =
              List<Map<String, dynamic>>.from(data['knowledge_entries'] ?? []);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errors['general'] = "Failed to fetch knowledge entries.";
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Deletes a knowledge entry and refreshes
  Future<void> _deleteKnowledgeEntry(String id) async {
    final url = Uri.parse("https://www.hearme.services/user/knowledge/delete");
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${widget.jwtToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'id': id}),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pop(); // Close any open modal
        }
        await _fetchKnowledgeEntries(); // Refresh the list
      }
    } catch (e) {
      // Optionally handle error
    }
  }

  /// Your custom validation checks:
  /// - Category not empty
  /// - Text length < 500
  /// - No duplicates
  bool _validateInputs() {
    setState(() {
      _errors.clear();

      if (_selectedCategory == null || _selectedCategory!.isEmpty) {
        _errors['category'] = "Category is required.";
      }

      final textTrimmed = _textController.text.trim();
      if (textTrimmed.isEmpty) {
        _errors['text'] = "Text is required.";
      } else if (textTrimmed.length > 500) {
        _errors['text'] = "Text cannot exceed 500 characters.";
      }

      // Duplicate check: same category + same text
      final duplicateExists = _knowledgeEntries.any(
        (entry) =>
            (entry['category'] == _selectedCategory) &&
            (entry['text']?.trim() == textTrimmed),
      );
      if (duplicateExists) {
        _errors['text'] = "This entry already exists.";
      }
    });

    return _errors.isEmpty;
  }

@override
Widget build(BuildContext context) {
  return GestureDetector(
    onTap: () {
      if (widget.jwtToken.trim().isEmpty) {
        // Show login-required dialog if jwtToken is empty
        _showInfoDialog(context, "Login Required", "Please login to use this feature.");
        return;
      }

      // If jwtToken is valid, proceed with opening the knowledge form
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: MediaQuery.of(context).viewInsets,
          child: _buildKnowledgeForm(),
        ),
      );
    },
    child: Image.asset(
      'assets/images/knowledicon.png',
      width: 30,
      height: 30,
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

  Widget _buildKnowledgeForm() {

  final mediaQuery = MediaQuery.of(context);
    return Card(
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
          child: Form(
            key: _formKey, // Manage validator state
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ///
                /// "Add Knowledge" with (i) icon
                ///
                Row(
                  children: [
                    const Text(
                      "Add Knowledge",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 18),
                      splashRadius: 16,
                      onPressed: () => _showInfo(
                        "Seperate and detail your thoughts; The entry name does not matter; Buddy will find it all! Example: 'I like Taylor Swift, and Beyonce ... because ... '. *Used for Buddy mode; Knowledge entries let Buddy know persona context.*",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category Dropdown
            TextFormField(
  initialValue: _selectedCategory,
  maxLength: 20,
  decoration: InputDecoration(
    labelText: "Name",
    errorText: _errors['category'], // Keeping your error handling
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.0),
    ),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 4,
    ),
  ),
  onChanged: (value) {
    setState(() {
      _selectedCategory = value.trim();
    });
  },
  validator: (value) {
    if (value == null || value.isEmpty) {
      return "Name is required.";
    }
    if (value.length > 20) {
      return "Name must be 20 characters or less.";
    }
    return null;
  },
),

                const SizedBox(height: 16),

                // TextFormField for "text"
                TextFormField(
                  controller: _textController,
                  maxLength: 500,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: "... I like or dislike ... because ...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    // Show your custom error for duplicates, etc.
                    errorText: _errors['text'],
                  ),
                  validator: (value) {
                    final textTrimmed = value?.trim() ?? '';
                    if (textTrimmed.isEmpty) {
                      return "Text is required.";
                    } else if (textTrimmed.length > 500) {
                      return "Text cannot exceed 500 characters.";
                    }
                    return null; // No immediate error
                  },
                ),

                // "general" error
                if (_errors['general'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _errors['general']!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _saveKnowledgeEntry,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Add"),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),

                ///
                /// "Assistant's Knowledge" with (i) icon
                ///
                Row(
                  children: [
                    const Text(
                      "Buddy's Knowledge",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 18),
                      splashRadius: 16,
                      onPressed: () => _showInfo(
                        "All existing knowledge; You can delete any by tapping the trash icon. *Knowledge entries let Buddy know persona context.*",
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // List of knowledge entries
                SizedBox(
                  height: 300, // Fixed height for scrolling
                  child: ListView.builder(
                    itemCount: _knowledgeEntries.length,
                    itemBuilder: (context, index) {
                      final entry = _knowledgeEntries[index];
                      return ListTile(
                        title: Text(entry['category']),
                        subtitle: Text(entry['text']),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            _deleteKnowledgeEntry(entry['id'].toString());
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        ),
    );
  }
}
