import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crystal/models/git_models.dart';
import 'package:git/git.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class GitService {
  late GitDir _gitDir;
  StreamSubscription? _fileWatcher;
  bool _isInitialized = false;
  final _statusController = StreamController<void>.broadcast();
  Stream<void> get onGitStatusChanged => _statusController.stream;
  StreamSubscription? _gitWatcher;
  Timer? _debounceTimer;
  static final Map<String, String> _avatarUrlCache = {};
  final Map<int, FileStatus> _lineStatuses = {};
  List<String> _originalContent = [];

  Map<String, String> get avatarUrlCache => _avatarUrlCache;
  final _lineStatusController =
      StreamController<Map<int, FileStatus>>.broadcast();
  Stream<Map<int, FileStatus>> get onLineStatusChanged =>
      _lineStatusController.stream;

  // Store file status information
  final Map<String, FileStatus> _fileStatuses = {};

  Future<void> updateDocumentChanges(
      String filePath, List<String> newContent) async {
    if (!_isInitialized) throw GitException('Git not initialized');

    // TODO
  }

  Map<int, FileStatus> getLineStatuses() {
    return Map.from(_lineStatuses);
  }

  Future<void> initialize(String filePath) async {
    try {
      // Find git root and initialize as before
      final gitRoot = await _findGitRoot(filePath);
      if (gitRoot == null) {
        throw GitException('Not a git repository');
      }
      _gitDir = await GitDir.fromExisting(gitRoot);
      _isInitialized = true;

      // Watch .git directory for git operations
      final gitDir = Directory(path.join(filePath, '.git'));
      _gitWatcher = gitDir.watch(recursive: true).listen((event) {
        if (event.path.endsWith('index') ||
            event.path.endsWith('HEAD') ||
            event.path.contains('refs/heads')) {
          _debounceAndNotify();
        }
      });

      // Watch project directory for file changes
      final projectDir = Directory(filePath);
      _fileWatcher = projectDir.watch(recursive: true).listen((event) {
        // Only react to file modifications
        if (event.type == FileSystemEvent.modify &&
            !event.path.contains('.git')) {
          _debounceAndNotify();
        }
      });
    } catch (e) {
      throw GitException('Failed to initialize Git: $e');
    }
  }

  Future<void> setOriginalContent(String filePath) async {
    // Store original content
    final result = await _gitDir.runCommand(['show', 'HEAD:$filePath']);
    _originalContent = (result.stdout as String).split('\n');
  }

  void _debounceAndNotify() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 100), () {
      _statusController.add(null);
    });
  }

  Future<String?> getRepositoryUrl() async {
    if (!_isInitialized) throw GitException('Git not initialized');
    try {
      final result =
          await _gitDir.runCommand(['config', '--get', 'remote.origin.url']);
      String url = (result.stdout as String).trim();

      // Convert SSH URL to HTTPS if needed
      if (url.startsWith('git@')) {
        url = url
            .replaceFirst(':', '/')
            .replaceFirst('git@', 'https://')
            .replaceAll('.git', '');
      }

      return url;
    } catch (e) {
      return null;
    }
  }

  Future<String> _fetchAvatarUrl(String repoUrl, String email) async {
    if (_avatarUrlCache.containsKey(email)) {
      return _avatarUrlCache[email]!;
    }

    try {
      // Convert GitHub URL to API format
      final uri = Uri.parse(repoUrl);
      final apiUrl = 'https://api.github.com/repos${uri.path}/commits';

      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final commits = jsonDecode(response.body) as List;
        for (var commit in commits) {
          if (commit['commit']['author']['email'] == email) {
            final avatarUrl = commit['author']['avatar_url'];
            if (avatarUrl != null) {
              _avatarUrlCache[email] = avatarUrl;
              return avatarUrl;
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching avatar: $e');
    }

    return '';
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
  Future<CommitDetails> getCommitDetails(String commitHash) async {
    if (!_isInitialized) throw GitException('Git not initialized');

    try {
      final result = await _gitDir.runCommand(
          ['show', '-s', '--format=%H|%an|%ae|%at|%s|%b', commitHash]);

      final output = (result.stdout as String).trim();
      final parts = output.split('|');

      if (parts.length >= 6) {
        final email = parts[2];
        String avatarUrl = _avatarUrlCache[email] ?? '';

        if (avatarUrl.isEmpty) {
          final repoUrl = await getRepositoryUrl();
          if (repoUrl != null) {
            avatarUrl = await _fetchAvatarUrl(repoUrl, email);
          }
        }

        return CommitDetails(
          hash: parts[0],
          author: parts[1],
          email: email,
          timestamp:
              DateTime.fromMillisecondsSinceEpoch(int.parse(parts[3]) * 1000),
          subject: parts[4],
          body: parts[5],
          authorAvatarUrl: avatarUrl,
        );
      }
      throw GitException('Invalid commit format');
    } catch (e) {
      throw GitException('Failed to get commit details: $e');
    }
  }

  Future<List<BlameLine>> getBlame(String filePath) async {
    if (!_isInitialized) throw GitException('Git not initialized');

    try {
      final result = await _gitDir.runCommand([
        'blame',
        '--porcelain',
        '-w', // Ignore whitespace
        '--show-name',
        '--show-email',
        filePath
      ]);
      final output = result.stdout as String;

      return _parseBlameOutput(output);
    } catch (e) {
      throw GitException('Failed to get blame: $e');
    }
  }

  List<BlameLine> _parseBlameOutput(String output) {
    final List<BlameLine> blameLines = [];
    final lines = output.split('\n');
    int currentLine = 0;

    // Cache for commit metadata
    final Map<String, (String, String, DateTime, String)> commitCache = {};

    while (currentLine < lines.length) {
      final line = lines[currentLine];

      if (line.startsWith(RegExp(r'^[0-9a-f]{40}'))) {
        final commit = line.substring(0, 40);
        String author;
        String email;
        DateTime timestamp;
        String message;
        String content = '';

        if (commitCache.containsKey(commit)) {
          (author, email, timestamp, message) = commitCache[commit]!;
          while (currentLine < lines.length &&
              !lines[currentLine].startsWith('\t')) {
            currentLine++;
          }
        } else {
          author = 'Unknown';
          email = '';
          message = '';
          timestamp = DateTime.now();
          currentLine++;

          while (currentLine < lines.length &&
              !lines[currentLine].startsWith('\t')) {
            final headerLine = lines[currentLine];
            if (headerLine.startsWith('author ')) {
              author = headerLine.substring(7).trim();
            } else if (headerLine.startsWith('author-mail ')) {
              email = headerLine
                  .substring(12)
                  .trim()
                  .replaceAll(RegExp(r'[<>]'), '');
            } else if (headerLine.startsWith('author-time ')) {
              timestamp = DateTime.fromMillisecondsSinceEpoch(
                  int.parse(headerLine.substring(11).trim()) * 1000);
            } else if (headerLine.startsWith('summary ')) {
              message = headerLine.substring(8).trim();
            }
            currentLine++;
          }

          commitCache[commit] = (author, email, timestamp, message);
        }

        if (currentLine < lines.length && lines[currentLine].startsWith('\t')) {
          content = lines[currentLine].substring(1);
          blameLines.add(BlameLine(
            commitHash: commit,
            author: author,
            email: email,
            timestamp: timestamp,
            message: message,
            content: content,
            lineNumber: blameLines.length + 1,
          ));
        }
      }
      currentLine++;
    }
    return blameLines;
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

  Future<Map<String, FileStatus>> getAllFileStatuses() async {
    if (!_isInitialized) throw GitException('Git not initialized');

    try {
      // Run git status --porcelain to get status of all files
      final result = await _gitDir.runCommand(['status', '--porcelain']);
      final output = (result.stdout as String).trim();

      // Parse the output and create a map of file paths to their statuses
      final Map<String, FileStatus> statuses = {};

      if (output.isNotEmpty) {
        final lines = output.split('\n');
        for (final line in lines) {
          if (line.length >= 2) {
            final statusCode = line.substring(0, 2);
            final filePath = line.substring(3).trim();

            final status = switch (statusCode) {
              'M ' => FileStatus.modified,
              ' M' => FileStatus.modified,
              'A ' => FileStatus.added,
              'D ' => FileStatus.deleted,
              'R ' => FileStatus.renamed,
              '??' => FileStatus.untracked,
              'MM' =>
                FileStatus.modified, // Both staged and unstaged modifications
              _ => FileStatus.unmodified,
            };

            statuses[filePath] = status;
          }
        }
      }

      return statuses;
    } catch (e) {
      throw GitException('Failed to get file statuses: $e');
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

  void dispose() {
    _debounceTimer?.cancel();
    _gitWatcher?.cancel();
    _fileWatcher?.cancel();
    _statusController.close();
  }
}
