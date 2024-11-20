import 'package:crystal/models/editor/search_match.dart';

class SearchConfig {
  final String searchTerm;
  final List<SearchMatch> matches;
  final int currentMatch;
  final Function(String) onSearchTermChanged;

  SearchConfig({
    required this.searchTerm,
    required this.matches,
    required this.currentMatch,
    required this.onSearchTermChanged,
  });
}
