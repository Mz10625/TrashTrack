import 'dart:async';
import 'package:flutter/material.dart';

class CountdownTimer extends StatefulWidget {
  final DateTime startTime;
  final int durationHours;

  const CountdownTimer({
    Key? key,
    required this.startTime,
    required this.durationHours,
  }) : super(key: key);

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  Timer? _timer;
  late String _timeRemaining;

  @override
  void initState() {
    super.initState();
    _calculateTimeRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _calculateTimeRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateTimeRemaining() {
    DateTime endTime = widget.startTime.add(Duration(hours: widget.durationHours));
    Duration remaining = endTime.difference(DateTime.now());

    if (remaining.isNegative) {
      setState(() {
        _timeRemaining = '00:00:00';
      });
      return;
    }

    int hours = remaining.inHours;
    int minutes = remaining.inMinutes.remainder(60);
    int seconds = remaining.inSeconds.remainder(60);

    setState(() {
      _timeRemaining = '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _timeRemaining,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontFamily: 'Courier',
      ),
    );
  }
}