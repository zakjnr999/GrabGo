enum VendorHelpArticleType {
  onboarding,
  operations,
  orders,
  catalog,
  policy,
  payments,
}

enum VendorEscalationPriority { low, medium, high, critical }

enum VendorEscalationStatus { open, inProgress, resolved }

class VendorHelpArticle {
  final String id;
  final VendorHelpArticleType type;
  final String title;
  final String excerpt;
  final List<String> tags;

  const VendorHelpArticle({
    required this.id,
    required this.type,
    required this.title,
    required this.excerpt,
    required this.tags,
  });
}

class VendorEscalationTicket {
  final String id;
  final String title;
  final String category;
  final VendorEscalationPriority priority;
  final VendorEscalationStatus status;
  final String createdLabel;
  final String lastUpdateLabel;

  const VendorEscalationTicket({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.createdLabel,
    required this.lastUpdateLabel,
  });

  VendorEscalationTicket copyWith({
    VendorEscalationPriority? priority,
    VendorEscalationStatus? status,
    String? lastUpdateLabel,
  }) {
    return VendorEscalationTicket(
      id: id,
      title: title,
      category: category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      createdLabel: createdLabel,
      lastUpdateLabel: lastUpdateLabel ?? this.lastUpdateLabel,
    );
  }
}

class VendorPolicyDocument {
  final String id;
  final String title;
  final String summary;
  final String updatedLabel;

  const VendorPolicyDocument({
    required this.id,
    required this.title,
    required this.summary,
    required this.updatedLabel,
  });
}

class VendorTrainingModule {
  final String id;
  final String title;
  final String durationLabel;
  final String description;
  final bool completed;

  const VendorTrainingModule({
    required this.id,
    required this.title,
    required this.durationLabel,
    required this.description,
    required this.completed,
  });

  VendorTrainingModule copyWith({bool? completed}) {
    return VendorTrainingModule(
      id: id,
      title: title,
      durationLabel: durationLabel,
      description: description,
      completed: completed ?? this.completed,
    );
  }
}

extension VendorHelpArticleTypeX on VendorHelpArticleType {
  String get label {
    return switch (this) {
      VendorHelpArticleType.onboarding => 'Onboarding',
      VendorHelpArticleType.operations => 'Operations',
      VendorHelpArticleType.orders => 'Orders',
      VendorHelpArticleType.catalog => 'Catalog',
      VendorHelpArticleType.policy => 'Policy',
      VendorHelpArticleType.payments => 'Payments',
    };
  }
}

extension VendorEscalationPriorityX on VendorEscalationPriority {
  String get label {
    return switch (this) {
      VendorEscalationPriority.low => 'Low',
      VendorEscalationPriority.medium => 'Medium',
      VendorEscalationPriority.high => 'High',
      VendorEscalationPriority.critical => 'Critical',
    };
  }
}

extension VendorEscalationStatusX on VendorEscalationStatus {
  String get label {
    return switch (this) {
      VendorEscalationStatus.open => 'Open',
      VendorEscalationStatus.inProgress => 'In Progress',
      VendorEscalationStatus.resolved => 'Resolved',
    };
  }
}

List<VendorHelpArticle> mockHelpArticles() {
  return const [
    VendorHelpArticle(
      id: 'help_001',
      type: VendorHelpArticleType.onboarding,
      title: 'How to replay onboarding training',
      excerpt: 'Run onboarding and demo-order steps again from More > Help.',
      tags: ['training', 'onboarding', 'replay'],
    ),
    VendorHelpArticle(
      id: 'help_002',
      type: VendorHelpArticleType.orders,
      title: 'Handling at-risk orders quickly',
      excerpt:
          'Use queue filters, prioritize red badges, and update status immediately.',
      tags: ['orders', 'sla', 'risk'],
    ),
    VendorHelpArticle(
      id: 'help_003',
      type: VendorHelpArticleType.catalog,
      title: 'Bulk stock updates in catalog',
      excerpt:
          'Select multiple items and apply stock delta actions in one step.',
      tags: ['catalog', 'stock', 'bulk'],
    ),
    VendorHelpArticle(
      id: 'help_004',
      type: VendorHelpArticleType.operations,
      title: 'Pausing store with auto-resume',
      excerpt: 'Pause requires a reason and can include optional resume timer.',
      tags: ['store', 'outage', 'pause'],
    ),
    VendorHelpArticle(
      id: 'help_005',
      type: VendorHelpArticleType.policy,
      title: 'Prescription handling policy',
      excerpt: 'Pharmacy products requiring Rx must complete manual review.',
      tags: ['pharmacy', 'policy', 'compliance'],
    ),
    VendorHelpArticle(
      id: 'help_006',
      type: VendorHelpArticleType.payments,
      title: 'Understanding settlement notifications',
      excerpt: 'Track payout updates and expected release windows.',
      tags: ['payout', 'settlement', 'finance'],
    ),
  ];
}

List<VendorEscalationTicket> mockEscalationTickets() {
  return const [
    VendorEscalationTicket(
      id: 'esc_001',
      title: 'Rider handover mismatch on #GG-829300',
      category: 'Order Handover',
      priority: VendorEscalationPriority.high,
      status: VendorEscalationStatus.inProgress,
      createdLabel: 'Today, 11:22 AM',
      lastUpdateLabel: '15m ago',
    ),
    VendorEscalationTicket(
      id: 'esc_002',
      title: 'Prescription document unreadable',
      category: 'Pharmacy Compliance',
      priority: VendorEscalationPriority.critical,
      status: VendorEscalationStatus.open,
      createdLabel: 'Today, 10:05 AM',
      lastUpdateLabel: '42m ago',
    ),
    VendorEscalationTicket(
      id: 'esc_003',
      title: 'Delayed payout advice needed',
      category: 'Payments',
      priority: VendorEscalationPriority.medium,
      status: VendorEscalationStatus.resolved,
      createdLabel: 'Yesterday',
      lastUpdateLabel: 'Resolved',
    ),
  ];
}

List<VendorPolicyDocument> mockPolicyDocuments() {
  return const [
    VendorPolicyDocument(
      id: 'pol_001',
      title: 'Vendor Operations Policy',
      summary: 'Daily operating standards and uptime requirements.',
      updatedLabel: 'Updated Jan 2026',
    ),
    VendorPolicyDocument(
      id: 'pol_002',
      title: 'Prescription & Restricted Items Policy',
      summary: 'Rules for pharmacy checks and restricted catalog items.',
      updatedLabel: 'Updated Dec 2025',
    ),
    VendorPolicyDocument(
      id: 'pol_003',
      title: 'Cancellation and Refund Policy',
      summary: 'Order cancellation windows and refund responsibilities.',
      updatedLabel: 'Updated Nov 2025',
    ),
  ];
}

List<VendorTrainingModule> mockTrainingModules() {
  return const [
    VendorTrainingModule(
      id: 'train_001',
      title: 'Onboarding Replay',
      durationLabel: '4 min',
      description: 'Replay introduction to unified vendor operations.',
      completed: true,
    ),
    VendorTrainingModule(
      id: 'train_002',
      title: 'Demo Order Simulation',
      durationLabel: '6 min',
      description: 'Practice accept, prepare, and handover sequence.',
      completed: false,
    ),
    VendorTrainingModule(
      id: 'train_003',
      title: 'Issue Escalation Flow',
      durationLabel: '3 min',
      description: 'Learn when and how to escalate order or policy issues.',
      completed: false,
    ),
  ];
}
