import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:crystal/models/editor/breadcrumb_item.dart';
import 'package:crystal/services/editor/symbol_collector_visitor.dart';
import 'package:crystal/utils/node_locator.dart';

class BreadcrumbGenerator {
  List<BreadcrumbItem> _allSymbols = [];

  List<BreadcrumbItem> getAllSymbols(String sourceCode) {
    final result = parseString(content: sourceCode, throwIfDiagnostics: false);
    final unit = result.unit;
    final lineInfo = result.lineInfo;

    final symbolCollector = SymbolCollectorVisitor(lineInfo);
    unit.accept(symbolCollector);

    _allSymbols = symbolCollector.symbols;
    return _allSymbols;
  }

  List<BreadcrumbItem> getSymbolsOfType(String type) {
    return _allSymbols.where((symbol) => symbol.type == type).toList();
  }

  List<BreadcrumbItem> generateBreadcrumbs(
      String sourceCode, int cursorOffset) {
    List<BreadcrumbItem> breadcrumbs = [];

    // Parse the code
    final result = parseString(content: sourceCode, throwIfDiagnostics: false);
    final unit = result.unit;
    final lineInfo = result.lineInfo;

    // Find the node at the cursor position
    final node = _findNode(unit, cursorOffset);

    // Traverse up the AST to build breadcrumbs
    AstNode? currentNode = node;
    while (currentNode != null) {
      if (currentNode is ClassDeclaration) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem('class', currentNode.name.lexeme, lineInfo,
                currentNode.offset));
      } else if (currentNode is MethodDeclaration) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem('method', currentNode.name.lexeme, lineInfo,
                currentNode.offset));
      } else if (currentNode is FunctionDeclaration) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem('function', currentNode.name.lexeme, lineInfo,
                currentNode.offset));
      } else if (currentNode is ConstructorDeclaration) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem(
                'constructor',
                currentNode.name?.lexeme ?? 'unnamed',
                lineInfo,
                currentNode.offset));
      } else if (currentNode is FieldDeclaration) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem(
                'field',
                currentNode.fields.variables.first.name.lexeme,
                lineInfo,
                currentNode.offset));
      } else if (currentNode is VariableDeclaration) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem('variable', currentNode.name.lexeme, lineInfo,
                currentNode.offset));
      } else if (currentNode is EnumDeclaration) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem(
                'enum', currentNode.name.lexeme, lineInfo, currentNode.offset));
      } else if (currentNode is MixinDeclaration) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem('mixin', currentNode.name.lexeme, lineInfo,
                currentNode.offset));
      } else if (currentNode is ExtensionDeclaration) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem(
                'extension',
                currentNode.name?.lexeme ?? 'unnamed',
                lineInfo,
                currentNode.offset));
      } else if (currentNode is TypeAlias) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem('typedef', currentNode.name.lexeme, lineInfo,
                currentNode.offset));
      } else if (currentNode is ForStatement) {
        breadcrumbs.insert(0,
            _createBreadcrumbItem('for', 'loop', lineInfo, currentNode.offset));
      } else if (currentNode is WhileStatement) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem(
                'while', 'loop', lineInfo, currentNode.offset));
      } else if (currentNode is DoStatement) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem(
                'do-while', 'loop', lineInfo, currentNode.offset));
      } else if (currentNode is IfStatement) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem(
                'if', 'statement', lineInfo, currentNode.offset));
      } else if (currentNode is SwitchStatement) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem(
                'switch', 'statement', lineInfo, currentNode.offset));
      } else if (currentNode is TryStatement) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem(
                'try', 'block', lineInfo, currentNode.offset));
      } else if (currentNode is CatchClause) {
        breadcrumbs.insert(
            0,
            _createBreadcrumbItem(
                'catch', 'clause', lineInfo, currentNode.offset));
      }

      currentNode = currentNode.parent;
    }

    return breadcrumbs;
  }

  BreadcrumbItem _createBreadcrumbItem(
      String type, String name, LineInfo lineInfo, int offset) {
    final location = lineInfo.getLocation(offset);
    return BreadcrumbItem(
      type: type,
      name: name,
      line: location.lineNumber,
      column: location.columnNumber,
    );
  }

  AstNode? _findNode(CompilationUnit unit, int offset) {
    var visitor = NodeLocator(offset);
    unit.accept(visitor);
    return visitor.foundNode;
  }
}
