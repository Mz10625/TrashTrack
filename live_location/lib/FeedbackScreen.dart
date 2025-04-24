// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_storage/firebase_storage.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:intl/intl.dart';
//
// class FeedbackScreen extends StatefulWidget {
//   const FeedbackScreen({Key? key}) : super(key: key);
//
//   @override
//   State<FeedbackScreen> createState() => _FeedbackScreenState();
// }
//
// class _FeedbackScreenState extends State<FeedbackScreen> {
//   // Form controllers
//   final TextEditingController _descriptionController = TextEditingController();
//
//   // Color scheme from existing app
//   final Color primaryColor = const Color(0xFF3F51B5);
//   final Color accentColor = const Color(0xFF4CAF50);
//   final Color backgroundColor = const Color(0xFFF5F7FA);
//   final Color cardColor = Colors.white;
//
//   // Feedback type selection
//   String _selectedFeedbackType = 'Missed Collection';
//   final List<String> _feedbackTypes = [
//     'Missed Collection',
//     'Rate Service',
//     'Suggestion',
//     'Report Issue'
//   ];
//
//   // Rating for service
//   int _rating = 0;
//
//   // Image for issue reporting
//   File? _image;
//   bool _isUploading = false;
//
//   // Ward info
//   String? _wardNumber;
//
//   @override
//   void initState() {
//     super.initState();
//     _loadUserWard();
//   }
//
//   @override
//   void dispose() {
//     _descriptionController.dispose();
//     super.dispose();
//   }
//
//   // Load user's ward from Firestore
//   Future<void> _loadUserWard() async {
//     try {
//       final user = FirebaseAuth.instance.currentUser;
//       if (user != null) {
//         final userData = await FirebaseFirestore.instance
//             .collection('users')
//             .doc(user.uid)
//             .get();
//
//         if (userData.exists && userData.data()!.containsKey('ward_number')) {
//           setState(() {
//             _wardNumber = userData.data()!['ward_number'].toString();
//           });
//         }
//       }
//     } catch (e) {
//       debugPrint('Error loading user ward: $e');
//     }
//   }
//
//   // Pick image from gallery
//   Future<void> _pickImage() async {
//     final ImagePicker picker = ImagePicker();
//     final XFile? pickedFile = await picker.pickImage(
//       source: ImageSource.gallery,
//       maxWidth: 1200,
//       maxHeight: 1200,
//       imageQuality: 85,
//     );
//
//     if (pickedFile != null) {
//       setState(() {
//         _image = File(pickedFile.path);
//       });
//     }
//   }
//
//   // Upload image to Firebase Storage
//   Future<String?> _uploadImage() async {
//     if (_image == null) return null;
//
//     try {
//       setState(() {
//         _isUploading = true;
//       });
//
//       final user = FirebaseAuth.instance.currentUser;
//       final timestamp = DateTime.now().millisecondsSinceEpoch;
//       final path = 'feedback_images/${user!.uid}_$timestamp.jpg';
//
//       final ref = FirebaseStorage.instance.ref().child(path);
//       await ref.putFile(_image!);
//
//       final url = await ref.getDownloadURL();
//       return url;
//     } catch (e) {
//       debugPrint('Error uploading image: $e');
//       return null;
//     } finally {
//       setState(() {
//         _isUploading = false;
//       });
//     }
//   }
//
//   // Submit feedback to Firestore
//   Future<void> _submitFeedback() async {
//     if (_descriptionController.text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('Please enter a description')),
//       );
//       return;
//     }
//
//     try {
//       setState(() {
//         _isUploading = true;
//       });
//
//       final user = FirebaseAuth.instance.currentUser;
//       if (user == null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('You need to be logged in to submit feedback')),
//         );
//         return;
//       }
//
//       // Upload image if any
//       String? imageUrl;
//       if (_image != null && _selectedFeedbackType == 'Report Issue') {
//         imageUrl = await _uploadImage();
//       }
//
//       // Create feedback document
//       final feedback = {
//         'user_id': user.uid,
//         'user_email': user.email,
//         'type': _selectedFeedbackType,
//         'description': _descriptionController.text.trim(),
//         'ward_number': _wardNumber,
//         'timestamp': FieldValue.serverTimestamp(),
//         'status': 'Pending',
//         'created_at': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
//       };
//
//       // Add rating if feedback type is Rate Service
//       if (_selectedFeedbackType == 'Rate Service') {
//         feedback['rating'] = _rating;
//       }
//
//       // Add image URL if available
//       if (imageUrl != null) {
//         feedback['image_url'] = imageUrl;
//       }
//
//       // Add to Firestore
//       await FirebaseFirestore.instance.collection('feedback').add(feedback);
//
//       // Reset form
//       _descriptionController.clear();
//       setState(() {
//         _image = null;
//         _rating = 0;
//       });
//
//       // Show success message
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: const Text('Feedback submitted successfully'),
//             backgroundColor: accentColor,
//           ),
//         );
//         Navigator.pop(context);
//       }
//     } catch (e) {
//       debugPrint('Error submitting feedback: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Error submitting feedback: ${e.toString()}'),
//           backgroundColor: Colors.red,
//         ),
//       );
//     } finally {
//       setState(() {
//         _isUploading = false;
//       });
//     }
//   }
//
//   Widget _buildFeedbackTypeSelector() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           'Select Feedback Type',
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             color: primaryColor,
//             fontSize: 16,
//           ),
//         ),
//         const SizedBox(height: 12),
//         Container(
//           decoration: BoxDecoration(
//             color: cardColor,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.grey.withOpacity(0.1),
//                 spreadRadius: 1,
//                 blurRadius: 4,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: ListView.builder(
//             shrinkWrap: true,
//             physics: const NeverScrollableScrollPhysics(),
//             itemCount: _feedbackTypes.length,
//             itemBuilder: (context, index) {
//               final type = _feedbackTypes[index];
//               return RadioListTile<String>(
//                 title: Text(type),
//                 value: type,
//                 groupValue: _selectedFeedbackType,
//                 activeColor: accentColor,
//                 onChanged: (value) {
//                   setState(() {
//                     _selectedFeedbackType = value!;
//                   });
//                 },
//               );
//             },
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildRatingSelector() {
//     return Visibility(
//       visible: _selectedFeedbackType == 'Rate Service',
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const SizedBox(height: 20),
//           Text(
//             'Rate the Collection Service',
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               color: primaryColor,
//               fontSize: 16,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 16),
//             decoration: BoxDecoration(
//               color: cardColor,
//               borderRadius: BorderRadius.circular(12),
//               boxShadow: [
//                 BoxShadow(
//                   color: Colors.grey.withOpacity(0.1),
//                   spreadRadius: 1,
//                   blurRadius: 4,
//                   offset: const Offset(0, 2),
//                 ),
//               ],
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: List.generate(5, (index) {
//                 return IconButton(
//                   iconSize: 36,
//                   icon: Icon(
//                     index < _rating ? Icons.star : Icons.star_border,
//                     color: index < _rating ? accentColor : Colors.grey,
//                   ),
//                   onPressed: () {
//                     setState(() {
//                       _rating = index + 1;
//                     });
//                   },
//                 );
//               }),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildImagePicker() {
//     return Visibility(
//       visible: _selectedFeedbackType == 'Report Issue',
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const SizedBox(height: 20),
//           Text(
//             'Upload Photo (Optional)',
//             style: TextStyle(
//               fontWeight: FontWeight.bold,
//               color: primaryColor,
//               fontSize: 16,
//             ),
//           ),
//           const SizedBox(height: 12),
//           InkWell(
//             onTap: _pickImage,
//             child: Container(
//               height: 150,
//               width: double.infinity,
//               decoration: BoxDecoration(
//                 color: cardColor,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.grey.withOpacity(0.1),
//                     spreadRadius: 1,
//                     blurRadius: 4,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//               ),
//               child: _image == null
//                   ? Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.add_photo_alternate_outlined,
//                     size: 48,
//                     color: primaryColor.withOpacity(0.5),
//                   ),
//                   const SizedBox(height: 8),
//                   Text(
//                     'Tap to add photo',
//                     style: TextStyle(
//                       color: Colors.grey.shade600,
//                       fontSize: 14,
//                     ),
//                   ),
//                 ],
//               )
//                   : ClipRRect(
//                 borderRadius: BorderRadius.circular(12),
//                 child: Stack(
//                   fit: StackFit.expand,
//                   children: [
//                     Image.file(
//                       _image!,
//                       fit: BoxFit.cover,
//                     ),
//                     Positioned(
//                       right: 0,
//                       top: 0,
//                       child: Material(
//                         color: Colors.transparent,
//                         child: InkWell(
//                           onTap: () {
//                             setState(() {
//                               _image = null;
//                             });
//                           },
//                           child: Container(
//                             padding: const EdgeInsets.all(4),
//                             decoration: BoxDecoration(
//                               color: Colors.black.withOpacity(0.5),
//                               shape: BoxShape.circle,
//                             ),
//                             child: const Icon(
//                               Icons.close,
//                               color: Colors.white,
//                               size: 20,
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDescriptionField() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const SizedBox(height: 20),
//         Text(
//           'Description',
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             color: primaryColor,
//             fontSize: 16,
//           ),
//         ),
//         const SizedBox(height: 12),
//         Container(
//           decoration: BoxDecoration(
//             color: cardColor,
//             borderRadius: BorderRadius.circular(12),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.grey.withOpacity(0.1),
//                 spreadRadius: 1,
//                 blurRadius: 4,
//                 offset: const Offset(0, 2),
//               ),
//             ],
//           ),
//           child: TextField(
//             controller: _descriptionController,
//             maxLines: 5,
//             decoration: InputDecoration(
//               hintText: _getHintText(),
//               contentPadding: const EdgeInsets.all(16),
//               border: OutlineInputBorder(
//                 borderRadius: BorderRadius.circular(12),
//                 borderSide: BorderSide.none,
//               ),
//               filled: true,
//               fillColor: cardColor,
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   String _getHintText() {
//     switch (_selectedFeedbackType) {
//       case 'Missed Collection':
//         return 'Describe when and where the collection was missed...';
//       case 'Rate Service':
//         return 'Provide any additional comments about the service...';
//       case 'Suggestion':
//         return 'Share your suggestions to improve the service...';
//       case 'Report Issue':
//         return 'Describe the waste-related issue you encountered...';
//       default:
//         return 'Enter your feedback here...';
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: backgroundColor,
//       appBar: AppBar(
//         title: const Text('Submit Feedback'),
//         backgroundColor: primaryColor,
//         foregroundColor: Colors.white,
//         elevation: 0,
//       ),
//       body: _isUploading
//           ? Center(
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             CircularProgressIndicator(color: primaryColor),
//             const SizedBox(height: 16),
//             const Text('Submitting your feedback...'),
//           ],
//         ),
//       )
//           : SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.all(16),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: cardColor,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.grey.withOpacity(0.1),
//                       spreadRadius: 1,
//                       blurRadius: 4,
//                       offset: const Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Icon(
//                           Icons.feedback_rounded,
//                           color: primaryColor,
//                           size: 28,
//                         ),
//                         const SizedBox(width: 10),
//                         Text(
//                           'Feedback',
//                           style: TextStyle(
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                             color: primaryColor,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Help us improve the garbage collection service',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.grey.shade700,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 20),
//
//               // Feedback form
//               _buildFeedbackTypeSelector(),
//               _buildRatingSelector(),
//               _buildImagePicker(),
//               _buildDescriptionField(),
//
//               // Submit button
//               const SizedBox(height: 30),
//               SizedBox(
//                 width: double.infinity,
//                 height: 50,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: accentColor,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10.0),
//                     ),
//                     elevation: 3,
//                   ),
//                   onPressed: _submitFeedback,
//                   child: const Text(
//                     'Submit Feedback',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // Feedback History Screen to view submitted feedback
// class FeedbackHistoryScreen extends StatelessWidget {
//   FeedbackHistoryScreen({Key? key}) : super(key: key);
//
//   final Color primaryColor = const Color(0xFF3F51B5);
//   final Color accentColor = const Color(0xFF4CAF50);
//   final Color backgroundColor = const Color(0xFFF5F7FA);
//   final Color cardColor = Colors.white;
//   final Color inactiveColor = const Color(0xFFE57373);
//
//   @override
//   Widget build(BuildContext context) {
//     final user = FirebaseAuth.instance.currentUser;
//
//     return Scaffold(
//       backgroundColor: backgroundColor,
//       appBar: AppBar(
//         title: const Text('My Feedback'),
//         backgroundColor: primaryColor,
//         foregroundColor: Colors.white,
//         elevation: 0,
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Header
//               Container(
//                 padding: const EdgeInsets.all(16),
//                 decoration: BoxDecoration(
//                   color: cardColor,
//                   borderRadius: BorderRadius.circular(12),
//                   boxShadow: [
//                     BoxShadow(
//                       color: Colors.grey.withOpacity(0.1),
//                       spreadRadius: 1,
//                       blurRadius: 4,
//                       offset: const Offset(0, 2),
//                     ),
//                   ],
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         Icon(
//                           Icons.history,
//                           color: primaryColor,
//                           size: 28,
//                         ),
//                         const SizedBox(width: 10),
//                         Text(
//                           'Feedback History',
//                           style: TextStyle(
//                             fontSize: 24,
//                             fontWeight: FontWeight.bold,
//                             color: primaryColor,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       'View your previously submitted feedback',
//                       style: TextStyle(
//                         fontSize: 14,
//                         color: Colors.grey.shade700,
//                         fontWeight: FontWeight.w500,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//
//               const SizedBox(height: 20),
//
//               // Feedback list
//               Expanded(
//                 child: StreamBuilder<QuerySnapshot>(
//                   stream: FirebaseFirestore.instance
//                       .collection('feedback')
//                       .where('user_id', isEqualTo: user?.uid)
//                       .orderBy('timestamp', descending: true)
//                       .snapshots(),
//                   builder: (context, snapshot) {
//                     if (snapshot.connectionState == ConnectionState.waiting) {
//                       return Center(
//                         child: CircularProgressIndicator(color: primaryColor),
//                       );
//                     }
//
//                     if (snapshot.hasError) {
//                       return Center(
//                         child: Text('Error: ${snapshot.error}'),
//                       );
//                     }
//
//                     if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                       return Center(
//                         child: Column(
//                           mainAxisAlignment: MainAxisAlignment.center,
//                           children: [
//                             Icon(
//                               Icons.feedback_outlined,
//                               size: 80,
//                               color: Colors.grey.shade400,
//                             ),
//                             const SizedBox(height: 16),
//                             Text(
//                               'No feedback submitted yet',
//                               style: TextStyle(
//                                 fontSize: 16,
//                                 color: Colors.grey.shade600,
//                                 fontWeight: FontWeight.w500,
//                               ),
//                             ),
//                             const SizedBox(height: 8),
//                             Text(
//                               'Your submitted feedback will appear here',
//                               style: TextStyle(
//                                 fontSize: 14,
//                                 color: Colors.grey.shade500,
//                               ),
//                             ),
//                           ],
//                         ),
//                       );
//                     }
//
//                     return ListView.builder(
//                       itemCount: snapshot.data!.docs.length,
//                       itemBuilder: (context, index) {
//                         final feedback = snapshot.data!.docs[index].data() as Map<String, dynamic>;
//                         final feedbackId = snapshot.data!.docs[index].id;
//                         final status = feedback['status'] ?? 'Pending';
//                         final type = feedback['type'] ?? 'Feedback';
//                         final date = feedback['created_at'] ?? '';
//                         final description = feedback['description'] ?? '';
//
//                         Color statusColor;
//                         switch (status) {
//                           case 'Resolved':
//                             statusColor = accentColor;
//                             break;
//                           case 'In Progress':
//                             statusColor = Colors.amber;
//                             break;
//                           case 'Pending':
//                           default:
//                             statusColor = Colors.orange;
//                             break;
//                         }
//
//                         Icon typeIcon;
//                         switch (type) {
//                           case 'Missed Collection':
//                             typeIcon = Icon(Icons.delete_outline, color: primaryColor);
//                             break;
//                           case 'Rate Service':
//                             typeIcon = Icon(Icons.star_outline, color: primaryColor);
//                             break;
//                           case 'Suggestion':
//                             typeIcon = Icon(Icons.lightbulb_outline, color: primaryColor);
//                             break;
//                           case 'Report Issue':
//                             typeIcon = Icon(Icons.warning_amber_outlined, color: primaryColor);
//                             break;
//                           default:
//                             typeIcon = Icon(Icons.feedback_outlined, color: primaryColor);
//                             break;
//                         }
//
//                         return Card(
//                           margin: const EdgeInsets.only(bottom: 12),
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                           elevation: 1,
//                           child: InkWell(
//                             borderRadius: BorderRadius.circular(12),
//                             onTap: () {
//                               // Show feedback details
//                               showModalBottomSheet(
//                                 context: context,
//                                 isScrollControlled: true,
//                                 backgroundColor: Colors.transparent,
//                                 builder: (context) => FeedbackDetailSheet(
//                                   feedbackId: feedbackId,
//                                   feedback: feedback,
//                                   statusColor: statusColor,
//                                   cardColor: cardColor,
//                                   primaryColor: primaryColor,
//                                 ),
//                               );
//                             },
//                             child: Padding(
//                               padding: const EdgeInsets.all(16),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Row(
//                                     children: [
//                                       typeIcon,
//                                       const SizedBox(width: 8),
//                                       Expanded(
//                                         child: Text(
//                                           type,
//                                           style: TextStyle(
//                                             fontSize: 16,
//                                             fontWeight: FontWeight.bold,
//                                             color: primaryColor,
//                                           ),
//                                         ),
//                                       ),
//                                       Container(
//                                         padding: const EdgeInsets.symmetric(
//                                           horizontal: 8,
//                                           vertical: 4,
//                                         ),
//                                         decoration: BoxDecoration(
//                                           color: statusColor.withOpacity(0.1),
//                                           borderRadius: BorderRadius.circular(20),
//                                         ),
//                                         child: Row(
//                                           mainAxisSize: MainAxisSize.min,
//                                           children: [
//                                             Container(
//                                               width: 8,
//                                               height: 8,
//                                               decoration: BoxDecoration(
//                                                 shape: BoxShape.circle,
//                                                 color: statusColor,
//                                               ),
//                                               margin: const EdgeInsets.only(right: 4),
//                                             ),
//                                             Text(
//                                               status,
//                                               style: TextStyle(
//                                                 color: statusColor,
//                                                 fontWeight: FontWeight.w600,
//                                                 fontSize: 12,
//                                               ),
//                                             ),
//                                           ],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Text(
//                                     description,
//                                     maxLines: 2,
//                                     overflow: TextOverflow.ellipsis,
//                                     style: TextStyle(
//                                       fontSize: 14,
//                                       color: Colors.grey.shade800,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 8),
//                                   Row(
//                                     mainAxisAlignment: MainAxisAlignment.end,
//                                     children: [
//                                       Icon(
//                                         Icons.calendar_today_outlined,
//                                         size: 12,
//                                         color: Colors.grey.shade500,
//                                       ),
//                                       const SizedBox(width: 4),
//                                       Text(
//                                         date,
//                                         style: TextStyle(
//                                           fontSize: 12,
//                                           color: Colors.grey.shade500,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ),
//                         );
//                       },
//                     );
//                   },
//                 ),
//               ),
//
//               // Add feedback button
//               const SizedBox(height: 20),
//               SizedBox(
//                 width: double.infinity,
//                 height: 50,
//                 child: ElevatedButton.icon(
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: accentColor,
//                     foregroundColor: Colors.white,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(10.0),
//                     ),
//                     elevation: 3,
//                   ),
//                   icon: const Icon(Icons.add),
//                   label: const Text(
//                     'Submit New Feedback',
//                     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
//                   ),
//                   onPressed: () {
//                     Navigator.push(
//                       context,
//                       MaterialPageRoute(
//                         builder: (context) => const FeedbackScreen(),
//                       ),
//                     );
//                   },
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// // Feedback Details Bottom Sheet
// class FeedbackDetailSheet extends StatelessWidget {
//   final String feedbackId;
//   final Map<String, dynamic> feedback;
//   final Color statusColor;
//   final Color cardColor;
//   final Color primaryColor;
//
//   const FeedbackDetailSheet({
//     Key? key,
//     required this.feedbackId,
//     required this.feedback,
//     required this.statusColor,
//     required this.cardColor,
//     required this.primaryColor,
//   }) : super(key: key);
//
//   @override
//   Widget build(BuildContext context) {
//     return DraggableScrollableSheet(
//         initialChildSize: 0.85,
//         minChildSize: 0.6,
//         maxChildSize: 0.95,
//         builder: (context, scrollController) {
//       return Container(
//         decoration: BoxDecoration(
//           color: cardColor,
//           borderRadius: const BorderRadius.only(
//             topLeft: Radius.circular(24),
//             topRight: Radius.circular(24),
//           ),
//         ),
//         child: ListView(
//           controller: scrollController,
//           padding: const EdgeInsets.all(20),
//           children: [
//         // Drag handle
//         Center(
//         child: Container(
//         width: 40,
//           height: 5,
//           decoration: BoxDecoration(
//             color: Colors.grey.shade300,
//             borderRadius: BorderRadius.circular(5),
//           ),
//         ),
//       ),
//     const SizedBox(height: 20),
//
//     // Header
//     Row(
//     children: [
//     _getTypeIcon(),
//     const SizedBox(width: 10),
//     Expanded(
//     child: Text(
//     feedback['type'] ?? 'Feedback',
//     style: TextStyle(
//     fontSize: 22,
//     fontWeight: FontWeight.bold,
//     color: primaryColor,
//     ),
//     ),
//     ),
//     ],
//     ),
//     const SizedBox(height: 20),
//
//     // Status
//     Container(
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//     decoration: BoxDecoration(
//     color: statusColor.withOpacity(0.1),
//     borderRadius: BorderRadius.circular(8),
//     ),
//     child: Row(
//     mainAxisSize: MainAxisSize.min,
//     children: [
//     Container(
//     width: 10,
//     height: 10,
//     decoration: BoxDecoration(
//     shape: BoxShape.circle,
//     color: statusColor,
//     ),
//     margin: const EdgeInsets.only(right: 8),
//     ),
//     Text(
//     feedback['status'] ?? 'Pending',
//     style: TextStyle(
//     color: statusColor,
//     fontWeight: FontWeight.w600,
//     fontSize: 14,
//     ),
//     ),
//     ],
//     ),
//     ),
//
//     // Info Card
//     _buildInfoCard(),
//
//     // Rating
//     if (feedback['type'] == 'Rate Service' && feedback['rating'] != null)
//     _buildRatingCard(),
//
//     // Description
//     _buildDescriptionCard(),
//
//     // Image preview if available
//     if (feedback['image_url'] != null)
//     _buildImageCard(),
//
//     // Response from authority if available
//             if (feedback['response'] != null)
//               _buildResponseCard(),
//
//             const SizedBox(height: 30),
//           ],
//         ),
//       );
//         },
//     );
//   }
//
//   Widget _getTypeIcon() {
//     switch (feedback['type']) {
//       case 'Missed Collection':
//         return Icon(Icons.delete_outline, color: primaryColor, size: 30);
//       case 'Rate Service':
//         return Icon(Icons.star_outline, color: primaryColor, size: 30);
//       case 'Suggestion':
//         return Icon(Icons.lightbulb_outline, color: primaryColor, size: 30);
//       case 'Report Issue':
//         return Icon(Icons.warning_amber_outlined, color: primaryColor, size: 30);
//       default:
//         return Icon(Icons.feedback_outlined, color: primaryColor, size: 30);
//     }
//   }
//
//   Widget _buildInfoCard() {
//     return Container(
//       margin: const EdgeInsets.only(top: 20),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//       ),
//       child: Column(
//         children: [
//           _buildInfoRow('Date', feedback['created_at'] ?? 'Unknown'),
//           const Divider(height: 24),
//           _buildInfoRow('Ward', 'Ward ${feedback['ward_number'] ?? 'Unknown'}'),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildInfoRow(String label, String value) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//       children: [
//         Text(
//           label,
//           style: TextStyle(
//             color: Colors.grey.shade700,
//             fontWeight: FontWeight.w500,
//             fontSize: 14,
//           ),
//         ),
//         Text(
//           value,
//           style: const TextStyle(
//             fontWeight: FontWeight.w600,
//             fontSize: 14,
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildRatingCard() {
//     final rating = feedback['rating'] as int;
//     return Container(
//       margin: const EdgeInsets.only(top: 20),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Your Rating',
//             style: TextStyle(
//               color: primaryColor,
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: List.generate(5, (index) {
//               return Icon(
//                 index < rating ? Icons.star : Icons.star_border,
//                 color: index < rating ? Colors.amber : Colors.grey,
//                 size: 32,
//               );
//             }),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildDescriptionCard() {
//     return Container(
//       margin: const EdgeInsets.only(top: 20),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: Colors.grey.shade50,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Description',
//             style: TextStyle(
//               color: primaryColor,
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             feedback['description'] ?? 'No description provided',
//             style: const TextStyle(
//               fontSize: 15,
//               height: 1.5,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildImageCard() {
//     return Container(
//       margin: const EdgeInsets.only(top: 20),
//       decoration: BoxDecoration(
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: Colors.grey.shade200),
//         color: Colors.grey.shade50,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Padding(
//             padding: const EdgeInsets.all(16),
//             child: Text(
//               'Attached Image',
//               style: TextStyle(
//                 color: primaryColor,
//                 fontWeight: FontWeight.bold,
//                 fontSize: 16,
//               ),
//             ),
//           ),
//           ClipRRect(
//             borderRadius: const BorderRadius.only(
//               bottomLeft: Radius.circular(12),
//               bottomRight: Radius.circular(12),
//             ),
//             child: Image.network(
//               feedback['image_url'],
//               fit: BoxFit.cover,
//               width: double.infinity,
//               height: 200,
//               errorBuilder: (context, error, stackTrace) {
//                 return Container(
//                   width: double.infinity,
//                   height: 200,
//                   color: Colors.grey.shade300,
//                   child: const Center(
//                     child: Icon(
//                       Icons.error_outline,
//                       color: Colors.grey,
//                       size: 48,
//                     ),
//                   ),
//                 );
//               },
//               loadingBuilder: (context, child, loadingProgress) {
//                 if (loadingProgress == null) return child;
//                 return Container(
//                   width: double.infinity,
//                   height: 200,
//                   color: Colors.grey.shade200,
//                   child: Center(
//                     child: CircularProgressIndicator(
//                       value: loadingProgress.expectedTotalBytes != null
//                           ? loadingProgress.cumulativeBytesLoaded /
//                           loadingProgress.expectedTotalBytes!
//                           : null,
//                       color: primaryColor,
//                     ),
//                   ),
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildResponseCard() {
//     return Container(
//       margin: const EdgeInsets.only(top: 20),
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: primaryColor.withOpacity(0.05),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: primaryColor.withOpacity(0.2)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Response from Authority',
//             style: TextStyle(
//               color: primaryColor,
//               fontWeight: FontWeight.bold,
//               fontSize: 16,
//             ),
//           ),
//           const SizedBox(height: 12),
//           Text(
//             feedback['response'] ?? 'No response yet',
//             style: const TextStyle(
//               fontSize: 15,
//               height: 1.5,
//             ),
//           ),
//           if (feedback['response_date'] != null) ...[
//             const SizedBox(height: 10),
//             Align(
//               alignment: Alignment.bottomRight,
//               child: Text(
//                 'Responded on: ${feedback['response_date']}',
//                 style: TextStyle(
//                   fontSize: 12,
//                   color: Colors.grey.shade600,
//                   fontStyle: FontStyle.italic,
//                 ),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }
//
// // Extension for Drawer menu to add feedback option
// class FeedbackDrawerItems {
//   static List<Widget> getFeedbackMenuItems(BuildContext context, Color primaryColor) {
//     return [
//       ListTile(
//         leading: Icon(Icons.feedback_outlined, color: primaryColor),
//         title: const Text('Submit Feedback'),
//         onTap: () {
//           Navigator.pop(context); // Close drawer
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => const FeedbackScreen(),
//             ),
//           );
//         },
//       ),
//       ListTile(
//         leading: Icon(Icons.history, color: primaryColor),
//         title: const Text('My Feedback'),
//         onTap: () {
//           Navigator.pop(context); // Close drawer
//           Navigator.push(
//             context,
//             MaterialPageRoute(
//               builder: (context) => FeedbackHistoryScreen(),
//             ),
//           );
//         },
//       ),
//     ];
//   }
// }
//
// // Helper method to integrate feedback items into existing drawer
// void addFeedbackMenuToDrawer(Column drawerColumn, BuildContext context, Color primaryColor) {
//   // Find the index of the divider before the logout item
//   final int dividerIndex = drawerColumn.children.indexWhere((widget) => widget is Divider);
//
//   if (dividerIndex != -1) {
//     // Insert feedback items before the divider
//     final feedbackItems = FeedbackDrawerItems.getFeedbackMenuItems(context, primaryColor);
//
//     // Create a new children list with feedback items inserted
//     final List<Widget> newChildren = [...drawerColumn.children];
//     newChildren.insertAll(dividerIndex, [...feedbackItems, const Divider()]);
//
//     // Replace the children with the new list
//     drawerColumn = Column(
//       mainAxisAlignment: drawerColumn.mainAxisAlignment,
//       children: newChildren,
//     );
//   }
// }