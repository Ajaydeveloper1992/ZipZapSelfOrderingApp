import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HeaderDateTime extends StatefulWidget {
  const HeaderDateTime({super.key});

  @override
  State<HeaderDateTime> createState() => _HeaderDateTimeState();
}

class _HeaderDateTimeState extends State<HeaderDateTime> {
  String _currentDate = '';
  String _currentTime = '';
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    // Update every second for real-time display
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateDateTime();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _getOrdinalSuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  void _updateDateTime() {
    final now = DateTime.now();
    setState(() {
      // Format: "Thursday, 13th Nov 2025"
      final dayName = DateFormat('EEEE').format(now);
      final day = now.day;
      final month = DateFormat('MMM').format(now);
      final year = now.year;
      _currentDate = '$dayName, $day${_getOrdinalSuffix(day)} $month $year';

      // Format: "12:20:92 AM" (hh:mm:ss a)
      _currentTime = DateFormat('hh:mm:ss a').format(now);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _currentDate,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          _currentTime,
          style: Theme.of(context).textTheme.bodySmall,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
