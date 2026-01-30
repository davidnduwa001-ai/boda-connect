import 'dart:async';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/logger_service.dart';

/// Retry configuration for Cloud Function calls
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxRetries;

  /// Initial delay between retries in milliseconds
  final int initialDelayMs;

  /// Maximum delay between retries in milliseconds
  final int maxDelayMs;

  /// Exponential backoff multiplier
  final double backoffMultiplier;

  /// Whether to add jitter to delays
  final bool useJitter;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelayMs = 1000,
    this.maxDelayMs = 10000,
    this.backoffMultiplier = 2.0,
    this.useJitter = true,
  });

  /// Default config for most operations
  static const RetryConfig standard = RetryConfig();

  /// Config for critical operations (more retries)
  static const RetryConfig critical = RetryConfig(
    maxRetries: 5,
    initialDelayMs: 500,
    maxDelayMs: 30000,
  );

  /// Config for quick operations (fewer retries)
  static const RetryConfig quick = RetryConfig(
    maxRetries: 2,
    initialDelayMs: 500,
    maxDelayMs: 3000,
  );
}

/// Result of a Cloud Function call with retry info
class CloudFunctionResult<T> {
  final T data;
  final int attempts;
  final Duration totalDuration;

  const CloudFunctionResult({
    required this.data,
    required this.attempts,
    required this.totalDuration,
  });
}

/// Utility class for calling Cloud Functions with automatic retry
class CloudFunctionRetry {
  static final Random _random = Random();

  /// Call a Cloud Function with automatic retry on transient failures
  ///
  /// Returns the result data if successful, throws on permanent failure.
  ///
  /// Retryable errors:
  /// - UNAVAILABLE (503)
  /// - DEADLINE_EXCEEDED (timeout)
  /// - RESOURCE_EXHAUSTED (rate limit - with longer delay)
  /// - INTERNAL (500 - sometimes transient)
  ///
  /// Non-retryable errors:
  /// - INVALID_ARGUMENT
  /// - PERMISSION_DENIED
  /// - NOT_FOUND
  /// - ALREADY_EXISTS
  /// - FAILED_PRECONDITION
  /// - UNAUTHENTICATED
  static Future<CloudFunctionResult<T>> call<T>({
    required HttpsCallable callable,
    required Map<String, dynamic> parameters,
    RetryConfig config = RetryConfig.standard,
    String? functionName,
  }) async {
    final stopwatch = Stopwatch()..start();
    int attempt = 0;
    Exception? lastException;

    while (attempt <= config.maxRetries) {
      attempt++;

      try {
        final result = await callable.call<T>(parameters);
        stopwatch.stop();

        if (attempt > 1) {
          Log.success('${functionName ?? 'CF'} succeeded on attempt $attempt');
        }

        return CloudFunctionResult(
          data: result.data,
          attempts: attempt,
          totalDuration: stopwatch.elapsed,
        );
      } on FirebaseFunctionsException catch (e) {
        lastException = e;

        // Check if error is retryable
        if (!_isRetryableError(e.code)) {
          Log.fail('${functionName ?? 'CF'} failed with non-retryable error: ${e.code}');
          stopwatch.stop();
          rethrow;
        }

        // Check if we have retries left
        if (attempt > config.maxRetries) {
          Log.fail('${functionName ?? 'CF'} failed after $attempt attempts');
          stopwatch.stop();
          rethrow;
        }

        // Calculate delay with exponential backoff
        final delay = _calculateDelay(attempt, config, e.code);
        Log.d('${functionName ?? 'CF'} retry $attempt/${config.maxRetries} after ${delay.inMilliseconds}ms (${e.code})');

        await Future.delayed(delay);
      } on TimeoutException catch (e) {
        lastException = e;

        if (attempt > config.maxRetries) {
          Log.fail('${functionName ?? 'CF'} timed out after $attempt attempts');
          stopwatch.stop();
          rethrow;
        }

        final delay = _calculateDelay(attempt, config, 'timeout');
        Log.d('${functionName ?? 'CF'} timeout retry $attempt/${config.maxRetries} after ${delay.inMilliseconds}ms');

        await Future.delayed(delay);
      } catch (e) {
        // Unknown error - don't retry
        Log.fail('${functionName ?? 'CF'} failed with unknown error: $e');
        stopwatch.stop();
        rethrow;
      }
    }

    // Should not reach here, but just in case
    stopwatch.stop();
    throw lastException ?? Exception('Cloud Function call failed');
  }

  /// Check if an error code is retryable
  static bool _isRetryableError(String code) {
    switch (code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'resource-exhausted':
      case 'internal':
      case 'aborted': // Transaction conflict
        return true;
      default:
        return false;
    }
  }

  /// Calculate delay for next retry with exponential backoff and jitter
  static Duration _calculateDelay(int attempt, RetryConfig config, String errorCode) {
    // Base delay with exponential backoff
    var delayMs = config.initialDelayMs * pow(config.backoffMultiplier, attempt - 1);

    // Add extra delay for rate limiting
    if (errorCode == 'resource-exhausted') {
      delayMs *= 2;
    }

    // Cap at max delay
    delayMs = min(delayMs, config.maxDelayMs.toDouble());

    // Add jitter (0-25% of delay)
    if (config.useJitter) {
      final jitter = _random.nextDouble() * 0.25 * delayMs;
      delayMs += jitter;
    }

    return Duration(milliseconds: delayMs.round());
  }
}

/// Extension to make HttpsCallable easier to use with retry
extension HttpsCallableRetry on HttpsCallable {
  /// Call with automatic retry
  Future<T> callWithRetry<T>(
    Map<String, dynamic> parameters, {
    RetryConfig config = RetryConfig.standard,
    String? functionName,
  }) async {
    final result = await CloudFunctionRetry.call<T>(
      callable: this,
      parameters: parameters,
      config: config,
      functionName: functionName,
    );
    return result.data;
  }
}
