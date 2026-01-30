class AppUser { // client | supplier
  const AppUser({
    required this.id,
    required this.role,
    this.phone,
  });
  final String id;
  final String? phone;
  final String role;
}
