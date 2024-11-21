import 'dart:async';

import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

class LSPConnectionManager {
  Process? languageServer;
  final _logger = Logger('LSPConnectionManager');
  final Map<int, Completer<dynamic>> _pendingRequests = {};
  int _messageId = 1;

  void Function(Map<String, dynamic>)? _onNotification;
  void Function(Map<String, dynamic>)? _onConfigurationRequest;

  set onNotification(void Function(Map<String, dynamic>) handler) {
    _onNotification = handler;
  }

  set onConfigurationRequest(void Function(Map<String, dynamic>) handler) {
    _onConfigurationRequest = handler;
  }

  Future<void> initializeConnection(
      String executable, List<String> args) async {
    // Verify executable before starting
    if (!await verifyExecutable(executable)) {
      throw Exception('Failed to verify executable: $executable');
    }

    try {
      _logger.info('Starting language server: $executable');
      _logger.info('Arguments: $args');
      _logger.info('PATH: ${Platform.environment['PATH']}');

      languageServer = await Process.start(executable, args, environment: {
        'PATH': Platform.environment['PATH']!,
        'NODE_PATH': Platform.environment['NODE_PATH'] ?? ''
      });

      languageServer?.stderr.transform(utf8.decoder).listen((String data) {
        _logger.warning('Language server stderr: $data');
      });
    } catch (e) {
      _logger.severe('Failed to start language server', e);
      rethrow;
    }

    _setupMessageHandling();
  }

  Future<bool> verifyExecutable(String executable) async {
    try {
      // First try to find the executable in PATH
      final String? executablePath = await _findExecutableInPath(executable);

      if (executablePath == null) {
        _logger.severe('Executable not found in PATH: $executable');
        return false;
      }

      _logger.info('Found executable at: $executablePath');

      // Check if file is executable
      final file = File(executablePath);
      final stat = await file.stat();

      if (Platform.isWindows) {
        if (!executablePath.toLowerCase().endsWith('.exe')) {
          _logger.warning(
              'Windows executable should end with .exe: $executablePath');
        }
      } else {
        // Check execute permission on Unix-like systems
        if ((stat.mode & 0x49) == 0) {
          _logger.severe(
              'Executable does not have execute permissions: $executablePath');
          return false;
        }
      }

      // Try to run with --version or --help to verify
      try {
        final result = await Process.run(executablePath, ['--version']);
        _logger.info('Executable version check output: ${result.stdout}');
        return result.exitCode == 0;
      } catch (e) {
        _logger.warning('Version check failed, trying help command');
        try {
          final result = await Process.run(executablePath, ['--help']);
          return result.exitCode == 0;
        } catch (e) {
          _logger.severe('Help command also failed: $e');
          return false;
        }
      }
    } catch (e) {
      _logger.severe('Error verifying executable: $e');
      return false;
    }
  }

  Future<String?> _findExecutableInPath(String executable) async {
    // If the executable is already a full path, just return it
    if (await File(executable).exists()) {
      return executable;
    }

    // Get the PATH environment variable
    final String pathEnv = Platform.environment['PATH'] ?? '';
    final List<String> pathDirs = pathEnv.split(Platform.isWindows ? ';' : ':');

    // On Windows, also check for .exe extension
    final List<String> executableNames =
        Platform.isWindows ? [executable, '$executable.exe'] : [executable];

    // Search for the executable in each PATH directory
    for (final String dir in pathDirs) {
      for (final String execName in executableNames) {
        final String path = '${dir.trim()}${Platform.pathSeparator}$execName';
        if (await File(path).exists()) {
          return path;
        }
      }
    }

    // If we get here, we couldn't find the executable
    return null;
  }

  Future<Map<String, dynamic>> initialize(
      String rootUri, Map<String, dynamic> capabilities) async {
    return await sendRequest('initialize', {
      'processId': pid,
      'rootUri': rootUri,
      'capabilities': capabilities,
    });
  }

  Future<void> waitForInitialization() async {
    sendMessage({'jsonrpc': '2.0', 'method': 'initialized', 'params': {}});
  }

  void sendMessage(Map<String, dynamic> message) {
    _sendMessage(message);
  }

  void _setupMessageHandling() {
    languageServer?.stdout.transform(utf8.decoder).listen((String data) {
      if (data.trim().isNotEmpty) {
        _handleServerMessage(data);
      }
    }, onError: (error) {
      _logger.severe('Error from language server', error);
    });
  }

  void _handleServerMessage(String message) {
    try {
      // Split messages if multiple are received
      final messages = message
          .split('Content-Length: ')
          .where((m) => m.isNotEmpty)
          .map((m) => 'Content-Length: $m');

      for (var msg in messages) {
        String jsonContent = '';
        final headerEnd = msg.indexOf('\r\n\r\n');

        if (headerEnd != -1) {
          final lengthMatch = RegExp(r'Content-Length: (\d+)').firstMatch(msg);
          if (lengthMatch != null) {
            final length = int.parse(lengthMatch.group(1)!);
            final content = msg.substring(headerEnd + 4);
            if (content.length >= length) {
              jsonContent = content.substring(0, length);
            }
          }
        }

        if (jsonContent.isNotEmpty) {
          final response = jsonDecode(jsonContent);

          if (response.containsKey('method')) {
            if (response['method'] == 'workspace/configuration') {
              _onConfigurationRequest?.call(response);
            } else {
              _onNotification?.call(response);
            }
          } else if (response.containsKey('id')) {
            _handleServerResponse(response);
          }
        }
      }
    } catch (e, stack) {
      _logger.severe('Error handling server message', e, stack);
    }
  }

  void _handleServerResponse(Map<String, dynamic> response) {
    final id = response['id'] as int;
    final completer = _pendingRequests.remove(id);

    if (completer == null) {
      _logger.warning('No pending request found for id: $id');
      return;
    }

    if (response.containsKey('error')) {
      completer.completeError(response['error']);
    } else {
      completer.complete(response['result']);
    }
  }

  Future<Map<String, dynamic>> sendRequest(
      String method, Map<String, dynamic> params) async {
    final id = _messageId++;
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;

    try {
      final request = {
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params
      };

      _sendMessage(request);

      return await completer.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _pendingRequests.remove(id);
          throw TimeoutException('Request timed out: $method');
        },
      );
    } catch (e) {
      _pendingRequests.remove(id);
      throw Exception('Failed to send request: $e');
    }
  }

  void sendNotification(String method, Map<String, dynamic> params) {
    try {
      final notification = {
        'jsonrpc': '2.0',
        'method': method,
        'params': params
      };

      _sendMessage(notification);
    } catch (e) {
      _logger.severe('Failed to send notification', e);
    }
  }

  void _sendMessage(Map<String, dynamic> message) {
    final messageJson = jsonEncode(message);
    final fullMessage = 'Content-Length: ${messageJson.length}\r\n'
        'Content-Type: application/vscode-jsonrpc; charset=utf-8\r\n'
        '\r\n'
        '$messageJson';

    languageServer?.stdin.write(fullMessage);
    languageServer?.stdin.flush();
  }

  void dispose() {
    languageServer?.kill();
    _pendingRequests.clear();
  }
}
