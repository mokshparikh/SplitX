import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import '../features/groups/group_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ⏳ Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // ❌ NOT LOGGED IN
        if (user == null) {
          return const LoginScreen();
        }

        // ❌ EMAIL NOT VERIFIED
        if (!user.emailVerified) {
          FirebaseAuth.instance.signOut();
          return const LoginScreen();
        }

        // ✅ LOGGED IN + VERIFIED
        return const GroupScreen();
      },
    );
  }
}
