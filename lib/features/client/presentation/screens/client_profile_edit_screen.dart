import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/constants/angola_locations.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/constants/dimensions.dart';
import '../../../../core/constants/text_styles.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/location_service.dart';

class ClientProfileEditScreen extends ConsumerStatefulWidget {
  const ClientProfileEditScreen({super.key});

  @override
  ConsumerState<ClientProfileEditScreen> createState() => _ClientProfileEditScreenState();
}

class _ClientProfileEditScreenState extends ConsumerState<ClientProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  // Location dropdowns
  String? _selectedProvince;
  String? _selectedCity;
  List<String> _availableCities = [];

  // Additional profile fields
  DateTime? _dateOfBirth;
  String? _gender;
  String _preferredContact = 'phone'; // phone, email, whatsapp
  List<String> _eventInterests = [];

  // Event interest options
  static const List<String> _eventOptions = [
    'Casamentos',
    'Aniversários',
    'Eventos Corporativos',
    'Batizados',
    'Noivados',
    'Festas de Formatura',
    'Chá de Bebê',
    'Outros',
  ];

  ({XFile file, Uint8List bytes})? _selectedImage;
  String? _currentPhotoUrl;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDetectingLocation = false;
  Position? _currentPosition;
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Detect current location using GPS
  Future<void> _detectCurrentLocation() async {
    setState(() => _isDetectingLocation = true);

    try {
      // Check and request permission
      final hasPermission = await _locationService.checkLocationPermission();

      if (!hasPermission) {
        if (mounted) {
          // Show dialog to open settings
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Permissão de Localização'),
              content: const Text(
                'Para detectar sua localização automaticamente, '
                'precisamos de permissão de acesso à localização. '
                'Deseja abrir as configurações?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Abrir Configurações'),
                ),
              ],
            ),
          );

          if (shouldOpenSettings == true) {
            await _locationService.openAppSettings();
          }
        }
        return;
      }

      // Get current position
      final position = await _locationService.getCurrentLocation();

      if (position != null && mounted) {
        setState(() {
          _currentPosition = position;
        });

        // For now, we'll set Luanda as default since reverse geocoding requires additional setup
        // In a full implementation, you would use a geocoding API to get city/province from coordinates
        // The coordinates are still saved to Firestore for distance calculations

        // Try to find the closest province based on approximate coordinates
        final detectedProvince = _getProvinceFromCoordinates(position.latitude, position.longitude);

        if (detectedProvince != null) {
          setState(() {
            _selectedProvince = detectedProvince;
            _availableCities = AngolaLocations.getCitiesForProvince(detectedProvince);
            // Select the first city (usually the capital of the province)
            if (_availableCities.isNotEmpty) {
              _selectedCity = _availableCities.first;
            }
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              detectedProvince != null
                  ? 'Localização detectada: $_selectedProvince'
                  : 'Coordenadas detectadas. Selecione sua província manualmente.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível obter sua localização'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error detecting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao detectar localização: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDetectingLocation = false);
      }
    }
  }

  /// Get province from coordinates (approximate matching for Angola)
  String? _getProvinceFromCoordinates(double lat, double lng) {
    // Approximate center coordinates for Angola provinces
    // These are rough estimates for demonstration
    final provinceCoordinates = {
      'Luanda': {'lat': -8.839, 'lng': 13.289},
      'Benguela': {'lat': -12.578, 'lng': 13.405},
      'Huambo': {'lat': -12.776, 'lng': 15.739},
      'Cabinda': {'lat': -5.55, 'lng': 12.20},
      'Huíla': {'lat': -14.916, 'lng': 13.536},
      'Cunene': {'lat': -16.533, 'lng': 16.033},
      'Namibe': {'lat': -15.196, 'lng': 12.152},
      'Bié': {'lat': -12.383, 'lng': 17.667},
      'Moxico': {'lat': -11.433, 'lng': 22.333},
      'Cuando Cubango': {'lat': -15.75, 'lng': 18.50},
      'Lunda Norte': {'lat': -8.417, 'lng': 19.917},
      'Lunda Sul': {'lat': -10.717, 'lng': 20.400},
      'Malanje': {'lat': -9.540, 'lng': 16.341},
      'Kwanza Norte': {'lat': -9.133, 'lng': 14.983},
      'Kwanza Sul': {'lat': -11.083, 'lng': 14.917},
      'Uíge': {'lat': -7.609, 'lng': 15.062},
      'Zaire': {'lat': -6.133, 'lng': 14.233},
      'Bengo': {'lat': -8.45, 'lng': 13.55},
    };

    String? closestProvince;
    double minDistance = double.infinity;

    for (final entry in provinceCoordinates.entries) {
      final pLat = entry.value['lat']!;
      final pLng = entry.value['lng']!;

      // Calculate simple distance (not accurate but good enough for province detection)
      final distance = _calculateSimpleDistance(lat, lng, pLat, pLng);

      if (distance < minDistance) {
        minDistance = distance;
        closestProvince = entry.key;
      }
    }

    // Only return if reasonably close (within ~3 degrees which is roughly 300km)
    if (minDistance < 3.0) {
      return closestProvince;
    }

    return null;
  }

  double _calculateSimpleDistance(double lat1, double lng1, double lat2, double lng2) {
    return ((lat1 - lat2).abs() + (lng1 - lng2).abs());
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

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
    _currentPhotoUrl = user.photoURL;

    // Load existing data from Firestore
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        if (data != null) {
          setState(() {
            if (data['name'] != null && data['name'].toString().isNotEmpty) {
              _nameController.text = data['name'];
            }
            if (data['phone'] != null && _phoneController.text.isEmpty) {
              _phoneController.text = data['phone'];
            }
            if (data['email'] != null && _emailController.text.isEmpty) {
              _emailController.text = data['email'];
            }
            if (data['photoUrl'] != null) {
              _currentPhotoUrl = data['photoUrl'];
            }

            // Load location
            if (data['location'] != null) {
              final location = data['location'] as Map<String, dynamic>;
              if (location['province'] != null) {
                _selectedProvince = location['province'];
                _availableCities = AngolaLocations.getCitiesForProvince(_selectedProvince!);
                if (location['city'] != null) {
                  _selectedCity = location['city'];
                }
              }
            }

            // Load additional profile fields
            if (data['bio'] != null) {
              _bioController.text = data['bio'];
            }
            if (data['dateOfBirth'] != null) {
              _dateOfBirth = (data['dateOfBirth'] as Timestamp).toDate();
            }
            if (data['gender'] != null) {
              _gender = data['gender'];
            }
            if (data['preferredContact'] != null) {
              _preferredContact = data['preferredContact'];
            }
            if (data['eventInterests'] != null) {
              _eventInterests = List<String>.from(data['eventInterests']);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = (file: image, bytes: bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao selecionar imagem: $e')),
        );
      }
    }
  }

  Future<String?> _uploadProfilePhoto(Uint8List bytes) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('profile.jpg');

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No authenticated user');
      }

      // Upload profile photo if selected
      String? newPhotoUrl;
      if (_selectedImage != null) {
        newPhotoUrl = await _uploadProfilePhoto(_selectedImage!.bytes);
      }

      // Build location data with optional geopoint
      final locationData = <String, dynamic>{
        'province': _selectedProvince,
        'city': _selectedCity,
        'country': 'Angola',
      };

      // Include geopoint if we have GPS coordinates
      if (_currentPosition != null) {
        locationData['geopoint'] = GeoPoint(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
        );
        locationData['lastUpdated'] = FieldValue.serverTimestamp();
      }

      // Update user document in Firestore
      final updateData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'phone': _phoneController.text.trim(),
        'location': locationData,
        'bio': _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
        'dateOfBirth': _dateOfBirth != null ? Timestamp.fromDate(_dateOfBirth!) : null,
        'gender': _gender,
        'preferredContact': _preferredContact,
        'eventInterests': _eventInterests.isNotEmpty ? _eventInterests : null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newPhotoUrl != null) {
        updateData['photoUrl'] = newPhotoUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      // Update Firebase Auth display name
      await user.updateDisplayName(_nameController.text.trim());

      // Update Firebase Auth photo if changed
      if (newPhotoUrl != null) {
        await user.updatePhotoURL(newPhotoUrl);
      }

      // Refresh auth provider to update UI immediately
      await ref.read(authProvider.notifier).refreshUser();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil atualizado com sucesso'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar perfil: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)), // At least 16 years old
      helpText: 'Selecione sua data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.peach,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: const Text(
                'Guardar',
                style: TextStyle(
                  color: AppColors.peach,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.md),
                children: [
                  // Profile Image
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.peach.withAlpha((0.2 * 255).toInt()),
                          backgroundImage: _selectedImage != null
                              ? MemoryImage(_selectedImage!.bytes) as ImageProvider
                              : (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty)
                                  ? NetworkImage(_currentPhotoUrl!) as ImageProvider
                                  : null,
                          child: _selectedImage == null && (_currentPhotoUrl == null || _currentPhotoUrl!.isEmpty)
                              ? const Icon(Icons.person, size: 48, color: AppColors.peach)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.peach,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Name
                  Text('Nome Completo', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'Ex: João Manuel Silva',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 20),

                  // Phone
                  Text('Telefone', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+244 923 456 789',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (value) => value?.isEmpty ?? true ? 'Campo obrigatório' : null,
                  ),
                  const SizedBox(height: 20),

                  // Email
                  Text('Email', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'seu@email.com',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // PERSONAL INFO SECTION
                  Text(
                    'INFORMAÇÕES PESSOAIS',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth
                  Text('Data de Nascimento', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _selectDateOfBirth,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.cake),
                        hintText: 'Selecione sua data de nascimento',
                      ),
                      child: Text(
                        _dateOfBirth != null
                            ? '${_dateOfBirth!.day.toString().padLeft(2, '0')}/${_dateOfBirth!.month.toString().padLeft(2, '0')}/${_dateOfBirth!.year}'
                            : 'Selecione sua data de nascimento',
                        style: TextStyle(
                          color: _dateOfBirth != null ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Gender
                  Text('Gênero', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.person_outline),
                      hintText: 'Selecione seu gênero',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'masculino', child: Text('Masculino')),
                      DropdownMenuItem(value: 'feminino', child: Text('Feminino')),
                      DropdownMenuItem(value: 'outro', child: Text('Outro')),
                      DropdownMenuItem(value: 'prefiro_nao_dizer', child: Text('Prefiro não dizer')),
                    ],
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                  const SizedBox(height: 20),

                  // Bio
                  Text('Sobre Você (Opcional)', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _bioController,
                    maxLines: 3,
                    maxLength: 250,
                    decoration: const InputDecoration(
                      hintText: 'Conte um pouco sobre você e seus eventos...',
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 50),
                        child: Icon(Icons.edit_note),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // PREFERENCES SECTION
                  Text(
                    'PREFERÊNCIAS',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Preferred Contact Method
                  Text('Forma de Contato Preferida', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          title: const Text('Telefone'),
                          subtitle: const Text('Ligações e SMS'),
                          value: 'phone',
                          groupValue: _preferredContact,
                          activeColor: AppColors.peach,
                          onChanged: (value) => setState(() => _preferredContact = value!),
                        ),
                        const Divider(height: 1),
                        RadioListTile<String>(
                          title: const Text('WhatsApp'),
                          subtitle: const Text('Mensagens via WhatsApp'),
                          value: 'whatsapp',
                          groupValue: _preferredContact,
                          activeColor: AppColors.peach,
                          onChanged: (value) => setState(() => _preferredContact = value!),
                        ),
                        const Divider(height: 1),
                        RadioListTile<String>(
                          title: const Text('Email'),
                          subtitle: const Text('Comunicação por email'),
                          value: 'email',
                          groupValue: _preferredContact,
                          activeColor: AppColors.peach,
                          onChanged: (value) => setState(() => _preferredContact = value!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Event Interests
                  Text('Tipos de Eventos de Interesse', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(
                    'Selecione os tipos de eventos que você geralmente planeja',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _eventOptions.map((event) {
                      final isSelected = _eventInterests.contains(event);
                      return FilterChip(
                        label: Text(event),
                        selected: isSelected,
                        selectedColor: AppColors.peach.withValues(alpha: 0.2),
                        checkmarkColor: AppColors.peach,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.peach : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _eventInterests.add(event);
                            } else {
                              _eventInterests.remove(event);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // LOCATION SECTION
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LOCALIZAÇÃO',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                          letterSpacing: 1.2,
                        ),
                      ),
                      // Detect Location Button
                      TextButton.icon(
                        onPressed: _isDetectingLocation ? null : _detectCurrentLocation,
                        icon: _isDetectingLocation
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.peach,
                                ),
                              )
                            : const Icon(Icons.my_location, size: 18),
                        label: Text(_isDetectingLocation ? 'Detectando...' : 'Usar GPS'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.peach,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Province Dropdown
                  Text('Província', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedProvince,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.map),
                      hintText: 'Selecione a província',
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
                  ),
                  const SizedBox(height: 20),

                  // City Dropdown
                  Text('Cidade', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCity,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.location_city),
                      hintText: 'Selecione a cidade',
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
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
