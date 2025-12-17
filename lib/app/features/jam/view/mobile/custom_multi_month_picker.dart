import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomMultiMonthPicker extends StatefulWidget {
  final List<DateTime> jamDates;
  final List<DateTime> selectedDates;

  const CustomMultiMonthPicker({
    super.key,
    required this.jamDates,
    required this.selectedDates,
  });

  @override
  State<CustomMultiMonthPicker> createState() => _CustomMultiMonthPickerState();
}

class _CustomMultiMonthPickerState extends State<CustomMultiMonthPicker> {
  late List<DateTime> _currentSelection;
  final DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _currentSelection = List.from(widget.selectedDates);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _toggleDate(DateTime date) {
    setState(() {
      if (_currentSelection.any((d) => _isSameDay(d, date))) {
        _currentSelection.removeWhere((d) => _isSameDay(d, date));
      } else {
        _currentSelection.add(date);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final month1 = _now;
    final month2 = DateTime(_now.year, _now.month + 1);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Seleziona Date",
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildMonthView(month1),
                  const Divider(),
                  _buildMonthView(month2),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Annulla"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _currentSelection),
                  child: const Text("Conferma"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthView(DateTime monthDate) {
    final title = DateFormat('MMMM yyyy').format(monthDate);
    final daysInMonth = DateUtils.getDaysInMonth(monthDate.year, monthDate.month);
    final firstDayWeekday = DateTime(monthDate.year, monthDate.month, 1).weekday; // 1=Mon, 7=Sun

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0, left: 8.0),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: daysInMonth + (firstDayWeekday - 1),
            itemBuilder: (context, index) {
              if (index < firstDayWeekday - 1) {
                return const SizedBox();
              }
              final day = index - (firstDayWeekday - 1) + 1;
              final date = DateTime(monthDate.year, monthDate.month, day);

              final bool hasJam = widget.jamDates.any((d) => _isSameDay(d, date));
              final bool isSelected = _currentSelection.any((d) => _isSameDay(d, date));

              return GestureDetector(
                onTap: hasJam ? () => _toggleDate(date) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.green[900] // Dark green for selected
                        : hasJam
                            ? Colors.green[300] // Light green for available
                            : Colors.grey[300], // Grey for unavailable
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "$day",
                    style: TextStyle(
                      color: hasJam || isSelected ? Colors.black : Colors.grey[600],
                      fontWeight: hasJam ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
