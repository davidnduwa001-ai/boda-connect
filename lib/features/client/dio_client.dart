import 'package:boda_connect/features/network/network_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// HTTP client optimized for African networks
/// 
/// Features:
/// - Longer timeouts for high latency networks
/// - Automatic retry with exponential backoff
/// - Connection quality detection
/// - Offline detection
/// - Request/response logging (debug only)
class DioClient {
  static DioClient? _instance;
  late final Dio _dio;
  final Connectivity _connectivity = Connectivity();
  
  ConnectionQuality _currentQuality = ConnectionQuality.good;

  DioClient._() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: NetworkConfig.connectTimeout,
        receiveTimeout: NetworkConfig.receiveTimeout,
        sendTimeout: NetworkConfig.sendTimeout,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.addAll([
      _RetryInterceptor(_dio),
      if (kDebugMode) _LoggingInterceptor(),
    ]);

    // Monitor connectivity
    _monitorConnectivity();
  }

  /// Get singleton instance
  static DioClient get instance {
    _instance ??= DioClient._();
    return _instance!;
  }

  /// Get Dio instance
  Dio get dio => _dio;

  /// Get current connection quality
  ConnectionQuality get connectionQuality => _currentQuality;

  /// Check if online
  Future<bool> get isOnline async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Monitor connectivity changes
  void _monitorConnectivity() {
    _connectivity.onConnectivityChanged.listen((result) {
      _updateConnectionQuality(result);
    });
  }

  /// Update connection quality based on connectivity result
  void _updateConnectionQuality(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.none:
        _currentQuality = ConnectionQuality.offline;
        break;
      case ConnectivityResult.mobile:
        // Assume moderate for mobile (could improve with speed test)
        _currentQuality = ConnectionQuality.moderate;
        break;
      case ConnectivityResult.wifi:
        _currentQuality = ConnectionQuality.good;
        break;
      case ConnectivityResult.ethernet:
        _currentQuality = ConnectionQuality.excellent;
        break;
      default:
        _currentQuality = ConnectionQuality.moderate;
    }
  }

  /// Make GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Make POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Make PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Make DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Upload file with progress
  Future<Response<T>> uploadFile<T>(
    String path, {
    required String filePath,
    required String fieldName,
    Map<String, dynamic>? data,
    void Function(int, int)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final formData = FormData.fromMap({
      ...?data,
      fieldName: await MultipartFile.fromFile(filePath),
    });

    return _dio.post<T>(
      path,
      data: formData,
      onSendProgress: onProgress,
      cancelToken: cancelToken,
    );
  }
}

/// Retry interceptor for failed requests
class _RetryInterceptor extends Interceptor {
  final Dio _dio;
  
  _RetryInterceptor(this._dio);

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Get retry count from request options
    final retryCount = err.requestOptions.extra['retryCount'] ?? 0;
    
    // Check if should retry
    if (_shouldRetry(err) && retryCount < NetworkConfig.maxRetries) {
      // Increment retry count
      err.requestOptions.extra['retryCount'] = retryCount + 1;
      
      // Wait with exponential backoff
      final delay = NetworkConfig.getRetryDelay(retryCount);
      await Future.delayed(delay);
      
      // Log retry attempt
      debugPrint(
        '🔄 Retrying request (${retryCount + 1}/${NetworkConfig.maxRetries}): '
        '${err.requestOptions.path}'
      );
      
      try {
        // Retry the request
        final response = await _dio.fetch(err.requestOptions);
        handler.resolve(response);
        return;
      } catch (e) {
        // If retry fails, continue with error handling
      }
    }
    
    handler.next(err);
  }

  /// Check if request should be retried
  bool _shouldRetry(DioException err) {
    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError ||
        (err.response?.statusCode != null && 
         err.response!.statusCode! >= 500);
  }
}

/// Logging interceptor for debugging
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('➡️ ${options.method} ${options.uri}');
    if (options.data != null) {
      debugPrint('📦 Data: ${options.data}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '✅ ${response.statusCode} ${response.requestOptions.uri}'
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '❌ ${err.type} ${err.requestOptions.uri}: ${err.message}'
    );
    handler.next(err);
  }
}