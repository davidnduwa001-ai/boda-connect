import 'package:boda_connect/core/models/supplier_model.dart';
import 'package:boda_connect/core/providers/auth_provider.dart';
import 'package:boda_connect/core/providers/supplier_provider.dart';
import 'package:boda_connect/core/routing/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;

  @override
  void initState() {
    super.initState();

    // Logo animation
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );

    // Text fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _textOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _fadeController.forward();
    });

    // Navigate after 5 seconds delay - check auth and suspension status
    Future.delayed(const Duration(seconds: 5), () async {
      if (mounted) {
        final authState = ref.read(authProvider);

        if (authState.isAuthenticated && authState.user != null) {
          // Check if user is suspended
          if (!authState.user!.isActive) {
            context.go(Routes.suspendedAccount);
          } else {
            // Navigate based on user type
            if (authState.isClient) {
              context.go(Routes.clientHome);
            } else if (authState.isSupplier) {
              // Check supplier account status before allowing dashboard access
              await ref.read(supplierProvider.notifier).loadCurrentSupplier();
              final supplier = ref.read(supplierProvider).currentSupplier;

              if (mounted) {
                if (supplier == null) {
                  // Supplier document doesn't exist yet or failed to load
                  // This can happen if registration was incomplete or just finished
                  debugPrint('⚠️ Supplier document not found, retrying...');
                  await Future.delayed(const Duration(milliseconds: 500));
                  await ref.read(supplierProvider.notifier).loadCurrentSupplier();
                  final retrySupplier = ref.read(supplierProvider).currentSupplier;

                  if (mounted) {
                    if (retrySupplier == null) {
                      // Still no supplier - go to verification pending which handles loading
                      debugPrint('⚠️ Supplier not found after retry, going to verification pending');
                      context.go(Routes.supplierVerificationPending);
                    } else if (retrySupplier.accountStatus != SupplierAccountStatus.active) {
                      context.go(Routes.supplierVerificationPending);
                    } else {
                      context.go(Routes.supplierDashboard);
                    }
                  }
                } else if (supplier.accountStatus != SupplierAccountStatus.active) {
                  // Redirect to verification pending screen
                  context.go(Routes.supplierVerificationPending);
                } else {
                  context.go(Routes.supplierDashboard);
                }
              }
            } else {
              context.go(Routes.welcome);
            }
          }
        } else {
          context.go(Routes.welcome);
        }
      }
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.white,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value,
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: Image.asset(
                        'assets/images/boda_logo.png',
                        width: 280,
                        height: 120,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Fallback text logo matching the design
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // B with box
                                  Container(
                                    width: 50,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC8626B),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      'B',
                                      style: TextStyle(
                                        fontSize: 40,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'ODA',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFC8626B),
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'CONNECT',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w300,
                                  color: const Color(0xFFC8626B)
                                      .withValues(alpha: 0.6),
                                  letterSpacing: 12,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // Tagline
              FadeTransition(
                opacity: _textOpacity,
                child: Text(
                  'Conectando sonhos a fornecedores de\neventos em Angola',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.grey[600],
                    height: 1.5,
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
