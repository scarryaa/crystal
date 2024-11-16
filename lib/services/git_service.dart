import 'dart:io';

import 'package:crystal/models/git_models.dart';
import 'package:git/git.dart';
import 'package:path/path.dart' as path;

class GitService {
  late GitDir _gitDir;
  bool _isInitialized = false;

  // Store file status information
  final Map<String, FileStatus> _fileStatuses = {};

  Future<void> initialize(String filePath) async {
    try {
      // Find the git root directory by walking up the directory tree
      final gitRoot = await _findGitRoot(filePath);
      if (gitRoot == null) {
        throw GitException('Not a git repository');
      }

      _gitDir = await GitDir.fromExisting(gitRoot);
      _isInitialized = true;
    } catch (e) {
      throw GitException('Failed to initialize Git: $e');
    }
  }

  Future<String?> _findGitRoot(String startPath) async {
    Directory current = Directory(startPath);

    while (true) {
      // Check if .git directory exists
      final gitDir = Directory(path.join(current.path, '.git'));
      if (await gitDir.exists()) {
        return current.path;
      }

      // Move up one directory
      final parent = current.parent;

      // If we've reached the root directory without finding .git
      if (parent.path == current.path) {
        return null;
      }

      current = parent;
    }
  }

  bool get isInitialized => _isInitialized;

  // Get blame information for a file
  Future<List<BlameLine>> getBlame(String filePath) async {
    if (!_isInitialized) throw GitException('Git not initialized');

    try {
      final result =
          await _gitDir.runCommand(['blame', '--porcelain', filePath]);
      return _parseBlameOutput(result.stdout as String);
    } catch (e) {
      throw GitException('Failed to get blame: $e');
    }
  }

  // Get diff for a specific file
  Future<FileDiff> getFileDiff(String filePath) async {
    if (!_isInitialized) throw GitException('Git not initialized');

    try {
      final result = await _gitDir.runCommand(['diff', filePath]);
      return _parseDiffOutput(result.stdout as String);
    } catch (e) {
      throw GitException('Failed to get diff: $e');
    }
  }

  // Get current branch
  Future<String> getCurrentBranch() async {
    if (!_isInitialized) throw GitException('Git not initialized');

    try {
      final result =
          await _gitDir.runCommand(['rev-parse', '--abbrev-ref', 'HEAD']);
      return (result.stdout as String).trim();
    } catch (e) {
      throw GitException('Failed to get current branch: $e');
    }
  }

  // Get file status (modified, added, deleted, etc.)
  Future<FileStatus> getFileStatus(String filePath) async {
    if (!_isInitialized) throw GitException('Git not initialized');

    try {
      final result =
          await _gitDir.runCommand(['status', '--porcelain', filePath]);
      return _parseStatusOutput(result.stdout as String);
    } catch (e) {
      throw GitException('Failed to get file status: $e');
    }
  }

  // Stage file
  Future<void> stageFile(String filePath) async {
    if (!_isInitialized) throw GitException('Git not initialized');

    try {
      await _gitDir.runCommand(['add', filePath]);
    } catch (e) {
      throw GitException('Failed to stage file: $e');
    }
  }

  // Commit changes
  Future<void> commit(String message) async {
    if (!_isInitialized) throw GitException('Git not initialized');

    try {
      await _gitDir.runCommand(['commit', '-m', message]);
    } catch (e) {
      throw GitException('Failed to commit: $e');
    }
  }

  // Get commit history
  Future<List<CommitInfo>> getCommitHistory(String filePath) async {
    if (!_isInitialized) throw GitException('Git not initialized');

    try {
      final result = await _gitDir
          .runCommand(['log', '--pretty=format:%H|%an|%ae|%at|%s', filePath]);
      return _parseCommitHistory(result.stdout as String);
    } catch (e) {
      throw GitException('Failed to get commit history: $e');
    }
  }

  List<BlameLine> _parseBlameOutput(String output) {
    final List<BlameLine> blameLines = [];
    final lines = output.split('\n');
    int currentLine = 0;

    while (currentLine < lines.length) {
      if (lines[currentLine].startsWith(RegExp(r'^[0-9a-f]{40}'))) {
        final commit = lines[currentLine].substring(0, 40);
        String author = '';
        DateTime timestamp = DateTime.now();
        String content = '';
        int lineNumber = 0;

        // Parse header lines
        while (!lines[currentLine].startsWith('\t')) {
          if (lines[currentLine].startsWith('author ')) {
            author = lines[currentLine].substring(7);
          } else if (lines[currentLine].startsWith('author-time ')) {
            timestamp = DateTime.fromMillisecondsSinceEpoch(
                int.parse(lines[currentLine].substring(11)) * 1000);
          }
          currentLine++;
        }

        // Get content
        content = lines[currentLine].substring(1);
        lineNumber = blameLines.length + 1;

        blameLines.add(BlameLine(
          commitHash: commit,
          author: author,
          timestamp: timestamp,
          content: content,
          lineNumber: lineNumber,
        ));
      }
      currentLine++;
    }

    return blameLines;
  }

  FileDiff _parseDiffOutput(String output) {
    final List<DiffHunk> hunks = [];
    final lines = output.split('\n');
    String filePath = '';

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.startsWith('diff --git')) {
        filePath = line.split(' ')[2];
      } else if (line.startsWith('@@ ')) {
        // Parse hunk header
        final match =
            RegExp(r'@@ -(\d+),?(\d+)? \+(\d+),?(\d+)? @@').firstMatch(line);
        if (match != null) {
          final oldStart = int.parse(match.group(1)!);
          final oldLength = int.parse(match.group(2) ?? '1');
          final newStart = int.parse(match.group(3)!);
          final newLength = int.parse(match.group(4) ?? '1');

          final List<DiffLine> diffLines = [];
          i++;

          // Parse hunk content
          while (i < lines.length && !lines[i].startsWith('@@ ')) {
            if (lines[i].isNotEmpty) {
              final type = switch (lines[i][0]) {
                '+' => DiffLineType.addition,
                '-' => DiffLineType.deletion,
                _ => DiffLineType.context,
              };
              diffLines.add(DiffLine(
                type: type,
                content: lines[i].substring(1),
              ));
            }
            i++;
          }
          i--; // Adjust for the outer loop increment

          hunks.add(DiffHunk(
            oldStart: oldStart,
            oldLength: oldLength,
            newStart: newStart,
            newLength: newLength,
            lines: diffLines,
          ));
        }
      }
    }

    return FileDiff(hunks: hunks, filePath: filePath);
  }

  FileStatus _parseStatusOutput(String output) {
    final status = output.trim();
    if (status.isEmpty) return FileStatus.unmodified;

    return switch (status.substring(0, 2)) {
      'M ' => FileStatus.modified,
      'A ' => FileStatus.added,
      'D ' => FileStatus.deleted,
      'R ' => FileStatus.renamed,
      '??' => FileStatus.untracked,
      _ => FileStatus.unmodified,
    };
  }

  List<CommitInfo> _parseCommitHistory(String output) {
    final commits = <CommitInfo>[];
    final lines = output.split('\n');

    for (final line in lines) {
      if (line.isEmpty) continue;

      final parts = line.split('|');
      if (parts.length == 5) {
        commits.add(CommitInfo(
          hash: parts[0],
          author: parts[1],
          email: parts[2],
          timestamp:
              DateTime.fromMillisecondsSinceEpoch(int.parse(parts[3]) * 1000),
          message: parts[4],
        ));
      }
    }

    return commits;
  }
}
