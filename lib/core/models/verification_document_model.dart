import 'package:cloud_firestore/cloud_firestore.dart';

/// Types of verification documents required/accepted
enum DocumentType {
  /// Business registration (CNPJ in Brazil)
  businessLicense,

  /// Personal identity document (RG/CPF)
  identityDocument,

  /// Portfolio samples (minimum 5 photos)
  portfolio,

  /// Professional liability insurance
  insurance,

  /// Bank account verification for payments
  bankAccount,

  /// Other supporting documents
  other,
}

/// Document verification status
enum DocumentStatus {
  /// Awaiting admin review
  pending,

  /// Document approved
  approved,

  /// Document rejected (can resubmit)
  rejected,

  /// Document expired (needs renewal)
  expired,
}

/// Supplier verification status
enum VerificationStatus {
  /// No documents submitted
  notStarted,

  /// Documents submitted, awaiting review
  pendingReview,

  /// All required documents approved
  verified,

  /// One or more documents rejected
  rejected,

  /// Verification revoked (policy violation)
  suspended,
}

/// Model for individual verification documents
class VerificationDocument {
  final String id;
  final String supplierId;
  final DocumentType type;
  final String fileName;
  final String fileUrl;
  final int fileSize; // bytes
  final String mimeType;
  final DocumentStatus status;
  final String? rejectionReason;
  final DateTime uploadedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy; // Admin ID

  const VerificationDocument({
    required this.id,
    required this.supplierId,
    required this.type,
    required this.fileName,
    required this.fileUrl,
    required this.fileSize,
    required this.mimeType,
    this.status = DocumentStatus.pending,
    this.rejectionReason,
    required this.uploadedAt,
    this.reviewedAt,
    this.reviewedBy,
  });

  /// Get human-readable document type name
  String get typeName {
    switch (type) {
      case DocumentType.businessLicense:
        return 'Licença Comercial (CNPJ)';
      case DocumentType.identityDocument:
        return 'Documento de Identidade';
      case DocumentType.portfolio:
        return 'Portfólio';
      case DocumentType.insurance:
        return 'Seguro Profissional';
      case DocumentType.bankAccount:
        return 'Conta Bancária';
      case DocumentType.other:
        return 'Outro Documento';
    }
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case DocumentStatus.pending:
        return 'Em Análise';
      case DocumentStatus.approved:
        return 'Aprovado';
      case DocumentStatus.rejected:
        return 'Rejeitado';
      case DocumentStatus.expired:
        return 'Expirado';
    }
  }

  /// Check if document is an image
  bool get isImage =>
      mimeType.startsWith('image/') ||
      fileName.toLowerCase().endsWith('.jpg') ||
      fileName.toLowerCase().endsWith('.jpeg') ||
      fileName.toLowerCase().endsWith('.png') ||
      fileName.toLowerCase().endsWith('.webp');

  /// Check if document is a PDF
  bool get isPdf =>
      mimeType == 'application/pdf' ||
      fileName.toLowerCase().endsWith('.pdf');

  factory VerificationDocument.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return VerificationDocument.fromMap(data, doc.id);
  }

  factory VerificationDocument.fromMap(Map<String, dynamic> data, String id) {
    return VerificationDocument(
      id: id,
      supplierId: data['supplierId'] as String? ?? '',
      type: DocumentType.values.firstWhere(
        (e) => e.name == (data['type'] as String? ?? 'other'),
        orElse: () => DocumentType.other,
      ),
      fileName: data['fileName'] as String? ?? 'document',
      fileUrl: data['fileUrl'] as String? ?? '',
      fileSize: (data['fileSize'] as num?)?.toInt() ?? 0,
      mimeType: data['mimeType'] as String? ?? 'application/octet-stream',
      status: DocumentStatus.values.firstWhere(
        (e) => e.name == (data['status'] as String? ?? 'pending'),
        orElse: () => DocumentStatus.pending,
      ),
      rejectionReason: data['rejectionReason'] as String?,
      uploadedAt: _parseTimestamp(data['uploadedAt']) ?? DateTime.now(),
      reviewedAt: _parseTimestamp(data['reviewedAt']),
      reviewedBy: data['reviewedBy'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'supplierId': supplierId,
      'type': type.name,
      'fileName': fileName,
      'fileUrl': fileUrl,
      'fileSize': fileSize,
      'mimeType': mimeType,
      'status': status.name,
      'rejectionReason': rejectionReason,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedBy': reviewedBy,
    };
  }

  VerificationDocument copyWith({
    String? id,
    String? supplierId,
    DocumentType? type,
    String? fileName,
    String? fileUrl,
    int? fileSize,
    String? mimeType,
    DocumentStatus? status,
    String? rejectionReason,
    DateTime? uploadedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
  }) {
    return VerificationDocument(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      type: type ?? this.type,
      fileName: fileName ?? this.fileName,
      fileUrl: fileUrl ?? this.fileUrl,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

/// Requirements for supplier verification
class VerificationRequirements {
  /// Required document types for verification
  static const List<DocumentType> requiredDocuments = [
    DocumentType.businessLicense,
    DocumentType.identityDocument,
    DocumentType.portfolio,
  ];

  /// Optional but recommended documents
  static const List<DocumentType> optionalDocuments = [
    DocumentType.insurance,
    DocumentType.bankAccount,
  ];

  /// Minimum number of portfolio images
  static const int minPortfolioImages = 5;

  /// Maximum file size in bytes (10MB)
  static const int maxFileSize = 10 * 1024 * 1024;

  /// Allowed file types
  static const List<String> allowedMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
    'application/pdf',
  ];

  /// Check if a document type is required
  static bool isRequired(DocumentType type) {
    return requiredDocuments.contains(type);
  }

  /// Get description for each document type
  static String getDescription(DocumentType type) {
    switch (type) {
      case DocumentType.businessLicense:
        return 'Cartão CNPJ ou documento de registro da empresa. Aceito MEI, ME ou outros.';
      case DocumentType.identityDocument:
        return 'RG, CNH ou outro documento oficial com foto do responsável.';
      case DocumentType.portfolio:
        return 'Mínimo de 5 fotos de trabalhos realizados mostrando a qualidade do seu serviço.';
      case DocumentType.insurance:
        return 'Apólice de seguro de responsabilidade civil profissional (recomendado).';
      case DocumentType.bankAccount:
        return 'Comprovante de conta bancária para recebimento de pagamentos.';
      case DocumentType.other:
        return 'Documentos adicionais que comprovem sua qualificação.';
    }
  }
}

/// Summary of verification status for a supplier
class VerificationSummary {
  final String supplierId;
  final VerificationStatus status;
  final List<VerificationDocument> documents;
  final DateTime? lastUpdated;
  final String? adminNote;

  const VerificationSummary({
    required this.supplierId,
    required this.status,
    required this.documents,
    this.lastUpdated,
    this.adminNote,
  });

  /// Get documents by type
  List<VerificationDocument> getDocumentsByType(DocumentType type) {
    return documents.where((d) => d.type == type).toList();
  }

  /// Check if a specific document type is submitted
  bool hasDocumentType(DocumentType type) {
    return documents.any((d) => d.type == type);
  }

  /// Check if a specific document type is approved
  bool isDocumentTypeApproved(DocumentType type) {
    return documents.any(
      (d) => d.type == type && d.status == DocumentStatus.approved,
    );
  }

  /// Get missing required documents
  List<DocumentType> get missingRequiredDocuments {
    return VerificationRequirements.requiredDocuments
        .where((type) => !hasDocumentType(type))
        .toList();
  }

  /// Get rejected documents
  List<VerificationDocument> get rejectedDocuments {
    return documents.where((d) => d.status == DocumentStatus.rejected).toList();
  }

  /// Get pending documents
  List<VerificationDocument> get pendingDocuments {
    return documents.where((d) => d.status == DocumentStatus.pending).toList();
  }

  /// Calculate verification progress (0-100)
  int get progressPercent {
    if (status == VerificationStatus.verified) return 100;

    int total = VerificationRequirements.requiredDocuments.length;
    int approved = VerificationRequirements.requiredDocuments
        .where((type) => isDocumentTypeApproved(type))
        .length;

    return ((approved / total) * 100).round();
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case VerificationStatus.notStarted:
        return 'Não Iniciada';
      case VerificationStatus.pendingReview:
        return 'Em Análise';
      case VerificationStatus.verified:
        return 'Verificado';
      case VerificationStatus.rejected:
        return 'Documentos Rejeitados';
      case VerificationStatus.suspended:
        return 'Suspenso';
    }
  }

  factory VerificationSummary.empty(String supplierId) {
    return VerificationSummary(
      supplierId: supplierId,
      status: VerificationStatus.notStarted,
      documents: [],
    );
  }
}
