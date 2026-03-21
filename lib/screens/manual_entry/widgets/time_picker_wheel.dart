import 'package:flutter/material.dart';

import '../../../core/tokens.dart';

class TimePickerWheel extends StatefulWidget {
  const TimePickerWheel({
    super.key,
    required this.onChanged,
    this.initialMinutes = 0,
    this.initialSeconds = 0,
  });

  final void Function(int totalSeconds) onChanged;
  final int initialMinutes;
  final int initialSeconds;

  @override
  State<TimePickerWheel> createState() => _TimePickerWheelState();
}

class _TimePickerWheelState extends State<TimePickerWheel> {
  late final FixedExtentScrollController _minuteController;
  late final FixedExtentScrollController _secondController;
  int _minutes = 0;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialMinutes;
    _seconds = widget.initialSeconds;
    _minuteController = FixedExtentScrollController(initialItem: _minutes);
    _secondController = FixedExtentScrollController(initialItem: _seconds);
  }

  @override
  void dispose() {
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _emit() => widget.onChanged(_minutes * 60 + _seconds);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _wheel(
            controller: _minuteController,
            itemCount: 180,
            onChanged: (v) {
              _minutes = v;
              _emit();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(':', style: Tokens.headingL),
          ),
          _wheel(
            controller: _secondController,
            itemCount: 60,
            onChanged: (v) {
              _seconds = v;
              _emit();
            },
          ),
        ],
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 64,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 40,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: itemCount,
          builder: (context, index) => Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: Tokens.headingL.copyWith(color: Tokens.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
