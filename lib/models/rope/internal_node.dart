import 'package:crystal/models/rope/node.dart';

class InternalNode extends Node {
  Node? left;
  Node? right;

  @override
  int weight = 0;
}
