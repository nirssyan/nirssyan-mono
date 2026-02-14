/// Response model for POST /sources/validate API
class SourceValidationResponse {
  final bool isValid;
  final String? sourceType; // "TELEGRAM" | "WEBSITE" | null
  final String? shortName;

  const SourceValidationResponse({
    required this.isValid,
    this.sourceType,
    this.shortName,
  });

  factory SourceValidationResponse.fromJson(Map<String, dynamic> json) {
    return SourceValidationResponse(
      isValid: json['is_valid'] as bool? ?? false,
      sourceType: json['source_type'] as String?,
      shortName: json['short_name'] as String?,
    );
  }
}

/// Validation status for a source in the feed creator form
enum SourceValidationStatus {
  pending, // Initial state, not yet validated
  validating, // API call in progress
  valid, // Successfully validated
  invalid, // Validation returned is_valid=false
  error, // Network or server error
}

/// A source with validation state for the feed creator form
class ValidatedSource {
  final String originalInput;
  final String? shortName;
  final String? sourceType;
  final SourceValidationStatus status;
  final String? errorMessage;

  const ValidatedSource({
    required this.originalInput,
    this.shortName,
    this.sourceType,
    this.status = SourceValidationStatus.pending,
    this.errorMessage,
  });

  /// The display name for the chip - prefer shortName if available
  String get displayName => shortName ?? originalInput;

  /// Create a copy with updated fields
  ValidatedSource copyWith({
    String? originalInput,
    String? shortName,
    String? sourceType,
    SourceValidationStatus? status,
    String? errorMessage,
  }) {
    return ValidatedSource(
      originalInput: originalInput ?? this.originalInput,
      shortName: shortName ?? this.shortName,
      sourceType: sourceType ?? this.sourceType,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
