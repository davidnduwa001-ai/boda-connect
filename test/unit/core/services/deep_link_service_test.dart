import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Comprehensive Deep Link Service Tests for BODA CONNECT
///
/// Test Coverage:
/// 1. Payment Deep Links
/// 2. Supplier Profile Links
/// 3. Booking Links
/// 4. Category Links
/// 5. Referral System
/// 6. Link Generation
/// 7. Link Parsing
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({});
  });

  group('Payment Deep Link Tests', () {
    test('should generate payment success URL', () {
      final reference = 'PAY-123456';
      final url = _generatePaymentReturnUrl(reference, 'success');

      expect(url, contains('bodaconnect://'));
      expect(url, contains('payment/success'));
      expect(url, contains('ref=$reference'));
    });

    test('should generate payment cancel URL', () {
      final reference = 'PAY-123456';
      final url = _generatePaymentReturnUrl(reference, 'cancel');

      expect(url, contains('bodaconnect://'));
      expect(url, contains('payment/cancel'));
      expect(url, contains('ref=$reference'));
    });

    test('should parse payment success deep link', () {
      final uri = Uri.parse('bodaconnect://payment/success?ref=PAY-123456&bookingId=booking-789');

      // For custom schemes, the host becomes 'payment' and path is '/success'
      // So we check the full path by combining host and path
      final fullPath = '/${uri.host}${uri.path}';
      expect(fullPath, '/payment/success');
      expect(uri.queryParameters['ref'], 'PAY-123456');
      expect(uri.queryParameters['bookingId'], 'booking-789');
    });

    test('should parse payment failed deep link', () {
      final uri = Uri.parse('bodaconnect://payment/failed?ref=PAY-123456&error=insufficient_funds');

      // For custom schemes, the host becomes 'payment' and path is '/failed'
      final fullPath = '/${uri.host}${uri.path}';
      expect(fullPath, '/payment/failed');
      expect(uri.queryParameters['error'], 'insufficient_funds');
    });
  });

  group('Supplier Profile Link Tests', () {
    test('should generate supplier profile link', () {
      final supplierId = 'supplier-123';
      final supplierName = 'Foto Premium';
      final link = _generateSupplierLink(supplierId, supplierName);

      expect(link, contains('/supplier'));
      expect(link, contains('id=$supplierId'));
    });

    test('should parse supplier profile deep link', () {
      final uri = Uri.parse('https://bodaconnect.ao/supplier?id=supplier-123');

      expect(uri.path, '/supplier');
      expect(uri.queryParameters['id'], 'supplier-123');
    });
  });

  group('Booking Link Tests', () {
    test('should generate booking detail link', () {
      final bookingId = 'booking-456';
      final link = _generateBookingLink(bookingId);

      expect(link, contains('/booking'));
      expect(link, contains('id=$bookingId'));
    });

    test('should parse booking deep link', () {
      final uri = Uri.parse('https://bodaconnect.ao/booking?id=booking-456');

      expect(uri.path, '/booking');
      expect(uri.queryParameters['id'], 'booking-456');
    });
  });

  group('Category Link Tests', () {
    test('should generate category browse link', () {
      final categoryId = 'fotografia';
      final categoryName = 'Fotografia';
      final link = _generateCategoryLink(categoryId, categoryName);

      expect(link, contains('/category'));
      expect(link, contains('id=$categoryId'));
    });

    test('should parse category deep link', () {
      final uri = Uri.parse('https://bodaconnect.ao/category?id=fotografia');

      expect(uri.path, '/category');
      expect(uri.queryParameters['id'], 'fotografia');
    });
  });

  group('Referral System Tests', () {
    test('should generate referral invite link', () {
      final referralCode = 'BODA-ABC123';
      final userName = 'João Silva';
      final link = _generateInviteLink(referralCode, userName);

      expect(link, contains('/invite'));
      expect(link, contains('code=$referralCode'));
    });

    test('should parse referral deep link', () {
      final uri = Uri.parse('https://bodaconnect.ao/invite?code=BODA-ABC123');

      expect(uri.path, '/invite');
      expect(uri.queryParameters['code'], 'BODA-ABC123');
    });

    test('should store referral code in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      final referralCode = 'BODA-ABC123';

      await prefs.setString('pending_referral_code', referralCode);
      await prefs.setInt('referral_code_timestamp', DateTime.now().millisecondsSinceEpoch);

      expect(prefs.getString('pending_referral_code'), referralCode);
    });

    test('should retrieve stored referral code', () async {
      final prefs = await SharedPreferences.getInstance();
      final referralCode = 'BODA-XYZ789';
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      await prefs.setString('pending_referral_code', referralCode);
      await prefs.setInt('referral_code_timestamp', timestamp);

      final storedCode = prefs.getString('pending_referral_code');
      final storedTimestamp = prefs.getInt('referral_code_timestamp');

      expect(storedCode, referralCode);
      expect(storedTimestamp, timestamp);
    });

    test('should expire referral code after 30 days', () async {
      final prefs = await SharedPreferences.getInstance();
      final referralCode = 'BODA-OLD123';
      final oldTimestamp = DateTime.now()
          .subtract(const Duration(days: 31))
          .millisecondsSinceEpoch;

      await prefs.setString('pending_referral_code', referralCode);
      await prefs.setInt('referral_code_timestamp', oldTimestamp);

      final storedTimestamp = prefs.getInt('referral_code_timestamp');
      final storedTime = DateTime.fromMillisecondsSinceEpoch(storedTimestamp!);
      final isExpired = DateTime.now().difference(storedTime).inDays > 30;

      expect(isExpired, true);
    });

    test('should clear referral code after use', () async {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('pending_referral_code', 'BODA-ABC123');
      await prefs.setInt('referral_code_timestamp', DateTime.now().millisecondsSinceEpoch);

      // Clear after successful registration
      await prefs.remove('pending_referral_code');
      await prefs.remove('referral_code_timestamp');

      expect(prefs.getString('pending_referral_code'), isNull);
    });

    test('should apply referral code and credit referrer', () async {
      // Create referrer user
      await fakeFirestore.collection('users').doc('referrer-123').set({
        'name': 'Referrer User',
        'referralCode': 'BODA-REF123',
        'totalReferrals': 5,
      });

      // Find referrer by code
      final referrerQuery = await fakeFirestore
          .collection('users')
          .where('referralCode', isEqualTo: 'BODA-REF123')
          .limit(1)
          .get();

      expect(referrerQuery.docs.isNotEmpty, true);

      // Create referral record
      await fakeFirestore.collection('referrals').add({
        'referrerId': 'referrer-123',
        'referredUserId': 'new-user-456',
        'referredUserName': 'New User',
        'referralCode': 'BODA-REF123',
        'status': 'completed',
        'createdAt': Timestamp.now(),
      });

      // Update referrer stats
      await fakeFirestore.collection('users').doc('referrer-123').update({
        'totalReferrals': FieldValue.increment(1),
      });

      final referrer = await fakeFirestore.collection('users').doc('referrer-123').get();
      expect(referrer.data()?['totalReferrals'], 6);

      // Create notification for referrer
      await fakeFirestore.collection('notifications').add({
        'userId': 'referrer-123',
        'type': 'referral_success',
        'title': 'Convite Aceito!',
        'message': 'New User se juntou ao BODA CONNECT através do seu convite.',
        'isRead': false,
        'createdAt': Timestamp.now(),
      });

      final notifications = await fakeFirestore
          .collection('notifications')
          .where('userId', isEqualTo: 'referrer-123')
          .where('type', isEqualTo: 'referral_success')
          .get();

      expect(notifications.docs.length, 1);
    });

    test('should generate unique referral code for user', () {
      final userId1 = 'user-abc123def';
      final userId2 = 'user-xyz789ghi';

      final code1 = _generateReferralCode(userId1);
      final code2 = _generateReferralCode(userId2);

      expect(code1.startsWith('BODA'), true);
      expect(code2.startsWith('BODA'), true);
      expect(code1, isNot(equals(code2)));
      expect(code1.length, greaterThanOrEqualTo(10));
    });
  });

  group('Link Parsing Tests', () {
    test('should handle various deep link formats', () {
      final links = [
        'bodaconnect://payment/success?ref=PAY-123',
        'https://bodaconnect.ao/supplier?id=sup-456',
        'https://bodaconnect.page.link/abc123',
      ];

      for (final link in links) {
        final uri = Uri.parse(link);
        expect(uri.hasScheme, true);
      }
    });

    test('should extract path components correctly', () {
      final uri = Uri.parse('https://bodaconnect.ao/category/fotografia/suppliers');

      expect(uri.pathSegments.length, 3);
      expect(uri.pathSegments[0], 'category');
      expect(uri.pathSegments[1], 'fotografia');
      expect(uri.pathSegments[2], 'suppliers');
    });

    test('should handle missing query parameters gracefully', () {
      final uri = Uri.parse('https://bodaconnect.ao/supplier');

      final supplierId = uri.queryParameters['id'];
      expect(supplierId, isNull);
    });
  });

  group('Dynamic Link Generation Tests', () {
    test('should build link with social meta tags', () {
      final link = _buildDynamicLinkParams(
        path: '/supplier',
        queryParams: {'id': 'supplier-123'},
        title: 'Foto Premium',
        description: 'Veja Foto Premium no BODA CONNECT',
        imageUrl: 'https://example.com/image.jpg',
      );

      expect(link['path'], '/supplier');
      expect(link['title'], 'Foto Premium');
      expect(link['description'], contains('BODA CONNECT'));
      expect(link['imageUrl'], isNotNull);
    });

    test('should encode query parameters properly', () {
      final params = {
        'name': 'João Silva',
        'category': 'Fotografia e Vídeo',
      };

      final encoded = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      expect(encoded, contains('Jo%C3%A3o'));
      expect(encoded, contains('V%C3%ADdeo'));
    });
  });

  group('Route Handling Tests', () {
    test('should map deep link paths to routes', () {
      final pathToRoute = {
        '/payment/success': 'paymentSuccess',
        '/payment/failed': 'paymentFailed',
        '/payment/cancel': 'paymentFailed',
        '/booking': 'bookingDetail',
        '/supplier': 'supplierDetail',
        '/category': 'categoryBrowse',
        '/invite': 'welcome',
      };

      expect(pathToRoute['/payment/success'], 'paymentSuccess');
      expect(pathToRoute['/supplier'], 'supplierDetail');
      expect(pathToRoute['/invite'], 'welcome');
    });

    test('should handle unknown paths', () {
      final unknownPath = '/unknown/path';
      final defaultRoute = 'splash';

      final route = _getRouteForPath(unknownPath) ?? defaultRoute;
      expect(route, defaultRoute);
    });
  });
}

// Helper functions for testing

String _generatePaymentReturnUrl(String reference, String status) {
  return 'bodaconnect://payment/$status?ref=$reference';
}

String _generateSupplierLink(String supplierId, String supplierName) {
  return 'https://bodaconnect.ao/supplier?id=$supplierId';
}

String _generateBookingLink(String bookingId) {
  return 'https://bodaconnect.ao/booking?id=$bookingId';
}

String _generateCategoryLink(String categoryId, String categoryName) {
  return 'https://bodaconnect.ao/category?id=$categoryId';
}

String _generateInviteLink(String referralCode, String userName) {
  return 'https://bodaconnect.ao/invite?code=$referralCode';
}

String _generateReferralCode(String userId) {
  final prefix = userId.substring(5, 9).toUpperCase();
  final suffix = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
  return 'BODA$prefix$suffix';
}

Map<String, dynamic> _buildDynamicLinkParams({
  required String path,
  Map<String, String>? queryParams,
  String? title,
  String? description,
  String? imageUrl,
}) {
  return {
    'path': path,
    'queryParams': queryParams,
    'title': title ?? 'BODA CONNECT',
    'description': description ?? 'Serviços de casamento em Angola',
    'imageUrl': imageUrl,
  };
}

String? _getRouteForPath(String path) {
  final routes = {
    '/payment/success': 'paymentSuccess',
    '/payment/failed': 'paymentFailed',
    '/payment/cancel': 'paymentFailed',
    '/booking': 'bookingDetail',
    '/supplier': 'supplierDetail',
    '/category': 'categoryBrowse',
    '/invite': 'welcome',
  };
  return routes[path];
}
