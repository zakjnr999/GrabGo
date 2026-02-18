import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/onboarding/model/onboarding_setup_step.dart';

class OnboardingSetupViewModel extends ChangeNotifier {
  OnboardingSetupViewModel() {
    _steps = mockVendorGuidedSetupSteps();
    _selectedStepId = _steps.first.id;
    unawaited(_hydrate());
  }

  static const String _cacheKey = 'vendor_onboarding_setup_state_v1';

  late List<VendorGuidedSetupStep> _steps;
  late String _selectedStepId;
  bool _hasGuidedSetupOpened = false;
  bool _isHydrated = false;

  List<VendorGuidedSetupStep> get steps => List.unmodifiable(_steps);
  bool get hasGuidedSetupOpened => _hasGuidedSetupOpened;
  bool get isHydrated => _isHydrated;

  VendorGuidedSetupStep get selectedStep {
    return _steps.firstWhere(
      (entry) => entry.id == _selectedStepId,
      orElse: () => _steps.first,
    );
  }

  int get requiredTotal => _steps.where((entry) => !entry.isOptional).length;
  int get requiredCompleted => _steps
      .where(
        (entry) =>
            !entry.isOptional &&
            entry.status == VendorGuidedStepStatus.completed,
      )
      .length;
  int get requiredRemaining => requiredTotal - requiredCompleted;
  bool get allRequiredCompleted => requiredRemaining <= 0;

  int get optionalTotal => _steps.where((entry) => entry.isOptional).length;
  int get optionalCompleted => _steps
      .where(
        (entry) =>
            entry.isOptional &&
            entry.status == VendorGuidedStepStatus.completed,
      )
      .length;
  int get optionalSkipped => _steps
      .where(
        (entry) =>
            entry.isOptional && entry.status == VendorGuidedStepStatus.skipped,
      )
      .length;
  int get optionalPendingOrSkipped => _steps
      .where(
        (entry) =>
            entry.isOptional &&
            entry.status != VendorGuidedStepStatus.completed,
      )
      .length;

  double get requiredProgress {
    if (requiredTotal == 0) {
      return 1;
    }
    return requiredCompleted / requiredTotal;
  }

  bool isStepCompletedByType(VendorGuidedStepType type) {
    final step = stepByType(type);
    return step?.status == VendorGuidedStepStatus.completed;
  }

  VendorGuidedSetupStep? stepByType(VendorGuidedStepType type) {
    return _steps.cast<VendorGuidedSetupStep?>().firstWhere(
      (entry) => entry?.type == type,
      orElse: () => null,
    );
  }

  void selectStep(String stepId) {
    if (_selectedStepId == stepId) {
      return;
    }
    final exists = _steps.any((entry) => entry.id == stepId);
    if (!exists) {
      return;
    }
    _selectedStepId = stepId;
    notifyListeners();
    unawaited(_persistState());
  }

  void markGuideOpened() {
    if (_hasGuidedSetupOpened) {
      return;
    }
    _hasGuidedSetupOpened = true;
    notifyListeners();
    unawaited(_persistState());
  }

  void setStepCompletedByType(VendorGuidedStepType type, bool completed) {
    final step = stepByType(type);
    if (step == null) {
      return;
    }
    _updateStep(
      step.id,
      completed
          ? VendorGuidedStepStatus.completed
          : VendorGuidedStepStatus.pending,
    );
  }

  void toggleTrainingModule(String moduleId) {
    switch (moduleId) {
      case 'train_001':
        _hasGuidedSetupOpened = !_hasGuidedSetupOpened;
        notifyListeners();
        unawaited(_persistState());
        break;
      case 'train_002':
        setStepCompletedByType(
          VendorGuidedStepType.demoOrderRun,
          !_isCompleted(VendorGuidedStepType.demoOrderRun),
        );
        break;
      case 'train_003':
        setStepCompletedByType(
          VendorGuidedStepType.complianceReview,
          !_isCompleted(VendorGuidedStepType.complianceReview),
        );
        break;
      default:
        break;
    }
  }

  void startSelectedStep() {
    final current = selectedStep;
    if (current.status == VendorGuidedStepStatus.completed) {
      return;
    }
    _updateStep(current.id, VendorGuidedStepStatus.inProgress);
  }

  void markSelectedComplete() {
    final current = selectedStep;
    if (current.status == VendorGuidedStepStatus.completed) {
      return;
    }
    _updateStep(current.id, VendorGuidedStepStatus.completed);
    _selectNextIncomplete();
  }

  void skipSelectedStep() {
    final current = selectedStep;
    if (!current.isOptional ||
        current.status == VendorGuidedStepStatus.completed) {
      return;
    }
    _updateStep(current.id, VendorGuidedStepStatus.skipped);
    _selectNextIncomplete();
  }

  void resumeSelectedStep() {
    final current = selectedStep;
    if (current.status != VendorGuidedStepStatus.skipped) {
      return;
    }
    _updateStep(current.id, VendorGuidedStepStatus.inProgress);
  }

  void focusFirstRequiredGap() {
    final target = _steps.cast<VendorGuidedSetupStep?>().firstWhere(
      (entry) =>
          entry != null &&
          !entry.isOptional &&
          entry.status != VendorGuidedStepStatus.completed,
      orElse: () => null,
    );
    if (target == null) {
      return;
    }
    _selectedStepId = target.id;
    notifyListeners();
    unawaited(_persistState());
  }

  Future<void> _hydrate() async {
    final raw = CacheService.getData(_cacheKey);
    if (raw == null || raw.trim().isEmpty) {
      _isHydrated = true;
      notifyListeners();
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _isHydrated = true;
        notifyListeners();
        return;
      }

      final statusEntries = decoded['stepStatuses'];
      if (statusEntries is Map<String, dynamic>) {
        final nextSteps = _steps.map((step) {
          final rawStatus = statusEntries[step.id];
          if (rawStatus is! String) {
            return step;
          }
          return step.copyWith(status: _statusFromString(rawStatus));
        }).toList();
        _steps = nextSteps;
      }

      final selectedStepId = decoded['selectedStepId'];
      if (selectedStepId is String &&
          _steps.any((entry) => entry.id == selectedStepId)) {
        _selectedStepId = selectedStepId;
      }

      final guidedOpened = decoded['guidedOpened'];
      if (guidedOpened is bool) {
        _hasGuidedSetupOpened = guidedOpened;
      }
    } catch (_) {
      // Ignore malformed cache and continue with defaults.
    } finally {
      _isHydrated = true;
      notifyListeners();
    }
  }

  Future<void> _persistState() async {
    final payload = <String, dynamic>{
      'stepStatuses': {for (final step in _steps) step.id: step.status.name},
      'selectedStepId': _selectedStepId,
      'guidedOpened': _hasGuidedSetupOpened,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await CacheService.saveData(_cacheKey, jsonEncode(payload));
  }

  void _selectNextIncomplete() {
    final currentIndex = _steps.indexWhere(
      (entry) => entry.id == _selectedStepId,
    );
    if (currentIndex < 0) {
      return;
    }

    for (var index = currentIndex + 1; index < _steps.length; index++) {
      final next = _steps[index];
      if (next.status != VendorGuidedStepStatus.completed) {
        _selectedStepId = next.id;
        notifyListeners();
        unawaited(_persistState());
        return;
      }
    }
    unawaited(_persistState());
  }

  void _updateStep(String stepId, VendorGuidedStepStatus status) {
    final index = _steps.indexWhere((entry) => entry.id == stepId);
    if (index < 0) {
      return;
    }
    final current = _steps[index];
    if (current.status == status) {
      return;
    }
    _steps[index] = current.copyWith(status: status);
    notifyListeners();
    unawaited(_persistState());
  }

  bool _isCompleted(VendorGuidedStepType type) {
    return isStepCompletedByType(type);
  }

  VendorGuidedStepStatus _statusFromString(String raw) {
    return switch (raw) {
      'pending' => VendorGuidedStepStatus.pending,
      'inProgress' => VendorGuidedStepStatus.inProgress,
      'completed' => VendorGuidedStepStatus.completed,
      'skipped' => VendorGuidedStepStatus.skipped,
      _ => VendorGuidedStepStatus.pending,
    };
  }
}
