import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:live_location/firebase_operations.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  // Feedback form fields
  String _feedbackType = 'Missed Collection';
  String _description = '';
  double _rating = 3.0;
  Map<String, dynamic>? currentUserData;
  File? _selectedImage;
  bool _isLoading = false;
  String? _wardNumber;

  // Define the same color scheme from ActiveVehiclesScreen
  final Color primaryColor = const Color(0xFF3F51B5);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = const Color(0xFFF5F7FA);
  final Color cardColor = Colors.white;
  final Color inactiveColor = const Color(0xFFE57373);

  final List<String> _feedbackTypes = [
    'Missed Collection',
    'Rate Service',
    'Suggestion',
    'Waste Issue'
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var userData = await fetchCurrentUserData();
      setState(() {
        _wardNumber = userData['ward_number'].toString();
      });
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null) {
        setState(() {
          _selectedImage = File(result.files.single.path!);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to select image: $e')),
      );
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final fileName = '${user?.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance
          .ref()
          .child('feedback_images')
          .child(fileName);

      await ref.putFile(_selectedImage!);
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error uploading image: $e");
      return null;
    }
  }

  Future<void> _submitFeedback() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      setState(() {
        _isLoading = true;
      });

      try {
        String? imageUrl;
        if (_selectedImage != null) {
          imageUrl = await _uploadImage();
        }

        await FirebaseFirestore.instance.collection('feedback').add({
          'user_id': user?.uid,
          'user_email': user?.email,
          'user_name': currentUserData?['name'] ?? 'Anonymous',
          'ward_number': _wardNumber,
          'feedback_type': _feedbackType,
          'description': _description,
          'rating': _feedbackType == 'Rate Service' ? _rating : null,
          'image_url': imageUrl,
          'status': 'Pending',
          'created_at': FieldValue.serverTimestamp(),
          'resolved_at': null,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Feedback submitted successfully!'),
              backgroundColor: accentColor,
            ),
          );

          // Reset form
          setState(() {
            _description = '';
            _selectedImage = null;
            _rating = 3.0;
          });
        }
      } catch (e) {
        debugPrint("Error submitting feedback: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to submit feedback: $e'),
              backgroundColor: inactiveColor,
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Submit Feedback'),
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.feedback_rounded,
                          color: primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Feedback',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Help us improve our garbage collection service',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Feedback Type Selection
              Text(
                'Feedback Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonFormField<String>(
                  value: _feedbackType,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    border: InputBorder.none,
                  ),
                  items: _feedbackTypes.map((String type) {
                    return DropdownMenuItem<String>(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _feedbackType = newValue!;
                    });
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Rating Slider (only for Rate Service type)
              if (_feedbackType == 'Rate Service') ...[
                Text(
                  'Service Rating',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(5, (index) {
                          return _buildRatingIcon(index + 1);
                        }),
                      ),
                      Slider(
                        value: _rating,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        activeColor: accentColor,
                        inactiveColor: Colors.grey.shade300,
                        onChanged: (value) {
                          setState(() {
                            _rating = value;
                          });
                        },
                      ),
                      Text(
                        '${_rating.toInt()} Star${_rating.toInt() > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Description Field
              Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextFormField(
                  decoration: const InputDecoration(
                    hintText: 'Provide details about your feedback...',
                    contentPadding: EdgeInsets.all(16),
                    border: InputBorder.none,
                  ),
                  maxLines: 5,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter description';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _description = value!;
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Image Upload Option (for Missed Collection and Waste Issue)
              if (_feedbackType == 'Missed Collection' || _feedbackType == 'Waste Issue') ...[
                Text(
                  'Upload Photo (Optional)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (_selectedImage != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            _selectedImage!,
                            height: 150,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _pickImage,
                        icon: Icon(_selectedImage == null ? Icons.add_photo_alternate : Icons.change_circle),
                        label: Text(_selectedImage == null ? 'Select Photo' : 'Change Photo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    elevation: 3,
                  ),
                  onPressed: _submitFeedback,
                  child: const Text(
                    'Submit Feedback',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // View Previous Feedback Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FeedbackHistoryScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'View My Feedback History',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingIcon(int index) {
    return Icon(
      Icons.star,
      size: 30,
      color: _rating >= index ? Colors.amber : Colors.grey.shade300,
    );
  }
}


class FeedbackHistoryScreen extends StatefulWidget {
  const FeedbackHistoryScreen({super.key});

  @override
  State<FeedbackHistoryScreen> createState() => _FeedbackHistoryScreenState();
}

class _FeedbackHistoryScreenState extends State<FeedbackHistoryScreen> {
  final user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> feedbackList = [];
  bool isLoading = true;


  final Color primaryColor = const Color(0xFF3F51B5);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = const Color(0xFFF5F7FA);
  final Color cardColor = Colors.white;
  final Color inactiveColor = const Color(0xFFE57373);

  @override
  void initState() {
    super.initState();
    _fetchFeedbackHistory();
  }

  Future<void> _fetchFeedbackHistory() async {
    setState(() {
      isLoading = true;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('feedback')
          .where('user_id', isEqualTo: user?.uid)
          .orderBy('created_at', descending: true)
          .get();

      setState(() {
        feedbackList = snapshot.docs
            .map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        })
            .toList();
      });
    } catch (e) {
      debugPrint("Error fetching feedback history: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('My Feedback History'),
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : feedbackList.isEmpty
              ? _buildEmptyState()
              : _buildFeedbackList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.feedback_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No feedback history found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submit your first feedback to improve our service',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackList() {
    return ListView.builder(
      itemCount: feedbackList.length,
      itemBuilder: (context, index) {
        final feedback = feedbackList[index];
        final Timestamp? timestamp = feedback['created_at'];
        final DateTime date = timestamp != null
            ? timestamp.toDate()
            : DateTime.now();
        final String formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(date);

        // Determine status color
        Color statusColor = Colors.grey;
        if (feedback['status'] == 'Resolved') {
          statusColor = accentColor;
        } else if (feedback['status'] == 'Pending') {
          statusColor = Colors.amber;
        } else if (feedback['status'] == 'Rejected') {
          statusColor = inactiveColor;
        }

        return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FeedbackDetailScreen(feedback: feedback),
                ),
              );
            },
        child: Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      feedback['feedback_type'] ?? 'Feedback',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        feedback['status'] ?? 'Pending',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 12),
                if (feedback['feedback_type'] == 'Rate Service') ...[
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        Icons.star,
                        size: 18,
                        color: (feedback['rating'] ?? 0) > index
                            ? Colors.amber
                            : Colors.grey.shade300,
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                ],
                Text(
                  feedback['description'] ?? 'No description provided',
                  style: const TextStyle(fontSize: 14),
                ),
                if (feedback['image_url'] != null) ...[
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      feedback['image_url'],
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 80,
                          width: double.infinity,
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Text("Image not available"),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                if (feedback['admin_response'] != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Response from Admin:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          feedback['admin_response'],
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ));
      },
    );
  }
}



class FeedbackDetailScreen extends StatelessWidget {
  final Map<String, dynamic> feedback;

  const FeedbackDetailScreen({super.key, required this.feedback});

  // Define the same color scheme
  final Color primaryColor = const Color(0xFF3F51B5);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = const Color(0xFFF5F7FA);
  final Color cardColor = Colors.white;
  final Color inactiveColor = const Color(0xFFE57373);

  @override
  Widget build(BuildContext context) {
    final Timestamp? timestamp = feedback['created_at'];
    final DateTime date = timestamp != null ? timestamp.toDate() : DateTime.now();
    final String formattedDate = DateFormat('MMMM dd, yyyy - hh:mm a').format(date);

    // Determine status color
    Color statusColor = Colors.grey;
    if (feedback['status'] == 'Resolved') {
      statusColor = accentColor;
    } else if (feedback['status'] == 'Pending') {
      statusColor = Colors.amber;
    } else if (feedback['status'] == 'Rejected') {
      statusColor = inactiveColor;
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text('Feedback Details'),
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        feedback['feedback_type'] ?? 'Feedback',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          feedback['status'] ?? 'Pending',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Submitted on: $formattedDate',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ward: ${feedback['ward_number'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            if (feedback['feedback_type'] == 'Rate Service') ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rating',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          Icons.star,
                          size: 30,
                          color: (feedback['rating'] ?? 0) > index
                              ? Colors.amber
                              : Colors.grey.shade300,
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${feedback['rating']?.toInt() ?? 0} out of 5 stars',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Description
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    feedback['description'] ?? 'No description provided',
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),


            if (feedback['image_url'] != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attached Photo',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        feedback['image_url'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 120,
                            width: double.infinity,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Text("Image not available"),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Admin Response (if available)
            if (feedback['admin_response'] != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Response from Admin',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      feedback['admin_response'],
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    if (feedback['resolved_at'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Responded on: ${DateFormat('MMM dd, yyyy').format((feedback['resolved_at'] as Timestamp).toDate())}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
