import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/enrollment_provider.dart';
import 'package:htoochoon_flutter/models/api_models/enrollment_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PendingApprovalsScreen extends StatefulWidget {
  final String orgId;
  final bool isInShell;
  const PendingApprovalsScreen({
    super.key,
    required this.orgId,
    this.isInShell = false,
  });

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  @override
  void initState() {
    super.initState();
    // Load incoming pending requests on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnrollmentProvider>().fetchProgramEnrollments(
        status: EnrollmentStatus.PENDING,
        organizationId: widget.orgId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isInShell,

        title: const Text('Pending Enrollment Requests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                context.read<EnrollmentProvider>().fetchProgramEnrollments(
                  status: EnrollmentStatus.PENDING,
                  organizationId: widget.orgId,
                ),
          ),
        ],
      ),
      body: Consumer<EnrollmentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.programEnrollments.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.programEnrollments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'All caught up!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'No pending enrollment requests.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.programEnrollments.length,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemBuilder: (context, index) {
              final enrollment = provider.programEnrollments[index];

              // Safely extract names matching your response footprint
              final userName = enrollment.user?.name ?? 'Unknown User';
              final userEmail = enrollment.user?.email ?? '';
              final programName = enrollment.program?.name ?? 'Unknown Program';
              final academyName =
                  enrollment.program?.organizationName ?? 'Academy';

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: User requesting access
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              userName.isNotEmpty
                                  ? userName[0].toUpperCase()
                                  : '?',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  userEmail,
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildPendingBadge(),
                        ],
                      ),
                      const Divider(height: 24),

                      // Target Program Information
                      const Text(
                        'REQUESTED PROGRAM',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.1,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        programName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      Text(
                        'via $academyName',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Actions Panel
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              // Optional: add your rejection/denial logic or PATCH logic here
                            },
                            child: const Text(
                              'Deny',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                            ),
                            label: const Text('Approve Access'),
                            onPressed: () => _processApproval(
                              context,
                              enrollment.id,
                              userName,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPendingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'PENDING',
        style: TextStyle(
          color: Colors.amber.shade900,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Future<void> _processApproval(
    BuildContext context,
    String enrollmentId,
    String userName,
  ) async {
    // Standard quick confirmation overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await context
        .read<EnrollmentProvider>()
        .acceptProgramEnrollment(enrollmentId);

    if (mounted) {
      Navigator.pop(context); // Kill indicator

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access granted to $userName! Status set to ACTIVE.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorMsg =
            context.read<EnrollmentProvider>().error ?? 'Unknown update error';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $errorMsg'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
