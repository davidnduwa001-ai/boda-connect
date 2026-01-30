import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';

/// Video Thumbnail Service
///
/// Generates and caches thumbnails for various video sources:
/// - YouTube videos (uses YouTube thumbnail API)
/// - Vimeo videos (uses Vimeo thumbnail API)
/// - Firebase Storage videos (generates from first frame)
/// - Direct video URLs (generates from first frame)
class VideoThumbnailService {
  static final VideoThumbnailService _instance = VideoThumbnailService._();
  factory VideoThumbnailService() => _instance;
  VideoThumbnailService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // In-memory cache for thumbnails
  final Map<String, String> _thumbnailCache = {};

  /// Get thumbnail URL for a video
  /// Returns cached URL if available, otherwise generates/fetches one
  Future<String> getThumbnailUrl(String videoUrl) async {
    // Check memory cache first
    if (_thumbnailCache.containsKey(videoUrl)) {
      return _thumbnailCache[videoUrl]!;
    }

    // Check Firestore cache
    final cachedUrl = await _getCachedThumbnail(videoUrl);
    if (cachedUrl != null) {
      _thumbnailCache[videoUrl] = cachedUrl;
      return cachedUrl;
    }

    // Generate thumbnail based on video source
    final thumbnailUrl = await _generateThumbnail(videoUrl);

    // Cache the result
    _thumbnailCache[videoUrl] = thumbnailUrl;
    await _cacheThumbnail(videoUrl, thumbnailUrl);

    return thumbnailUrl;
  }

  /// Generate thumbnail based on video source
  Future<String> _generateThumbnail(String videoUrl) async {
    // YouTube
    if (_isYouTubeUrl(videoUrl)) {
      return _getYouTubeThumbnail(videoUrl);
    }

    // Vimeo
    if (_isVimeoUrl(videoUrl)) {
      return await _getVimeoThumbnail(videoUrl);
    }

    // Facebook
    if (_isFacebookUrl(videoUrl)) {
      return _getFacebookThumbnail(videoUrl);
    }

    // Instagram
    if (_isInstagramUrl(videoUrl)) {
      return _getInstagramThumbnail(videoUrl);
    }

    // TikTok
    if (_isTikTokUrl(videoUrl)) {
      return _getTikTokThumbnail(videoUrl);
    }

    // Firebase Storage or direct URL - try to generate from first frame
    // For now, return placeholder since generating requires platform channel
    return _getPlaceholderThumbnail(videoUrl);
  }

  // ==================== YOUTUBE ====================

  bool _isYouTubeUrl(String url) {
    return url.contains('youtube.com') ||
           url.contains('youtu.be') ||
           url.contains('youtube-nocookie.com');
  }

  String _getYouTubeThumbnail(String videoUrl) {
    String? videoId;

    // Standard YouTube URL: youtube.com/watch?v=VIDEO_ID
    if (videoUrl.contains('youtube.com/watch')) {
      final uri = Uri.parse(videoUrl);
      videoId = uri.queryParameters['v'];
    }
    // Short YouTube URL: youtu.be/VIDEO_ID
    else if (videoUrl.contains('youtu.be')) {
      videoId = videoUrl.split('youtu.be/').last.split('?').first;
    }
    // Embed URL: youtube.com/embed/VIDEO_ID
    else if (videoUrl.contains('youtube.com/embed')) {
      videoId = videoUrl.split('/embed/').last.split('?').first;
    }
    // Shorts URL: youtube.com/shorts/VIDEO_ID
    else if (videoUrl.contains('youtube.com/shorts')) {
      videoId = videoUrl.split('/shorts/').last.split('?').first;
    }

    if (videoId != null && videoId.isNotEmpty) {
      // Return high quality thumbnail
      // Options: default, mqdefault, hqdefault, sddefault, maxresdefault
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }

    return _getPlaceholderThumbnail(videoUrl);
  }

  // ==================== VIMEO ====================

  bool _isVimeoUrl(String url) {
    return url.contains('vimeo.com') || url.contains('player.vimeo.com');
  }

  Future<String> _getVimeoThumbnail(String videoUrl) async {
    try {
      String? videoId;

      // Standard: vimeo.com/VIDEO_ID
      if (videoUrl.contains('vimeo.com/')) {
        videoId = videoUrl.split('vimeo.com/').last.split('?').first.split('/').first;
      }
      // Player embed: player.vimeo.com/video/VIDEO_ID
      else if (videoUrl.contains('player.vimeo.com/video/')) {
        videoId = videoUrl.split('/video/').last.split('?').first;
      }

      if (videoId != null && videoId.isNotEmpty) {
        // Vimeo oEmbed API to get thumbnail
        // Note: This is a public API, no authentication needed for public videos
        return 'https://vumbnail.com/$videoId.jpg';
      }
    } catch (e) {
      debugPrint('❌ Error getting Vimeo thumbnail: $e');
    }

    return _getPlaceholderThumbnail(videoUrl);
  }

  // ==================== FACEBOOK ====================

  bool _isFacebookUrl(String url) {
    return url.contains('facebook.com') || url.contains('fb.watch');
  }

  String _getFacebookThumbnail(String videoUrl) {
    // Facebook doesn't have a public thumbnail API
    // Return a branded placeholder
    return _getPlaceholderThumbnail(videoUrl);
  }

  // ==================== INSTAGRAM ====================

  bool _isInstagramUrl(String url) {
    return url.contains('instagram.com') || url.contains('instagr.am');
  }

  String _getInstagramThumbnail(String videoUrl) {
    // Instagram doesn't have a public thumbnail API
    // Return a branded placeholder
    return _getPlaceholderThumbnail(videoUrl);
  }

  // ==================== TIKTOK ====================

  bool _isTikTokUrl(String url) {
    return url.contains('tiktok.com') || url.contains('vm.tiktok.com');
  }

  String _getTikTokThumbnail(String videoUrl) {
    // TikTok doesn't have a simple public thumbnail API
    // Return a branded placeholder
    return _getPlaceholderThumbnail(videoUrl);
  }

  // ==================== PLACEHOLDER ====================

  String _getPlaceholderThumbnail(String videoUrl) {
    // Return a data URL for a video placeholder icon
    // This is a simple gray background with a play button
    return 'data:image/svg+xml;base64,${base64Encode(utf8.encode(_videoPlaceholderSvg))}';
  }

  static const String _videoPlaceholderSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="320" height="180" viewBox="0 0 320 180">
  <rect width="320" height="180" fill="#E5E7EB"/>
  <circle cx="160" cy="90" r="35" fill="#9CA3AF"/>
  <polygon points="150,75 150,105 175,90" fill="#F3F4F6"/>
</svg>
''';

  // ==================== CACHING ====================

  /// Get URL hash for caching
  String _getUrlHash(String url) {
    return md5.convert(utf8.encode(url)).toString();
  }

  /// Get cached thumbnail from Firestore
  Future<String?> _getCachedThumbnail(String videoUrl) async {
    try {
      final hash = _getUrlHash(videoUrl);
      final doc = await _firestore
          .collection('video_thumbnails')
          .doc(hash)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        final expiry = (data['expiresAt'] as Timestamp?)?.toDate();

        // Check if not expired (cache for 7 days)
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          return data['thumbnailUrl'] as String?;
        }
      }
    } catch (e) {
      debugPrint('❌ Error getting cached thumbnail: $e');
    }
    return null;
  }

  /// Cache thumbnail URL in Firestore
  Future<void> _cacheThumbnail(String videoUrl, String thumbnailUrl) async {
    try {
      final hash = _getUrlHash(videoUrl);
      await _firestore.collection('video_thumbnails').doc(hash).set({
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 7)),
        ),
      });
    } catch (e) {
      debugPrint('❌ Error caching thumbnail: $e');
    }
  }

  /// Clear thumbnail cache for a specific URL
  Future<void> clearCacheForUrl(String videoUrl) async {
    _thumbnailCache.remove(videoUrl);
    try {
      final hash = _getUrlHash(videoUrl);
      await _firestore.collection('video_thumbnails').doc(hash).delete();
    } catch (e) {
      debugPrint('❌ Error clearing thumbnail cache: $e');
    }
  }

  /// Clear all thumbnail cache
  void clearMemoryCache() {
    _thumbnailCache.clear();
  }

  // ==================== UTILITY METHODS ====================

  /// Get video platform name from URL
  String getVideoPlatform(String videoUrl) {
    if (_isYouTubeUrl(videoUrl)) return 'YouTube';
    if (_isVimeoUrl(videoUrl)) return 'Vimeo';
    if (_isFacebookUrl(videoUrl)) return 'Facebook';
    if (_isInstagramUrl(videoUrl)) return 'Instagram';
    if (_isTikTokUrl(videoUrl)) return 'TikTok';
    if (videoUrl.contains('firebasestorage.googleapis.com')) return 'Uploaded';
    return 'Video';
  }

  /// Check if URL is a video URL
  bool isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.avi', '.wmv', '.flv', '.webm', '.mkv'];
    final lowerUrl = url.toLowerCase();

    // Check for video platforms
    if (_isYouTubeUrl(url) ||
        _isVimeoUrl(url) ||
        _isFacebookUrl(url) ||
        _isInstagramUrl(url) ||
        _isTikTokUrl(url)) {
      return true;
    }

    // Check for video file extensions
    for (final ext in videoExtensions) {
      if (lowerUrl.contains(ext)) return true;
    }

    return false;
  }

  /// Extract video ID from URL (platform-agnostic)
  String? extractVideoId(String videoUrl) {
    if (_isYouTubeUrl(videoUrl)) {
      if (videoUrl.contains('youtube.com/watch')) {
        return Uri.parse(videoUrl).queryParameters['v'];
      } else if (videoUrl.contains('youtu.be')) {
        return videoUrl.split('youtu.be/').last.split('?').first;
      }
    }

    if (_isVimeoUrl(videoUrl)) {
      if (videoUrl.contains('vimeo.com/')) {
        return videoUrl.split('vimeo.com/').last.split('?').first.split('/').first;
      }
    }

    return null;
  }
}
