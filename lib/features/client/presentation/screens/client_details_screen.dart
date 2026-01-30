import 'package:boda_connect/core/constants/angola_locations.dart';
import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClientDetailsScreen extends ConsumerStatefulWidget {
  const ClientDetailsScreen({super.key});

  @override
  ConsumerState<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends ConsumerState<ClientDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  // Location dropdowns
  String? _selectedProvince;
  String? _selectedCity;
  List<String> _availableCities = [];

  @override
  void initState() {
    super.initState();
    _loadExistingUserData();
  }

  /// Load existing user data from Firebase Auth and Firestore
  Future<void> _loadExistingUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Pre-fill from Firebase Auth
    if (user.email != null) {
      _emailController.text = user.email!;
    }
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      _nameController.text = user.displayName!;
    }
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      _phoneController.text = user.phoneNumber!;
    }

    // Load existing data from Firestore if available
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        if (data != null) {
          // Pre-fill name if not already set
          if (_nameController.text.isEmpty && data['name'] != null) {
            _nameController.text = data['name'];
          }

          // Pre-fill phone if not already set
          if (_phoneController.text.isEmpty && data['phone'] != null) {
            _phoneController.text = data['phone'];
          }

          // Pre-fill location if available
          if (data['location'] != null) {
            final location = data['location'] as Map<String, dynamic>;
            if (location['province'] != null) {
              setState(() {
                _selectedProvince = location['province'];
                _availableCities = AngolaLocations.getCitiesForProvince(_selectedProvince!);
                if (location['city'] != null) {
                  _selectedCity = location['city'];
                }
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Check if document exists first
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await docRef.get();
      final documentExists = docSnapshot.exists;

      debugPrint('📄 Document exists: $documentExists');

      // Prepare base data
      final Map<String, dynamic> dataToSave = {
        'userType': 'client',
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : user.email,
        'phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        'photo': user.photoURL,
        'location': {
          'province': _selectedProvince ?? 'Luanda',
          'city': _selectedCity ?? 'Luanda',
          'country': 'Angola',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Only add createdAt if document doesn't exist
      if (!documentExists) {
        dataToSave['createdAt'] = FieldValue.serverTimestamp();
      }

      debugPrint('🔍 Saving client data:');
      debugPrint('  userType: "${dataToSave['userType']}"');
      debugPrint('  name: "${dataToSave['name']}"');
      debugPrint('  email: "${dataToSave['email']}"');
      debugPrint('  phone: "${dataToSave['phone']}"');
      debugPrint('  Has createdAt: ${dataToSave.containsKey('createdAt')}');

      // Save to Firestore
      if (documentExists) {
        debugPrint('📝 Updating existing document with merge');
        await docRef.set(dataToSave, SetOptions(merge: true));
      } else {
        debugPrint('✨ Creating new document');
        await docRef.set(dataToSave);
      }

      // Update Firebase Auth display name
      await user.updateDisplayName(_nameController.text.trim());

      // Refresh auth provider state with updated user data
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        // Navigate to preferences screen
        context.go(Routes.clientPreferences);
      }
    } catch (e) {
      debugPrint('❌ Error saving client details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar dados: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress Indicator
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.peach,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Title
                const Text(
                  'Seus Dados',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Preencha seus dados pessoais',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 32),

                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nome completo',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, digite seu nome';
                    }
                    if (value.trim().split(' ').length < 2) {
                      return 'Por favor, digite nome e sobrenome';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, digite seu email';
                    }
                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                        .hasMatch(value)) {
                      return 'Email inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone Field
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Telefone',
                    hintText: '+244 912 345 678',
                    prefixIcon: const Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, digite seu telefone';
                    }
                    // Basic validation - at least 9 digits
                    if (value.replaceAll(RegExp(r'[^\d]'), '').length < 9) {
                      return 'Telefone inválido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Province Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedProvince,
                  decoration: InputDecoration(
                    labelText: 'Província',
                    prefixIcon: const Icon(Icons.map_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: AngolaLocations.provinceNames
                      .map((province) => DropdownMenuItem(
                            value: province,
                            child: Text(province),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProvince = value;
                      _selectedCity = null;
                      _availableCities = value != null
                          ? AngolaLocations.getCitiesForProvince(value)
                          : [];
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, selecione uma província';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // City Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCity,
                  decoration: InputDecoration(
                    labelText: 'Cidade',
                    prefixIcon: const Icon(Icons.location_city_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: _availableCities
                      .map((city) => DropdownMenuItem(
                            value: city,
                            child: Text(city),
                          ))
                      .toList(),
                  onChanged: _selectedProvince == null
                      ? null
                      : (value) {
                          setState(() {
                            _selectedCity = value;
                          });
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor, selecione uma cidade';
                    }
                    return null;
                  },
                ),

                const Spacer(),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveAndContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.peach,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Continuar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
