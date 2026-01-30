/// Angola Geographic Locations
///
/// This file contains all provinces, major cities, and municipalities in Angola
/// to support location-based features throughout the app.

class AngolaLocations {
  // Country
  static const String country = 'Angola';

  // All 18 provinces of Angola
  static const List<Province> provinces = [
    Province(name: 'Luanda', capital: 'Luanda', region: 'North'),
    Province(name: 'Bengo', capital: 'Caxito', region: 'North'),
    Province(name: 'Benguela', capital: 'Benguela', region: 'Central'),
    Province(name: 'Bié', capital: 'Kuito', region: 'Central'),
    Province(name: 'Cabinda', capital: 'Cabinda', region: 'North'),
    Province(name: 'Cuando Cubango', capital: 'Menongue', region: 'South'),
    Province(name: 'Cuanza Norte', capital: 'N\'dalatando', region: 'North'),
    Province(name: 'Cuanza Sul', capital: 'Sumbe', region: 'Central'),
    Province(name: 'Cunene', capital: 'Ondjiva', region: 'South'),
    Province(name: 'Huambo', capital: 'Huambo', region: 'Central'),
    Province(name: 'Huíla', capital: 'Lubango', region: 'South'),
    Province(name: 'Lunda Norte', capital: 'Dundo', region: 'East'),
    Province(name: 'Lunda Sul', capital: 'Saurimo', region: 'East'),
    Province(name: 'Malanje', capital: 'Malanje', region: 'North'),
    Province(name: 'Moxico', capital: 'Luena', region: 'East'),
    Province(name: 'Namibe', capital: 'Namibe', region: 'South'),
    Province(name: 'Uíge', capital: 'Uíge', region: 'North'),
    Province(name: 'Zaire', capital: 'M\'banza-Kongo', region: 'North'),
  ];

  // Major cities in Luanda Province
  static const List<String> luandaCities = [
    'Luanda',
    'Viana',
    'Cacuaco',
    'Cazenga',
    'Talatona',
    'Kilamba',
    'Belas',
    'Benfica',
    'Maianga',
    'Ingombota',
    'Samba',
    'Rangel',
  ];

  // Major cities by province (most populous/important ones)
  static const Map<String, List<String>> citiesByProvince = {
    'Luanda': [
      'Luanda',
      'Viana',
      'Cacuaco',
      'Cazenga',
      'Talatona',
      'Kilamba',
      'Belas',
    ],
    'Bengo': [
      'Caxito',
      'Catete',
      'Muxima',
      'Barra do Dande',
    ],
    'Benguela': [
      'Benguela',
      'Lobito',
      'Catumbela',
      'Baía Farta',
    ],
    'Bié': [
      'Kuito',
      'Andulo',
      'Camacupa',
    ],
    'Cabinda': [
      'Cabinda',
      'Cacongo',
      'Landana',
    ],
    'Cuando Cubango': [
      'Menongue',
      'Cuito Cuanavale',
      'Dirico',
    ],
    'Cuanza Norte': [
      'N\'dalatando',
      'Cazengo',
      'Lucala',
    ],
    'Cuanza Sul': [
      'Sumbe',
      'Gabela',
      'Porto Amboim',
      'Libolo',
    ],
    'Cunene': [
      'Ondjiva',
      'Cahama',
      'Namacunde',
    ],
    'Huambo': [
      'Huambo',
      'Caála',
      'Longonjo',
      'Bailundo',
    ],
    'Huíla': [
      'Lubango',
      'Chibia',
      'Matala',
      'Humpata',
    ],
    'Lunda Norte': [
      'Dundo',
      'Lucapa',
      'Cambulo',
    ],
    'Lunda Sul': [
      'Saurimo',
      'Cacolo',
      'Dala',
    ],
    'Malanje': [
      'Malanje',
      'Cacuso',
      'Kalandula',
    ],
    'Moxico': [
      'Luena',
      'Lumeje',
      'Luau',
    ],
    'Namibe': [
      'Namibe',
      'Tombwa',
      'Bibala',
    ],
    'Uíge': [
      'Uíge',
      'Negage',
      'Maquela do Zombo',
    ],
    'Zaire': [
      'M\'banza-Kongo',
      'Soyo',
      'Nzeto',
    ],
  };

  /// Get list of all province names
  static List<String> get provinceNames => provinces.map((p) => p.name).toList();

  /// Get list of all major cities across Angola
  static List<String> get allMajorCities {
    final cities = <String>[];
    citiesByProvince.values.forEach((cityList) {
      cities.addAll(cityList);
    });
    return cities;
  }

  /// Get cities for a specific province
  static List<String> getCitiesForProvince(String provinceName) {
    return citiesByProvince[provinceName] ?? [];
  }

  /// Get province for a city (reverse lookup)
  static String? getProvinceForCity(String cityName) {
    for (final entry in citiesByProvince.entries) {
      if (entry.value.any((city) => city.toLowerCase() == cityName.toLowerCase())) {
        return entry.key;
      }
    }
    return null;
  }

  /// Get province by name
  static Province? getProvince(String provinceName) {
    try {
      return provinces.firstWhere(
        (p) => p.name.toLowerCase() == provinceName.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get provinces by region
  static List<Province> getProvincesByRegion(String region) {
    return provinces.where((p) => p.region == region).toList();
  }

  /// Get all regions
  static List<String> get regions => ['North', 'Central', 'South', 'East'];
}

/// Province data model
class Province {
  final String name;
  final String capital;
  final String region; // North, Central, South, East

  const Province({
    required this.name,
    required this.capital,
    required this.region,
  });

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Province &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;
}

/// Helper extension for easy access
extension StringLocationExtension on String {
  /// Check if this string is a valid Angola province
  bool get isAngolaProvince => AngolaLocations.provinceNames.contains(this);

  /// Check if this string is a valid Angola city
  bool get isAngolaCity => AngolaLocations.allMajorCities.contains(this);

  /// Get province for this city name
  String? get province => AngolaLocations.getProvinceForCity(this);
}
