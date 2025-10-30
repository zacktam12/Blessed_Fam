import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/utils/flash.dart';

class AdminCreateUserScreen extends ConsumerStatefulWidget {
  const AdminCreateUserScreen({super.key});

  @override
  ConsumerState<AdminCreateUserScreen> createState() => _AdminCreateUserScreenState();
}

class _AdminCreateUserScreenState extends ConsumerState<AdminCreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'member';
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  Future<void> _createUser() async {
    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authRepositoryProvider).createUserAsAdmin(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
            role: _selectedRole,
          );

      if (mounted) {
        showTopSuccess(context, 'User created successfully');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().toLowerCase();
        String message;
        
        if (errorMsg.contains('already registered') || errorMsg.contains('already exists')) {
          message = 'This email is already registered';
        } else if (errorMsg.contains('network') || errorMsg.contains('connection')) {
          message = 'Network error. Please check your connection.';
        } else if (errorMsg.contains('permission') || errorMsg.contains('denied')) {
          message = 'You do not have permission to create users';
        } else {
          message = 'Failed to create user. Please try again.';
        }
        
        showTopError(context, message);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New User'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Create a new user account. The user will be able to sign in immediately.',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Email field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                  helperText: 'User will use this email to sign in',
                ),
                validator: _validateEmail,
                textInputAction: TextInputAction.next,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // Password field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: const OutlineInputBorder(),
                  helperText: 'Min 6 chars, 1 uppercase, 1 number',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: _validatePassword,
                textInputAction: TextInputAction.next,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 16),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                  helperText: 'Display name for the user',
                ),
                validator: _validateName,
                textInputAction: TextInputAction.done,
                enabled: !_isLoading,
              ),
              const SizedBox(height: 24),

              // Role selection
              Text(
                'User Role',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Member'),
                      subtitle: const Text('Regular user access'),
                      value: 'member',
                      groupValue: _selectedRole,
                      onChanged: _isLoading ? null : (value) {
                        setState(() => _selectedRole = value!);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _selectedRole == 'member' 
                              ? colorScheme.primary 
                              : colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Admin'),
                      subtitle: const Text('Full access'),
                      value: 'admin',
                      groupValue: _selectedRole,
                      onChanged: _isLoading ? null : (value) {
                        setState(() => _selectedRole = value!);
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color: _selectedRole == 'admin' 
                              ? colorScheme.primary 
                              : colorScheme.outline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Create button
              FilledButton.icon(
                onPressed: _isLoading ? null : _createUser,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add),
                label: Text(_isLoading ? 'Creating...' : 'Create User'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
