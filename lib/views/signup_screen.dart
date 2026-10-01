import 'package:provider/provider.dart';

import '../Provider/profile_provider.dart';

import 'package:flutter/material.dart';
import 'package:quick_recipe/Utils/constants.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  final _formKey = GlobalKey<FormState>();
  Future<void> _submit() async {
    final account = context.read<ProfileProvider>();
    if (account.busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = await account.authenticate(
      email: emailController.text,
      password: passwordController.text,
      name: nameController.text,
    );
    if (!mounted) return;
    if (success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demo sign-up complete. Tap Sign In to continue. No real account was created.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(account.error ?? 'Please try again.')),
      );
    }
  }

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<ProfileProvider>();
    return Scaffold(
      backgroundColor: kbackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // App title
                Center(
                  child: Text(
                    'QuickRecipe',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: kprimaryColor,
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                const Text(
                  'Create Account',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  'Try the sign-up form. This demo does not create a real account.',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),

                const SizedBox(height: 30),

                // Name
                const Text(
                  'Name',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: nameController,
                  enabled: !account.busy,
                  validator: (value) =>
                      (value ?? '').trim().length < 2 ||
                          (value ?? '').trim().length > 60
                      ? 'Name must contain 2 to 60 characters.'
                      : null,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Enter your name',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Email
                const Text(
                  'Email',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: emailController,
                  enabled: !account.busy,
                  validator: (value) =>
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch((value ?? '').trim())
                      ? null
                      : 'Enter a valid email address.',
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'Enter your email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Password
                const Text(
                  'Password',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: passwordController,
                  enabled: !account.busy,
                  validator: (value) => (value ?? '').length < 6
                      ? 'Password must contain at least 6 characters.'
                      : null,
                  textInputAction: TextInputAction.next,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: 'Create a password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Confirm Password
                const Text(
                  'Confirm Password',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),

                const SizedBox(height: 8),

                TextFormField(
                  controller: confirmPasswordController,
                  enabled: !account.busy,
                  validator: (value) => (value ?? '').isEmpty
                      ? 'Confirm your password.'
                      : value != passwordController.text
                      ? 'Passwords do not match.'
                      : null,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  obscureText: !isConfirmPasswordVisible,
                  decoration: InputDecoration(
                    hintText: 'Confirm your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isConfirmPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          isConfirmPasswordVisible = !isConfirmPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: account.busy ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kprimaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: account.busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Sign Up',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    GestureDetector(
                      onTap: account.busy
                          ? null
                          : () {
                              Navigator.pop(context);
                            },
                      child: Text(
                        'Sign In',
                        style: TextStyle(
                          color: kprimaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
