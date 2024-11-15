import 'package:crystal/models/dialog_request.dart';
import 'package:crystal/services/dialog_service.dart';
import 'package:flutter/material.dart';

class DialogListener extends StatelessWidget {
  final Widget child;

  const DialogListener({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DialogRequest>(
        stream: DialogService().dialogStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              final result = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(snapshot.data!.title),
                  content: Text(snapshot.data!.message),
                  actions: snapshot.data!.actions
                      .map((action) => TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(action);
                            },
                            child: Text(action),
                          ))
                      .toList(),
                ),
              );
              DialogService().responseController.add(result ?? 'Cancel');
            });
          }
          return child;
        });
  }
}
