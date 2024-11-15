import 'package:crystal/models/highlighted_text.dart';

class HighlightRegion {
  final int startLine;
  final int endLine;
  final int version;
  List<HighlightedText> highlights;

  HighlightRegion({
    required this.startLine,
    required this.endLine,
    required this.version,
    required this.highlights,
  });
}
