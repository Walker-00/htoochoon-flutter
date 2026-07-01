// ─────────────────────────────────────────────────────────────────────────────
// PATCH: Replace your existing _openAdminShell method with this.
// This detects the current user's role in the org and routes to the
// appropriate shell (AdminShell for ADMIN/OWNER, TeacherShell for TEACHER).
//
// Add this import at the top of the file:
//   import 'package:htoochoon_flutter/Screens/TeacherScreens/teacher_shell.dart';
// ─────────────────────────────────────────────────────────────────────────────
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/Providers/AdminProviders/organisation_provider.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/admin_shell.dart';
import 'package:htoochoon_flutter/Screens/TeacherScreens/teacher_shell.dart';
import 'package:htoochoon_flutter/models/api_models/organization_model.dart';
// ─────────────────────────────────────────────────────────────────────────────
// PATCH: Replace your existing _openAdminShell method with this.
//
// Imports to add at the top of your home/org screen file:
//   import 'package:htoochoon_flutter/Screens/TeacherScreens/teacher_shell.dart';
//   import 'package:htoochoon_flutter/models/api_models/enums.dart';
// ─────────────────────────────────────────────────────────────────────────────
//
// Future<void> _openAdminShell(
//     BuildContext context,
//     OrganizationResponse org,
//     OrganizationProvider orgProv,
//     ) async {
//   logD("opened org shell: ${org.id}");
//
//   orgProv.setSelected(org);
//   await Future.delayed(const Duration(milliseconds: 50));
//
//   if (!context.mounted) return;
//   if (orgProv.error != null) {
//     logD("Navigation blocked due to error: ${orgProv.error}");
//     return;
//   }
//
//   final role = orgProv.getOrgRole(org.id);
//   logD("User role in org ${org.id}: $role");
//
//   WidgetsBinding.instance.addPostFrameCallback((_) {
//     if (!context.mounted) return;
//
//     final onQuit = () {
//       orgProv.leaveOrganisation();
//       Navigator.of(context).pop();
//     };
//
//     Widget shell;
//
//     switch (role) {
//       case Role.TEACHER:
//         shell = TeacherShell(
//           organisationId: org.id,
//           onQuitOrganisation: onQuit,
//         );
//         break;
//
//       case Role.ORG_ADMIN:
//         shell = AdminShell(
//           organisationId: org.id,
//           onQuitOrganisation: onQuit,
//         );
//         break;
//
//     // STUDENT, STAFF, USER — no shell yet, block entry
//       case Role.STUDENT:
//       case Role.STAFF:
//       case Role.USER:
//       default:
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text(
//               "You don't have admin or teacher access to this organisation.",
//             ),
//             behavior: SnackBarBehavior.floating,
//           ),
//         );
//         return;
//     }
//
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => shell),
//     );
//   });
// }

// ─────────────────────────────────────────────────────────────────────────────
// NOTES:
//
// 1. Role source: UserSessionManager.orgRole(orgId) → Role enum
//    This is already what orgProv.getOrgRole(org.id) calls.
//    Make sure UserSessionManager is populated after login (looks like it is
//    via loadMe() / getUser() in AuthProvider).
//
// 2. TeacherShell imports to add at the top of your home/org screen file:
//    import 'package:htoochoon_flutter/Screens/TeacherScreens/teacher_shell.dart';
//
// 3. File locations — place these files in your project:
//    lib/Screens/TeacherScreens/
//      ├── teacher_shell.dart
//      ├── teacher_dashboard_screen.dart
//      ├── teacher_programs_screen.dart
//      └── teacher_classes_screen.dart
//
// 4. ClassProvider must be registered in your MultiProvider tree.
//    It should already be there since ClassesScreen in AdminShell uses it.
//
// 5. When TeacherAssignment API is ready, update TeacherProgramsScreen to
//    filter programs by teacher assignment instead of showing all org programs.
//    Add a method to ProgramsProvider like:
//      Future<void> fetchProgramsByTeacher(String orgId, String teacherId)
//    and call the new endpoint.
//
// 6. ClassroomScreen navigation in teacher_classes_screen.dart is commented out
//    with a TODO. Uncomment and point to your actual ClassroomScreen when ready.
// ─────────────────────────────────────────────────────────────────────────────
