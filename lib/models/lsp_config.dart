import 'package:crystal/models/server_command.dart';

class LSPConfiguration {
  final Map<String, ServerCommand> serverCommands;

  LSPConfiguration({required this.serverCommands});

  factory LSPConfiguration.fromJson(Map<String, dynamic> json) {
    final commands = <String, ServerCommand>{};
    final serverConfigs = json['serverCommands'] as Map<String, dynamic>;

    serverConfigs.forEach((key, value) {
      commands[key] = ServerCommand(
        value['executable'] as String,
        (value['args'] as List<dynamic>).cast<String>(),
      );
    });

    return LSPConfiguration(serverCommands: commands);
  }
}
