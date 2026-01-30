import 'package:boda_connect/core/constants/colors.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/category_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ClientPreferencesScreen extends ConsumerStatefulWidget {
  const ClientPreferencesScreen({super.key});

  @override
  ConsumerState<ClientPreferencesScreen> createState() =>
      _ClientPreferencesScreenState();
}

class _ClientPreferencesScreenState
    extends ConsumerState<ClientPreferencesScreen> {
  final Set<String> _selectedCategories = {};
  bool _isLoading = false;

  Future<void> _saveAndContinue() async {
    if (_selectedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, selecione pelo menos uma categoria'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Update user document with preferences
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'preferences': {
          'categories': _selectedCategories.toList(),
          'completedOnboarding': true,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Refresh auth provider state with updated user data
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        // Navigate to client home
        context.go(Routes.clientHome);
      }
    } catch (e) {
      debugPrint('❌ Error saving preferences: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar preferências: ${e.toString()}'),
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

  Future<void> _skipForNow() async {
    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'preferences': {
            'completedOnboarding': true,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Refresh auth provider state with updated user data
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        context.go(Routes.clientHome);
      }
    } catch (e) {
      debugPrint('❌ Error skipping preferences: $e');
      if (mounted) {
        context.go(Routes.clientHome);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(featuredCategoriesProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _skipForNow,
            child: const Text('Pular'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                        color: AppColors.peach,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Title
              const Text(
                'Suas Preferências',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Escolha os serviços que mais te interessam',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 32),

              // Categories Grid
              Expanded(
                child: categories.isEmpty
                    ? const Center(child: CircularProgressIndicator(color: AppColors.peach))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          final category = categories[index];
                          final isSelected = _selectedCategories.contains(category.id);

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedCategories.remove(category.id);
                                } else {
                                  _selectedCategories.add(category.id);
                                }
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.peachLight
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.peach
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    category.icon,
                                    style: const TextStyle(fontSize: 40),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    category.name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? AppColors.peach : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // Selected Count
              if (_selectedCategories.isNotEmpty)
                Center(
                  child: Text(
                    '${_selectedCategories.length} ${_selectedCategories.length == 1 ? "categoria selecionada" : "categorias selecionadas"}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 14,
                    ),
                  ),
                ),
              const SizedBox(height: 16),

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
                          'Concluir',
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
    );
  }
}
