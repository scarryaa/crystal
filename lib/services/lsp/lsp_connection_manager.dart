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
    languageServer = await Process.start(executable, args, environment: {
      'PATH': Platform.environment['PATH']!,
      'NODE_PATH': Platform.environment['NODE_PATH'] ?? ''
    });

    _setupMessageHandling();
  }

  Future<Map<String, dynamic>> initialize(
      String rootUri, Map<String, dynamic> capabilities) async {
    return await sendRequest('initialize', {
      'processId': pid,
      'rootUri': rootUri,
      'capabilities': capabilities,
      'trace': 'verbose'
    });
  }

  Future<void> waitForInitialization() async {
    await sendRequest('initialized', {});
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
