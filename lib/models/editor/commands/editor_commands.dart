import 'package:crystal/models/editor/commands/editing_commands.dart';
import 'package:crystal/models/editor/commands/file_commands.dart';
import 'package:crystal/models/editor/commands/navigation_commands.dart';

class EditorCommands {
  final FileCommands fileCommands;
  final NavigationCommands navigationCommands;
  final EditingCommands editingCommands;

  EditorCommands({
    required this.fileCommands,
    required this.navigationCommands,
    required this.editingCommands,
  });
}
