import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class SwipeRemove extends StatefulWidget {
  const SwipeRemove({
    super.key,
    required this.label,
    required this.onRemove,
    required this.child,
  });
  final String label;
  final Future<void> Function() onRemove;
  final Widget child;

  @override
  State<SwipeRemove> createState() => _SwipeRemoveState();
}

class _SwipeRemoveState extends State<SwipeRemove> {
  double _progress = 0;

  @override
  Widget build(BuildContext context) => Semantics(
    customSemanticsActions: {
      CustomSemanticsAction(label: widget.label): widget.onRemove,
    },
    child: Dismissible(
      key: ValueKey(widget.key),
      direction: DismissDirection.endToStart,
      onUpdate: (details) => setState(() => _progress = details.progress),
      // The backing list removes the row after the operation succeeds.
      confirmDismiss: (_) async {
        await widget.onRemove();
        return false;
      },
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        color: Color.lerp(
          const Color(0xffd79595),
          const Color(0xffb3261e),
          (_progress / .4).clamp(0, 1),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: widget.child,
    ),
  );
}
