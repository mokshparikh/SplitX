import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool _isPasswordVisible = false;

  // 🎨 COLORS FOR PREMIUM BLUE THEME
  final Color primaryColor = const Color(0xFF2D62ED); // Vibrant Modern Blue
  final Color fieldBg = const Color(0xFFF1F4F9); // Soft Blue-Grey background
  final Color textColor = const Color(0xFF1A1C1E);

  // UI Reusable Decoration
  BoxDecoration _fieldDecoration() {
    return BoxDecoration(
      color: fieldBg,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // Same logic as before...
  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) return;
    try {
      setState(() => loading = true);
      final uc = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      if (uc.user != null && !uc.user!.emailVerified) {
        await uc.user!.sendEmailVerification();
        await FirebaseAuth.instance.signOut();
        _showSnackBar('Verify your email first!');
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showSnackBar(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 80),

              // 💎 MODERN LOGO ICON
              Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [primaryColor, primaryColor.withOpacity(0.7)]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.wallet_rounded,
                    color: Colors.white, size: 30),
              ),

              const SizedBox(height: 30),
              Text('Welcome Back',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -1)),
              const Text('Enter your details to access your account',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),

              const SizedBox(height: 50),

              // --- PREMIUM EMAIL FIELD ---
              Container(
                decoration: _fieldDecoration(),
                child: TextField(
                  controller: emailController,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    labelStyle:
                        const TextStyle(color: Colors.blueGrey, fontSize: 14),
                    prefixIcon: Icon(Icons.alternate_email_rounded,
                        color: primaryColor),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 20),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --- PREMIUM PASSWORD FIELD ---
              Container(
                decoration: _fieldDecoration(),
                child: TextField(
                  controller: passwordController,
                  obscureText: !_isPasswordVisible,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle:
                        const TextStyle(color: Colors.blueGrey, fontSize: 14),
                    prefixIcon:
                        Icon(Icons.lock_outline_rounded, color: primaryColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          size: 20),
                      onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 20),
                  ),
                ),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: Text('Forgot Password?',
                      style: TextStyle(
                          color: primaryColor, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 35),

              // 🚀 MODERN BUTTON
              Container(
                width: double.infinity,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 0,
                  ),
                  onPressed: loading ? null : login,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Sign In',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                ),
              ),

              const SizedBox(height: 40),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SignupScreen())),
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                      children: [
                        TextSpan(
                            text: "Sign Up",
                            style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
