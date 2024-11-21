import 'package:crystal/services/lsp/lsp_connection_manager.dart';
import 'package:crystal/services/lsp_config_manager.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

class DocumentManager {
  final Map<String, int> _openDocuments = {};
  int _documentVersion = 1;
  final _logger = Logger('DocumentManager');
  final LSPConnectionManager _connection;

  DocumentManager(this._connection);

  Future<void> openDocument(String uri, String text, String languageId) async {
    try {
      await _connection.sendRequest('textDocument/didOpen', {
        'textDocument': {
          'uri': uri,
          'languageId': languageId,
          'version': _documentVersion++,
          'text': text
        }
      });
      _openDocuments[uri] = _documentVersion;
      _logger.info('Document opened: $uri');
    } catch (e, stackTrace) {
      _logger.severe('Failed to open document', e, stackTrace);
      rethrow;
    }
  }

  Future<void> updateDocument(String uri, String text) async {
    // If document isn't open, open it first
    if (!_openDocuments.containsKey(uri)) {
      _logger.info('Document not opened, opening first: $uri');
      // Get language ID from file extension
      final extension = p.extension(Uri.parse(uri).path);
      final languageId =
          await LSPConfigManager.getLanguageForExtension(extension) ??
              'plaintext';
      await openDocument(uri, text, languageId);
      return;
    }

    try {
      await _connection.sendRequest('textDocument/didChange', {
        'textDocument': {'uri': uri, 'version': _documentVersion++},
        'contentChanges': [
          {'text': text}
        ]
      });
      _openDocuments[uri] = _documentVersion;
      _logger.fine('Document updated: $uri');
    } catch (e) {
      _logger.severe('Failed to update document', e);
      rethrow;
    }
  }

  bool isDocumentOpen(String uri) {
    return _openDocuments.containsKey(uri);
  }

  Future<void> closeDocument(String uri) async {
    if (_openDocuments.containsKey(uri)) {
      await _connection.sendRequest('textDocument/didClose', {
        'textDocument': {'uri': uri}
      });
      _openDocuments.remove(uri);
      _logger.info('Document closed: $uri');
    }
  }
}
