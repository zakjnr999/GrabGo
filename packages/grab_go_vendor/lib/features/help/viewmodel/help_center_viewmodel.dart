import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/help/model/vendor_help_models.dart';

class HelpCenterViewModel extends ChangeNotifier {
  HelpCenterViewModel() {
    searchController.addListener(_onSearchChanged);
  }

  final TextEditingController searchController = TextEditingController();
  final List<VendorHelpArticle> _articles = mockHelpArticles();
  final List<VendorPolicyDocument> _policyDocuments = mockPolicyDocuments();
  final List<VendorTrainingModule> _trainingModules = mockTrainingModules();

  List<VendorEscalationTicket> _tickets = mockEscalationTickets();

  String _query = '';
  VendorHelpArticleType? _articleTypeFilter;
  bool _preferInAppChat = true;
  bool _preferPhoneCall = false;
  bool _preferEmail = true;

  VendorHelpArticleType? get articleTypeFilter => _articleTypeFilter;
  bool get preferInAppChat => _preferInAppChat;
  bool get preferPhoneCall => _preferPhoneCall;
  bool get preferEmail => _preferEmail;

  List<VendorHelpArticle> get filteredArticles {
    final query = _query.toLowerCase();
    return _articles.where((article) {
      final matchesType =
          _articleTypeFilter == null || article.type == _articleTypeFilter;
      final matchesQuery =
          query.isEmpty ||
          article.title.toLowerCase().contains(query) ||
          article.excerpt.toLowerCase().contains(query) ||
          article.tags.any((tag) => tag.toLowerCase().contains(query));
      return matchesType && matchesQuery;
    }).toList();
  }

  List<VendorEscalationTicket> get tickets {
    final result = List<VendorEscalationTicket>.from(_tickets);
    result.sort((a, b) => b.id.compareTo(a.id));
    return result;
  }

  List<VendorPolicyDocument> get policyDocuments =>
      List.unmodifiable(_policyDocuments);

  List<VendorTrainingModule> get trainingModules =>
      List.unmodifiable(_trainingModules);

  int get unresolvedEscalationCount {
    return _tickets
        .where((ticket) => ticket.status != VendorEscalationStatus.resolved)
        .length;
  }

  void setArticleTypeFilter(VendorHelpArticleType? type) {
    if (_articleTypeFilter == type) return;
    _articleTypeFilter = type;
    notifyListeners();
  }

  void setPreferInAppChat(bool value) {
    if (_preferInAppChat == value) return;
    _preferInAppChat = value;
    notifyListeners();
  }

  void setPreferPhoneCall(bool value) {
    if (_preferPhoneCall == value) return;
    _preferPhoneCall = value;
    notifyListeners();
  }

  void setPreferEmail(bool value) {
    if (_preferEmail == value) return;
    _preferEmail = value;
    notifyListeners();
  }

  void addEscalation({
    required String title,
    required String category,
    required VendorEscalationPriority priority,
  }) {
    final trimmedTitle = title.trim();
    final trimmedCategory = category.trim();
    if (trimmedTitle.isEmpty || trimmedCategory.isEmpty) return;

    final id = 'esc_${DateTime.now().microsecondsSinceEpoch}';
    _tickets = [
      VendorEscalationTicket(
        id: id,
        title: trimmedTitle,
        category: trimmedCategory,
        priority: priority,
        status: VendorEscalationStatus.open,
        createdLabel: 'Now',
        lastUpdateLabel: 'Now',
      ),
      ..._tickets,
    ];
    notifyListeners();
  }

  void advanceEscalationStatus(String escalationId) {
    final index = _tickets.indexWhere((ticket) => ticket.id == escalationId);
    if (index < 0) return;

    final current = _tickets[index];
    final nextStatus = switch (current.status) {
      VendorEscalationStatus.open => VendorEscalationStatus.inProgress,
      VendorEscalationStatus.inProgress => VendorEscalationStatus.resolved,
      VendorEscalationStatus.resolved => VendorEscalationStatus.resolved,
    };
    if (nextStatus == current.status) return;

    _tickets[index] = current.copyWith(
      status: nextStatus,
      lastUpdateLabel: 'Now',
    );
    notifyListeners();
  }

  void toggleTrainingCompletion(String moduleId) {
    final index = _trainingModules.indexWhere(
      (module) => module.id == moduleId,
    );
    if (index < 0) return;
    final module = _trainingModules[index];
    _trainingModules[index] = module.copyWith(completed: !module.completed);
    notifyListeners();
  }

  void _onSearchChanged() {
    final nextValue = searchController.text.trim();
    if (_query == nextValue) return;
    _query = nextValue;
    notifyListeners();
  }

  @override
  void dispose() {
    searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }
}
