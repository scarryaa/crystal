import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:crystal/models/editor/breadcrumb_item.dart';

class SymbolCollectorVisitor extends RecursiveAstVisitor<void> {
  final List<BreadcrumbItem> symbols = [];
  final LineInfo lineInfo;

  SymbolCollectorVisitor(this.lineInfo);

  void _addSymbol(String type, String name, int offset) {
    final location = lineInfo.getLocation(offset);
    symbols.add(BreadcrumbItem(
      type: type,
      name: name,
      line: location.lineNumber,
      column: location.columnNumber,
    ));
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _addSymbol('class', node.name.lexeme, node.name.offset);
    super.visitClassDeclaration(node);
  }

  @override
  void visitMethodDeclaration(MethodDeclaration node) {
    _addSymbol('method', node.name.lexeme, node.name.offset);
    super.visitMethodDeclaration(node);
  }

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    _addSymbol('function', node.name.lexeme, node.name.offset);
    super.visitFunctionDeclaration(node);
  }

  @override
  void visitConstructorDeclaration(ConstructorDeclaration node) {
    _addSymbol('constructor', node.name?.lexeme ?? 'unnamed', node.offset);
    super.visitConstructorDeclaration(node);
  }

  @override
  void visitFieldDeclaration(FieldDeclaration node) {
    for (var variable in node.fields.variables) {
      _addSymbol('field', variable.name.lexeme, variable.name.offset);
    }
    super.visitFieldDeclaration(node);
  }

  @override
  void visitTopLevelVariableDeclaration(TopLevelVariableDeclaration node) {
    for (var variable in node.variables.variables) {
      _addSymbol('variable', variable.name.lexeme, variable.name.offset);
    }
    super.visitTopLevelVariableDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    _addSymbol('enum', node.name.lexeme, node.name.offset);
    super.visitEnumDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    _addSymbol('mixin', node.name.lexeme, node.name.offset);
    super.visitMixinDeclaration(node);
  }

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) {
    _addSymbol('extension', node.name?.lexeme ?? 'unnamed', node.offset);
    super.visitExtensionDeclaration(node);
  }

  @override
  void visitGenericTypeAlias(GenericTypeAlias node) {
    _addSymbol('typedef', node.name.lexeme, node.name.offset);
    super.visitGenericTypeAlias(node);
  }
}
