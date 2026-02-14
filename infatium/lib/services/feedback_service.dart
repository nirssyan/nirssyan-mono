import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';
import 'analytics_service.dart';
import 'authenticated_http_client.dart';
import '../models/analytics_event_schema.dart';

/// Service for handling user feedback submissions
///
/// Provides functionality to send text feedback to the backend API
/// with proper authentication and error handling.
class FeedbackService extends ChangeNotifier {
  // Singleton instance
  static final FeedbackService _instance = FeedbackService._internal();
  factory FeedbackService() => _instance;
  FeedbackService._internal();

  // Service dependencies
  final AuthService _authService = AuthService();
  final AnalyticsService _analyticsService = AnalyticsService();
  final AuthenticatedHttpClient _httpClient = AuthenticatedHttpClient();

  // State properties
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _lastFeedbackId;
  DateTime? _lastSubmissionTime;

  // Getters
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get lastFeedbackId => _lastFeedbackId;
  DateTime? get lastSubmissionTime => _lastSubmissionTime;

  // Rate limiting - prevent double submit (1 feedback per 5 seconds)
  bool get canSubmit {
    if (_lastSubmissionTime == null) return true;
    final timeSinceLastSubmission = DateTime.now().difference(_lastSubmissionTime!);
    return timeSinceLastSubmission.inSeconds >= 5;
  }

  int get secondsUntilCanSubmit {
    if (_lastSubmissionTime == null) return 0;
    final timeSinceLastSubmission = DateTime.now().difference(_lastSubmissionTime!);
    final secondsPassed = timeSinceLastSubmission.inSeconds;
    return secondsPassed >= 5 ? 0 : 5 - secondsPassed;
  }

  /// Submit text feedback to the backend
  ///
  /// Returns true if successful, false otherwise.
  /// Error message can be retrieved via [errorMessage] property.
  Future<bool> submitFeedback(String message) async {
    // Validate input
    if (message.trim().isEmpty) {
      _errorMessage = 'Feedback message cannot be empty';
      notifyListeners();
      return false;
    }

    // Check rate limiting
    if (!canSubmit) {
      _errorMessage = 'Please wait ${secondsUntilCanSubmit} seconds before submitting again';
      notifyListeners();
      return false;
    }

    // Check authentication
    final user = _authService.currentUser;
    if (user == null) {
      _errorMessage = 'You must be logged in to send feedback';
      notifyListeners();
      return false;
    }

    // Reset error and set submitting state
    _errorMessage = null;
    _isSubmitting = true;
    notifyListeners();

    try {
      // Track analytics event
      _analyticsService.capture(EventSchema.feedbackSubmissionStarted, properties: {
        'message_length': message.length,
      });

      // Prepare the request
      final url = Uri.parse('${ApiConfig.baseUrl}/feedback');

      // Create multipart request for form-data
      final request = http.MultipartRequest('POST', url);

      // Add headers
      request.headers.addAll({
        'user-id': user.id,
        if (AuthService().currentSession?.accessToken != null)
          'Authorization': 'Bearer ${AuthService().currentSession!.accessToken}',
      });

      // Add message field
      request.fields['message'] = message;

      // Send request via authenticated client (handles 401 retry automatically)
      final response = await _httpClient.sendMultipart(
        request,
        timeout: ApiConfig.requestTimeout,
      );

      if (response.statusCode == 200) {
        // Parse successful response
        final data = jsonDecode(response.body);
        _lastFeedbackId = data['feedback_id'] ?? 'unknown';
        _lastSubmissionTime = DateTime.now();

        // Track success
        _analyticsService.capture(EventSchema.feedbackSubmitted, properties: {
          'feedback_id': _lastFeedbackId,
          'message_length': message.length,
        });

        _isSubmitting = false;
        notifyListeners();
        return true;
      } else {
        // Handle error response
        String errorMsg = 'Failed to send feedback';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg = errorData['error'] ?? errorMsg;
        } catch (_) {
          // If response is not JSON, use status code
          errorMsg = 'Failed to send feedback (${response.statusCode})';
        }

        _errorMessage = errorMsg;

        _isSubmitting = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('FeedbackService: Error submitting feedback: $e');

      // Set user-friendly error message
      if (e.toString().contains('timed out')) {
        _errorMessage = 'Request timed out. Please check your connection and try again.';
      } else if (e.toString().contains('SocketException')) {
        _errorMessage = 'No internet connection. Please check your network.';
      } else {
        _errorMessage = 'An error occurred. Please try again later.';
      }

      // Track error
      _analyticsService.capture(EventSchema.feedbackSubmissionError, properties: {
        'error': e.toString(),
      });

      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  /// Clear any error messages
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset the service state
  void reset() {
    _isSubmitting = false;
    _errorMessage = null;
    notifyListeners();
  }

  /// Reset rate limiting (call when modal is closed)
  void resetRateLimit() {
    _lastSubmissionTime = null;
    notifyListeners();
  }
}