import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  List<Map<String, dynamic>> allFeedback = [];
  bool isLoading = true;
  String statusFilter = 'All';


  final Color primaryColor = const Color(0xFF3F51B5);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = const Color(0xFFF5F7FA);
  final Color cardColor = Colors.white;
  final Color inactiveColor = const Color(0xFFE57373);

  @override
  void initState() {
    super.initState();
    _fetchAllFeedback();
  }

  Future<void> _fetchAllFeedback() async {
    setState(() {
      isLoading = true;
    });

    try {
      Query query = FirebaseFirestore.instance
          .collection('feedback')
          .orderBy('created_at', descending: true);

      if (statusFilter != 'All') {
        query = query.where('status', isEqualTo: statusFilter);
      }

      final snapshot = await query.get();

      setState(() {
        allFeedback = snapshot.docs
            .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        })
            .toList();
      });
    } catch (e) {
      debugPrint("Error fetching feedback data: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _updateFeedbackStatus(String id, String status, String? response) async {
    try {
      await FirebaseFirestore.instance.collection('feedback').doc(id).update({
        'status': status,
        'admin_response': response,
        'resolved_at': status == 'Resolved' ? FieldValue.serverTimestamp() : null,
      });

      _fetchAllFeedback();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Feedback updated to $status'),
          backgroundColor: accentColor,
        ),
      );
    } catch (e) {
      debugPrint("Error updating feedback: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update feedback: $e'),
          backgroundColor: inactiveColor,
        ),
      );
    }
  }

  void _showResponseDialog(String id) {
    final TextEditingController responseController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Respond to Feedback'),
        content: TextField(
          controller: responseController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Enter your response...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateFeedbackStatus(id, 'Resolved', responseController.text);
            },
            child: Text('Resolve', style: TextStyle(color: accentColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateFeedbackStatus(id, 'Rejected', responseController.text);
            },
            child: Text('Reject', style: TextStyle(color: inactiveColor)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Feedback Management'),
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Status Filter Chips
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Resolved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Rejected'),
                ],
              ),
            ),
          ),

          // Feedback List
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: primaryColor))
                : allFeedback.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.feedback_outlined,
                    size: 70,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No feedback found',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: allFeedback.length,
              itemBuilder: (context, index) {
                final feedback = allFeedback[index];
                final Timestamp? timestamp = feedback['created_at'];
                final DateTime date = timestamp != null
                    ? timestamp.toDate()
                    : DateTime.now();
                final String formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(date);

                return Card(
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
                            _buildStatusBadge(feedback['status'] ?? 'Pending'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ward: ${feedback['ward_number'] ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'From: ${feedback['user_email']}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
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
                                  'Admin Response:',
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
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (feedback['status'] == 'Pending') ...[
                              TextButton.icon(
                                onPressed: () => _showResponseDialog(feedback['id']),
                                icon: const Icon(Icons.reply),
                                label: const Text('Respond'),
                                style: TextButton.styleFrom(
                                  foregroundColor: primaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status) {
    final isSelected = statusFilter == status;

    return FilterChip(
      label: Text(status),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          statusFilter = status;
        });
        _fetchAllFeedback();
      },
      backgroundColor: cardColor,
      selectedColor: primaryColor.withOpacity(0.2),
      checkmarkColor: primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? primaryColor : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? primaryColor : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'Resolved':
        color = accentColor;
        break;
      case 'Rejected':
        color = inactiveColor;
        break;
      case 'Pending':
        color = Colors.amber;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
