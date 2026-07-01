//
// class LogisterParent extends StatefulWidget {
//   const LogisterParent({Key? key}) : super(key: key);
//
//   @override
//   State<LogisterParent> createState() => _LogisterParentState();
// }
//
// class _LogisterParentState extends State<LogisterParent> {
//   bool showLoginPage = true;
//   late LoginProvider loginProvider;
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     loginProvider = Provider.of<LoginProvider>(context);
//   }
//
//   void togglePage() {
//     setState(() {
//       showLoginPage = !showLoginPage;
//     });
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }
//
//         if (snapshot.hasError) {
//           return Scaffold(
//             body: Center(child: Text('Error: ${snapshot.error}')),
//           );
//         }
//
//         User? user = snapshot.data;
//
//         if (user != null) {
//           return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//             future: loginProvider.fetchUserDocument(user.uid),
//             builder: (context, userDocSnapshot) {
//               if (userDocSnapshot.connectionState == ConnectionState.waiting) {
//                 return const Scaffold(
//                   body: Center(child: CircularProgressIndicator()),
//                 );
//               }
//
//               if (userDocSnapshot.hasError || !userDocSnapshot.hasData) {
//                 return Scaffold(
//                   body: Center(child: Text('Error loading user data')),
//                 );
//               }
//
//               final data = userDocSnapshot.data?.data();
//               if (data == null) {
//                 return Scaffold(
//                   body: Center(child: Text('User data not found')),
//                 );
//               }
//
//               String role = data['role'] ?? 'user';
//               String plan = data['plan'] ?? 'free';
//               String? userType = data['userType'];
//
//               WidgetsBinding.instance.addPostFrameCallback((_) {
//                 if (!mounted) return;
//
//                 if (role == 'org') {
//                   Navigator.pushReplacement(
//                     context,
//                     MaterialPageRoute(
//                       builder: (_) => const MainDashboardWrapper(),
//                     ),
//                   );
//                 } else if (role == 'user') {
//                   if (userType == "student" || userType == "teacher") {
//                     Navigator.pushReplacement(
//                       context,
//                       MaterialPageRoute(builder: (_) => FreeUserHome()),
//                     );
//                   } else {
//                     Navigator.pushReplacement(
//                       context,
//                       MaterialPageRoute(builder: (_) => StudentORTeacherPage()),
//                     );
//                   }
//                 }
//               });
//
//               // RETURN a temporary widget while navigating
//               return const Scaffold(
//                 body: Center(child: CircularProgressIndicator()),
//               );
//             },
//           );
//         } else {
//           return LoginScreen();
//         }
//       },
//     );
//   }
// }
//
// class LogisterParent extends StatefulWidget {
//   const LogisterParent({Key? key}) : super(key: key);
//
//   @override
//   State<LogisterParent> createState() => _LogisterParentState();
// }
//
// class _LogisterParentState extends State<LogisterParent> {
//   late LoginProvider loginProvider;
//
//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     loginProvider = Provider.of<LoginProvider>(context, listen: false);
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<User?>(
//       stream: FirebaseAuth.instance.authStateChanges(),
//       builder: (context, authSnapshot) {
//         if (authSnapshot.connectionState == ConnectionState.waiting) {
//           return const _FullScreenLoader();
//         }
//
//         if (authSnapshot.hasError) {
//           return _ErrorScreen(authSnapshot.error.toString());
//         }
//
//         final user = authSnapshot.data;
//
//         if (user == null) {
//           return const LoginScreen();
//         }
//
//         return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//           future: loginProvider.fetchUserDocument(user.uid),
//           builder: (context, userDocSnapshot) {
//             if (userDocSnapshot.connectionState == ConnectionState.waiting) {
//               return const _FullScreenLoader();
//             }
//
//             if (userDocSnapshot.hasError) {
//               return const _ErrorScreen("Failed to load user profile");
//             }
//
//             final data = userDocSnapshot.data?.data();
//             if (data == null) {
//               return const _ErrorScreen("User data not found");
//             }
//
//             final role = data['role'] ?? 'user';
//             final userType = data['userType'];
//
//             if (role == 'org') {
//               return MainDashboardWrapper(currentOrgID:  orgProvider.currentOrgId,);
//             }
//
//             if (role == 'user') {
//               if (userType == 'student' || userType == 'teacher') {
//                 return const FreeUserHome();
//               }
//               return const StudentORTeacherPage();
//             }
//
//             return const LoginScreen();
//           },
//         );
//       },
//     );
//   }
// }
//
// class _FullScreenLoader extends StatelessWidget {
//   const _FullScreenLoader();
//
//   @override
//   Widget build(BuildContext context) {
//     return const Scaffold(body: Center(child: CircularProgressIndicator()));
//   }
// }
//
// class _ErrorScreen extends StatelessWidget {
//   final String message;
//   const _ErrorScreen(this.message);
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(body: Center(child: Text(message)));
//   }
// }
