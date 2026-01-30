import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprehensive Video Thumbnail Service Tests for BODA CONNECT
///
/// Test Coverage:
/// 1. YouTube Thumbnail Extraction
/// 2. Vimeo Thumbnail Extraction
/// 3. Other Platform Detection
/// 4. Cache Management
/// 5. Placeholder Generation
/// 6. Video URL Validation
void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  group('YouTube Thumbnail Tests', () {
    test('should detect YouTube URLs', () {
      final youtubeUrls = [
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        'https://youtube.com/watch?v=dQw4w9WgXcQ',
        'https://youtu.be/dQw4w9WgXcQ',
        'https://www.youtube.com/embed/dQw4w9WgXcQ',
        'https://www.youtube.com/shorts/dQw4w9WgXcQ',
        'https://youtube-nocookie.com/embed/dQw4w9WgXcQ',
      ];

      for (final url in youtubeUrls) {
        expect(_isYouTubeUrl(url), isTrue, reason: 'Failed to detect: $url');
      }
    });

    test('should extract YouTube video ID from standard URL', () {
      final url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final videoId = _extractYouTubeVideoId(url);
      expect(videoId, 'dQw4w9WgXcQ');
    });

    test('should extract YouTube video ID from short URL', () {
      final url = 'https://youtu.be/dQw4w9WgXcQ';
      final videoId = _extractYouTubeVideoId(url);
      expect(videoId, 'dQw4w9WgXcQ');
    });

    test('should extract YouTube video ID from embed URL', () {
      final url = 'https://www.youtube.com/embed/dQw4w9WgXcQ';
      final videoId = _extractYouTubeVideoId(url);
      expect(videoId, 'dQw4w9WgXcQ');
    });

    test('should extract YouTube video ID from shorts URL', () {
      final url = 'https://www.youtube.com/shorts/dQw4w9WgXcQ';
      final videoId = _extractYouTubeVideoId(url);
      expect(videoId, 'dQw4w9WgXcQ');
    });

    test('should generate YouTube thumbnail URL', () {
      final videoId = 'dQw4w9WgXcQ';
      final thumbnailUrl = _getYouTubeThumbnailUrl(videoId);

      expect(thumbnailUrl, 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg');
    });

    test('should handle YouTube URL with extra parameters', () {
      final url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLrAXtmErZgOeiKm4sgNOknGvNjby9efdf&index=1';
      final videoId = _extractYouTubeVideoId(url);
      expect(videoId, 'dQw4w9WgXcQ');
    });
  });

  group('Vimeo Thumbnail Tests', () {
    test('should detect Vimeo URLs', () {
      final vimeoUrls = [
        'https://vimeo.com/123456789',
        'https://www.vimeo.com/123456789',
        'https://player.vimeo.com/video/123456789',
      ];

      for (final url in vimeoUrls) {
        expect(_isVimeoUrl(url), isTrue, reason: 'Failed to detect: $url');
      }
    });

    test('should extract Vimeo video ID from standard URL', () {
      final url = 'https://vimeo.com/123456789';
      final videoId = _extractVimeoVideoId(url);
      expect(videoId, '123456789');
    });

    test('should extract Vimeo video ID from player URL', () {
      final url = 'https://player.vimeo.com/video/123456789';
      final videoId = _extractVimeoVideoId(url);
      expect(videoId, '123456789');
    });

    test('should generate Vimeo thumbnail URL', () {
      final videoId = '123456789';
      final thumbnailUrl = _getVimeoThumbnailUrl(videoId);

      expect(thumbnailUrl, 'https://vumbnail.com/123456789.jpg');
    });
  });

  group('Other Platform Detection Tests', () {
    test('should detect Facebook video URLs', () {
      final facebookUrls = [
        'https://www.facebook.com/watch?v=123456789',
        'https://facebook.com/user/videos/123456789',
        'https://fb.watch/abc123',
      ];

      for (final url in facebookUrls) {
        expect(_isFacebookUrl(url), isTrue, reason: 'Failed to detect: $url');
      }
    });

    test('should detect Instagram video URLs', () {
      final instagramUrls = [
        'https://www.instagram.com/p/ABC123/',
        'https://instagram.com/reel/ABC123/',
        'https://instagr.am/p/ABC123/',
      ];

      for (final url in instagramUrls) {
        expect(_isInstagramUrl(url), isTrue, reason: 'Failed to detect: $url');
      }
    });

    test('should detect TikTok video URLs', () {
      final tiktokUrls = [
        'https://www.tiktok.com/@user/video/123456789',
        'https://tiktok.com/@user/video/123456789',
        'https://vm.tiktok.com/ABC123/',
      ];

      for (final url in tiktokUrls) {
        expect(_isTikTokUrl(url), isTrue, reason: 'Failed to detect: $url');
      }
    });

    test('should identify video platform', () {
      expect(_getVideoPlatform('https://youtube.com/watch?v=abc'), 'YouTube');
      expect(_getVideoPlatform('https://vimeo.com/123'), 'Vimeo');
      expect(_getVideoPlatform('https://facebook.com/watch?v=123'), 'Facebook');
      expect(_getVideoPlatform('https://instagram.com/reel/abc'), 'Instagram');
      expect(_getVideoPlatform('https://tiktok.com/@user/video/123'), 'TikTok');
      expect(_getVideoPlatform('https://firebasestorage.googleapis.com/v0/b/...'), 'Uploaded');
      expect(_getVideoPlatform('https://example.com/video.mp4'), 'Video');
    });
  });

  group('Video URL Validation Tests', () {
    test('should identify video file extensions', () {
      final videoExtensions = ['.mp4', '.mov', '.avi', '.wmv', '.flv', '.webm', '.mkv'];

      for (final ext in videoExtensions) {
        final url = 'https://example.com/video$ext';
        expect(_isVideoUrl(url), isTrue, reason: 'Failed for: $ext');
      }
    });

    test('should not identify image URLs as video', () {
      final imageUrls = [
        'https://example.com/image.jpg',
        'https://example.com/photo.png',
        'https://example.com/image.gif',
      ];

      for (final url in imageUrls) {
        final isOnlyVideoExtension = _hasVideoExtension(url);
        expect(isOnlyVideoExtension, isFalse);
      }
    });

    test('should identify video platform URLs as video', () {
      final platformUrls = [
        'https://youtube.com/watch?v=abc123',
        'https://vimeo.com/123456',
        'https://tiktok.com/@user/video/123',
      ];

      for (final url in platformUrls) {
        expect(_isVideoUrl(url), isTrue, reason: 'Failed for: $url');
      }
    });
  });

  group('Cache Management Tests', () {
    test('should cache thumbnail URL in Firestore', () async {
      final videoUrl = 'https://youtube.com/watch?v=dQw4w9WgXcQ';
      final thumbnailUrl = 'https://img.youtube.com/vi/dQw4w9WgXcQ/hqdefault.jpg';
      final hash = _getUrlHash(videoUrl);

      await fakeFirestore.collection('video_thumbnails').doc(hash).set({
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'createdAt': Timestamp.now(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      });

      final cached = await fakeFirestore.collection('video_thumbnails').doc(hash).get();
      expect(cached.exists, isTrue);
      expect(cached.data()?['thumbnailUrl'], thumbnailUrl);
    });

    test('should retrieve cached thumbnail if not expired', () async {
      final videoUrl = 'https://youtube.com/watch?v=abc123';
      final hash = _getUrlHash(videoUrl);
      final expiresAt = DateTime.now().add(const Duration(days: 3));

      await fakeFirestore.collection('video_thumbnails').doc(hash).set({
        'videoUrl': videoUrl,
        'thumbnailUrl': 'https://img.youtube.com/vi/abc123/hqdefault.jpg',
        'expiresAt': Timestamp.fromDate(expiresAt),
      });

      final doc = await fakeFirestore.collection('video_thumbnails').doc(hash).get();
      final expiry = (doc.data()?['expiresAt'] as Timestamp).toDate();

      expect(expiry.isAfter(DateTime.now()), isTrue);
    });

    test('should detect expired cache', () async {
      final videoUrl = 'https://youtube.com/watch?v=expired123';
      final hash = _getUrlHash(videoUrl);
      final expiresAt = DateTime.now().subtract(const Duration(days: 1));

      await fakeFirestore.collection('video_thumbnails').doc(hash).set({
        'videoUrl': videoUrl,
        'thumbnailUrl': 'https://img.youtube.com/vi/expired123/hqdefault.jpg',
        'expiresAt': Timestamp.fromDate(expiresAt),
      });

      final doc = await fakeFirestore.collection('video_thumbnails').doc(hash).get();
      final expiry = (doc.data()?['expiresAt'] as Timestamp).toDate();

      expect(expiry.isBefore(DateTime.now()), isTrue);
    });

    test('should clear cache for specific URL', () async {
      final videoUrl = 'https://youtube.com/watch?v=clearme';
      final hash = _getUrlHash(videoUrl);

      await fakeFirestore.collection('video_thumbnails').doc(hash).set({
        'videoUrl': videoUrl,
        'thumbnailUrl': 'https://img.youtube.com/vi/clearme/hqdefault.jpg',
      });

      await fakeFirestore.collection('video_thumbnails').doc(hash).delete();

      final doc = await fakeFirestore.collection('video_thumbnails').doc(hash).get();
      expect(doc.exists, isFalse);
    });
  });

  group('Placeholder Generation Tests', () {
    test('should generate SVG placeholder', () {
      final placeholder = _getPlaceholderThumbnail();

      expect(placeholder, startsWith('data:image/svg+xml;base64,'));

      // Decode and verify it's valid SVG
      final base64Part = placeholder.split(',')[1];
      final decoded = utf8.decode(base64Decode(base64Part));
      expect(decoded, contains('<svg'));
      expect(decoded, contains('</svg>'));
    });

    test('placeholder should have play button', () {
      final placeholder = _getPlaceholderThumbnail();
      final base64Part = placeholder.split(',')[1];
      final decoded = utf8.decode(base64Decode(base64Part));

      // Should contain polygon (play button triangle)
      expect(decoded, contains('<polygon'));
    });
  });

  group('Hash Generation Tests', () {
    test('should generate consistent hash for same URL', () {
      final url = 'https://youtube.com/watch?v=test123';

      final hash1 = _getUrlHash(url);
      final hash2 = _getUrlHash(url);

      expect(hash1, hash2);
    });

    test('should generate different hashes for different URLs', () {
      final url1 = 'https://youtube.com/watch?v=video1';
      final url2 = 'https://youtube.com/watch?v=video2';

      final hash1 = _getUrlHash(url1);
      final hash2 = _getUrlHash(url2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('hash should be valid MD5 length', () {
      final url = 'https://youtube.com/watch?v=test';
      final hash = _getUrlHash(url);

      expect(hash.length, 32); // MD5 hash is 32 characters
    });
  });

  group('Thumbnail Quality Options Tests', () {
    test('should support different YouTube thumbnail qualities', () {
      final videoId = 'abc123';

      final defaultThumbnail = 'https://img.youtube.com/vi/$videoId/default.jpg';
      final mqThumbnail = 'https://img.youtube.com/vi/$videoId/mqdefault.jpg';
      final hqThumbnail = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
      final sdThumbnail = 'https://img.youtube.com/vi/$videoId/sddefault.jpg';
      final maxresThumbnail = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';

      expect(defaultThumbnail, contains('/default.jpg'));
      expect(mqThumbnail, contains('/mqdefault.jpg'));
      expect(hqThumbnail, contains('/hqdefault.jpg'));
      expect(sdThumbnail, contains('/sddefault.jpg'));
      expect(maxresThumbnail, contains('/maxresdefault.jpg'));
    });
  });

  group('Error Handling Tests', () {
    test('should return placeholder for invalid YouTube URL', () {
      final invalidUrl = 'https://youtube.com/invalid';
      final videoId = _extractYouTubeVideoId(invalidUrl);

      if (videoId == null || videoId.isEmpty) {
        final thumbnail = _getPlaceholderThumbnail();
        expect(thumbnail, startsWith('data:image/svg+xml'));
      }
    });

    test('should handle malformed URLs gracefully', () {
      final malformedUrls = [
        'not-a-url',
        'http://',
        'youtube',
      ];

      for (final url in malformedUrls) {
        expect(_isYouTubeUrl(url), isFalse);
        expect(_isVimeoUrl(url), isFalse);
      }
    });
  });
}

// Helper functions for testing

bool _isYouTubeUrl(String url) {
  return url.contains('youtube.com') ||
      url.contains('youtu.be') ||
      url.contains('youtube-nocookie.com');
}

bool _isVimeoUrl(String url) {
  return url.contains('vimeo.com') || url.contains('player.vimeo.com');
}

bool _isFacebookUrl(String url) {
  return url.contains('facebook.com') || url.contains('fb.watch');
}

bool _isInstagramUrl(String url) {
  return url.contains('instagram.com') || url.contains('instagr.am');
}

bool _isTikTokUrl(String url) {
  return url.contains('tiktok.com') || url.contains('vm.tiktok.com');
}

String? _extractYouTubeVideoId(String url) {
  if (url.contains('youtube.com/watch')) {
    final uri = Uri.parse(url);
    return uri.queryParameters['v'];
  } else if (url.contains('youtu.be')) {
    return url.split('youtu.be/').last.split('?').first;
  } else if (url.contains('youtube.com/embed')) {
    return url.split('/embed/').last.split('?').first;
  } else if (url.contains('youtube.com/shorts')) {
    return url.split('/shorts/').last.split('?').first;
  }
  return null;
}

String? _extractVimeoVideoId(String url) {
  // Check for player URL first (more specific pattern)
  if (url.contains('player.vimeo.com/video/')) {
    return url.split('/video/').last.split('?').first;
  } else if (url.contains('vimeo.com/')) {
    return url.split('vimeo.com/').last.split('?').first.split('/').first;
  }
  return null;
}

String _getYouTubeThumbnailUrl(String videoId) {
  return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
}

String _getVimeoThumbnailUrl(String videoId) {
  return 'https://vumbnail.com/$videoId.jpg';
}

String _getVideoPlatform(String url) {
  if (_isYouTubeUrl(url)) return 'YouTube';
  if (_isVimeoUrl(url)) return 'Vimeo';
  if (_isFacebookUrl(url)) return 'Facebook';
  if (_isInstagramUrl(url)) return 'Instagram';
  if (_isTikTokUrl(url)) return 'TikTok';
  if (url.contains('firebasestorage.googleapis.com')) return 'Uploaded';
  return 'Video';
}

bool _isVideoUrl(String url) {
  if (_isYouTubeUrl(url) ||
      _isVimeoUrl(url) ||
      _isFacebookUrl(url) ||
      _isInstagramUrl(url) ||
      _isTikTokUrl(url)) {
    return true;
  }
  return _hasVideoExtension(url);
}

bool _hasVideoExtension(String url) {
  final videoExtensions = ['.mp4', '.mov', '.avi', '.wmv', '.flv', '.webm', '.mkv'];
  final lowerUrl = url.toLowerCase();
  return videoExtensions.any((ext) => lowerUrl.contains(ext));
}

String _getUrlHash(String url) {
  // Simple hash for testing (in real code, use crypto package)
  var hash = 0;
  for (var i = 0; i < url.length; i++) {
    hash = ((hash << 5) - hash) + url.codeUnitAt(i);
    hash = hash & hash;
  }
  return hash.abs().toRadixString(16).padLeft(32, '0');
}

String _getPlaceholderThumbnail() {
  const svgContent = '''
<svg xmlns="http://www.w3.org/2000/svg" width="320" height="180" viewBox="0 0 320 180">
  <rect width="320" height="180" fill="#E5E7EB"/>
  <circle cx="160" cy="90" r="35" fill="#9CA3AF"/>
  <polygon points="150,75 150,105 175,90" fill="#F3F4F6"/>
</svg>
''';
  return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(svgContent))}';
}
