import 'package:flutter/material.dart';
import 'package:quick_recipe/Utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:quick_recipe/Provider/profile_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>();
    _name = TextEditingController(text: profile.name);
    _email = TextEditingController(text: profile.email);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final account = context.read<ProfileProvider>();
    if (account.busy || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final success = await account.save(name: _name.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Profile saved.'
              : account.error ?? 'Unable to save profile.',
        ),
      ),
    );
  }

  Future<void> _signOut() async {
    final account = context.read<ProfileProvider>();
    await account.signOut();
    if (!mounted) return;
    if (account.uid == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(account.error ?? 'Unable to sign out.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<ProfileProvider>();
    return Scaffold(
      backgroundColor: kbackgroundColor,
      appBar: AppBar(
        backgroundColor: kbackgroundColor,
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                Icons.account_circle_outlined,
                size: 80,
                color: kprimaryColor,
              ),
              const SizedBox(height: 24),
              const Text(
                'Your profile',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Demo profile for this app installation. Your data is stored online.'),
              const SizedBox(height: 28),
              TextFormField(
                controller: _name,
                enabled: !account.busy,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: 'Name',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Enter a name with at least 2 characters.'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _email,
                readOnly: true,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'Not required in demo mode',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: account.busy ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kprimaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: account.busy
                      ? const CircularProgressIndicator()
                      : const Text(
                          'Save profile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: account.busy ? null : _signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
