class BlameLine {
  final String author;
  final String commitHash;
  final DateTime timestamp;
  final String message;
  final String email;
  final String content;
  final int lineNumber;

  BlameLine({
    required this.author,
    required this.commitHash,
    required this.timestamp,
    required this.message,
    required this.email,
    required this.content,
    required this.lineNumber,
  });
}

class CommitDetails {
  final String hash;
  final String author;
  final String email;
  final DateTime timestamp;
  final String subject;
  final String body;
  final String authorAvatarUrl;

  CommitDetails({
    required this.hash,
    required this.author,
    required this.email,
    required this.timestamp,
    required this.subject,
    required this.body,
    required this.authorAvatarUrl,
  });
}

class FileDiff {
  final List<DiffHunk> hunks;
  final String filePath;

  FileDiff({
    required this.hunks,
    required this.filePath,
  });
}

class DiffHunk {
  final int oldStart;
  final int oldLength;
  final int newStart;
  final int newLength;
  final List<DiffLine> lines;

  DiffHunk({
    required this.oldStart,
    required this.oldLength,
    required this.newStart,
    required this.newLength,
    required this.lines,
  });
}

class DiffLine {
  final DiffLineType type;
  final String content;

  DiffLine({
    required this.type,
    required this.content,
  });
}

enum DiffLineType { addition, deletion, context, modification }

class CommitInfo {
  final String hash;
  final String author;
  final String email;
  final DateTime timestamp;
  final String message;

  CommitInfo({
    required this.hash,
    required this.author,
    required this.email,
    required this.timestamp,
    required this.message,
  });
}

enum FileStatus { modified, added, deleted, renamed, unmodified, untracked }

class GitException implements Exception {
  final String message;
  GitException(this.message);

  @override
  String toString() => 'GitException: $message';
}
