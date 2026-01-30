/// Network configuration optimized for African networks (Angola)
/// 
/// African networks typically have:
/// - Higher latency (100-300ms)
/// - Variable bandwidth
/// - Expensive data costs
/// - Frequent disconnections
/// 
/// This configuration addresses these challenges.
class NetworkConfig {
  NetworkConfig._();

  // ==================== TIMEOUTS ====================
  // Longer timeouts for African networks
  
  /// Connection timeout (time to establish connection)
  static const Duration connectTimeout = Duration(seconds: 30);
  
  /// Receive timeout (time to receive response)
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  /// Send timeout (time to send request)
  static const Duration sendTimeout = Duration(seconds: 30);

  // ==================== RETRY CONFIGURATION ====================
  
  /// Maximum number of retry attempts
  static const int maxRetries = 3;
  
  /// Delay between retry attempts
  static const Duration retryDelay = Duration(seconds: 2);
  
  /// Exponential backoff multiplier
  static const double backoffMultiplier = 1.5;

  // ==================== IMAGE QUALITY ====================
  // Lower quality to reduce data usage and improve loading times
  
  /// Thumbnail quality (for list views, avatars)
  static const int thumbnailQuality = 50;
  
  /// Preview quality (for detail views)
  static const int previewQuality = 70;
  
  /// Full image quality (for zoom/download)
  static const int fullImageQuality = 85;
  
  /// Maximum thumbnail dimension (pixels)
  static const int thumbnailMaxDimension = 200;
  
  /// Maximum preview dimension (pixels)
  static const int previewMaxDimension = 800;
  
  /// Maximum full image dimension (pixels)
  static const int fullImageMaxDimension = 1920;

  // ==================== UPLOAD LIMITS ====================
  // Consider data costs for African users
  
  /// Maximum image file size (MB)
  static const int maxImageSizeMB = 5;
  
  /// Maximum video file size (MB)
  static const int maxVideoSizeMB = 50;
  
  /// Maximum video duration (seconds)
  static const int maxVideoDurationSeconds = 60;
  
  /// Maximum images per upload batch
  static const int maxImagesPerBatch = 10;

  // ==================== CACHE CONFIGURATION ====================
  
  /// Cache duration for static content (categories, etc.)
  static const Duration staticCacheDuration = Duration(days: 7);
  
  /// Cache duration for dynamic content (suppliers, etc.)
  static const Duration dynamicCacheDuration = Duration(hours: 1);
  
  /// Cache duration for user data
  static const Duration userCacheDuration = Duration(minutes: 30);
  
  /// Maximum cache size (MB)
  static const int maxCacheSizeMB = 100;

  // ==================== PAGINATION ====================
  // Smaller page sizes for faster loading
  
  /// Default page size for lists
  static const int defaultPageSize = 10;
  
  /// Page size for search results
  static const int searchPageSize = 15;
  
  /// Page size for chat messages
  static const int chatPageSize = 20;

  // ==================== OFFLINE CONFIGURATION ====================
  
  /// Enable offline mode by default
  static const bool offlineModeEnabled = true;
  
  /// Sync interval when online (minutes)
  static const int syncIntervalMinutes = 5;
  
  /// Maximum offline queue size
  static const int maxOfflineQueueSize = 100;

  // ==================== HELPERS ====================

  /// Get retry delay with exponential backoff
  static Duration getRetryDelay(int attempt) {
    final delay = retryDelay.inMilliseconds * 
        (backoffMultiplier * attempt).round();
    return Duration(milliseconds: delay);
  }

  /// Check if file size is within limit
  static bool isFileSizeValid(int bytes, {bool isVideo = false}) {
    final maxBytes = (isVideo ? maxVideoSizeMB : maxImageSizeMB) * 1024 * 1024;
    return bytes <= maxBytes;
  }

  /// Get human-readable max file size
  static String getMaxFileSizeText({bool isVideo = false}) {
    final size = isVideo ? maxVideoSizeMB : maxImageSizeMB;
    return '${size}MB';
  }
}

/// Connection quality levels
enum ConnectionQuality {
  /// No connection
  offline,
  
  /// Very slow (< 100 Kbps) - 2G
  poor,
  
  /// Slow (100-500 Kbps) - 3G
  moderate,
  
  /// Good (500 Kbps - 2 Mbps) - 4G
  good,
  
  /// Excellent (> 2 Mbps) - WiFi/5G
  excellent,
}

/// Extension to get configuration based on connection quality
extension ConnectionQualityConfig on ConnectionQuality {
  /// Get image quality based on connection
  int get imageQuality {
    switch (this) {
      case ConnectionQuality.offline:
        return 0; // Use cached only
      case ConnectionQuality.poor:
        return 30;
      case ConnectionQuality.moderate:
        return 50;
      case ConnectionQuality.good:
        return 70;
      case ConnectionQuality.excellent:
        return 85;
    }
  }

  /// Get page size based on connection
  int get pageSize {
    switch (this) {
      case ConnectionQuality.offline:
        return 5;
      case ConnectionQuality.poor:
        return 5;
      case ConnectionQuality.moderate:
        return 10;
      case ConnectionQuality.good:
        return 15;
      case ConnectionQuality.excellent:
        return 20;
    }
  }

  /// Should preload images?
  bool get shouldPreloadImages {
    switch (this) {
      case ConnectionQuality.offline:
      case ConnectionQuality.poor:
        return false;
      case ConnectionQuality.moderate:
      case ConnectionQuality.good:
      case ConnectionQuality.excellent:
        return true;
    }
  }

  /// Should autoplay videos?
  bool get shouldAutoplayVideos {
    switch (this) {
      case ConnectionQuality.offline:
      case ConnectionQuality.poor:
      case ConnectionQuality.moderate:
        return false;
      case ConnectionQuality.good:
      case ConnectionQuality.excellent:
        return true;
    }
  }
}