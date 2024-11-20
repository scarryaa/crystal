import 'package:crystal/models/editor/completion_item.dart';
import 'package:crystal/services/editor/completion_service.dart';
import 'package:flutter/material.dart';

class CompletionState {
  late final CompletionService _completionService;
  List<CompletionItem> suggestions = [];
  bool showCompletions = false;
  int selectedSuggestionIndex = 0;
  final ValueNotifier<int> selectedSuggestionIndexNotifier = ValueNotifier(0);

  void updateCompletions(List<CompletionItem> newSuggestions) {
    suggestions = newSuggestions;
    showCompletions = suggestions.isNotEmpty;
  }
}
