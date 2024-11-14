import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class NodeLocator extends GeneralizingAstVisitor<void> {
  final int offset;
  AstNode? foundNode;

  NodeLocator(this.offset);

  @override
  void visitNode(AstNode node) {
    if (node.offset <= offset && offset <= node.end) {
      foundNode = node;
      super.visitNode(node);
    }
  }
}
