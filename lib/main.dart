import 'package:flutter/material.dart';
import 'package:gsheets/gsheets.dart';
import 'package:intl/intl.dart';

// ⚡️ Ключ будет предоставлен автоматически при сборке приложения.
const _credentials = String.fromEnvironment('GCP_CREDENTIALS');

// ⚡️ Вставь сюда ID таблицы (из URL Google Sheets)
const _spreadsheetId = '1c7IH67rCHF7LnjINuwrKASCbyq-gp21a8mpAa8y4Elk';

void main() {
  runApp(const WorkLogApp());
}

class WorkLogApp extends StatelessWidget {
  const WorkLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Учёт рабочего времени',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const WorkLogForm(),
    );
  }
}

class WorkLogForm extends StatefulWidget {
  const WorkLogForm({super.key});

  @override
  State<WorkLogForm> createState() => _WorkLogFormState();
}

class _WorkLogFormState extends State<WorkLogForm> {
  final _projectController = TextEditingController();
  final _taskController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int _breakMinutes = 0;

  bool _saving = false;
  late GSheets _gsheets;
  Worksheet? _sheet;

  @override
  void initState() {
    super.initState();
    _initSheets();
  }

  Future<void> _initSheets() async {
    _gsheets = GSheets(_credentials);
    final ss = await _gsheets.spreadsheet(_spreadsheetId);
    _sheet = ss.worksheetByTitle('Лист1') ?? await ss.addWorksheet('Лист1');
  }

  double _calculateDuration() {
    if (_startTime == null || _endTime == null) return 0;

    var start = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _startTime!.hour, _startTime!.minute);
    var end = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _endTime!.hour, _endTime!.minute);

    if (end.isBefore(start)) {
      end = end.add(const Duration(days: 1));
    }

    final diff = end.difference(start).inMinutes - _breakMinutes;
    return diff > 0 ? diff / 60.0 : 0;
  }

  Future<void> _saveRecord() async {
    if (_sheet == null) return;
    setState(() => _saving = true);

    final duration = _calculateDuration();
    final row = [
      DateFormat('yyyy-MM-dd').format(_selectedDate),
      _projectController.text,
      _taskController.text,
      _startTime?.format(context) ?? '',
      _endTime?.format(context) ?? '',
      _breakMinutes.toString(),
      duration.toStringAsFixed(2),
      _notesController.text,
      "user123" // ⚡️ Здесь должен быть ID пользователя (например, Firebase UID)
    ];

    await _sheet!.values.appendRow(row);

    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Запись сохранена!')),
    );

    _projectController.clear();
    _taskController.clear();
    _notesController.clear();
    _startTime = null;
    _endTime = null;
    _breakMinutes = 0;
  }

  Future<void> _pickTime(bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        if (isStart) {
          _startTime = time;
        } else {
          _endTime = time;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Учёт рабочего времени')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _projectController,
              decoration: const InputDecoration(labelText: 'Проект'),
            ),
            TextField(
              controller: _taskController,
              decoration: const InputDecoration(labelText: 'Задача'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickTime(true),
                    child: Text(_startTime == null
                        ? 'Начало'
                        : 'Начало: ${_startTime!.format(context)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _pickTime(false),
                    child: Text(_endTime == null
                        ? 'Конец'
                        : 'Конец: ${_endTime!.format(context)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Перерыв (минуты)'),
              onChanged: (v) =>
                  setState(() => _breakMinutes = int.tryParse(v) ?? 0),
            ),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Примечания'),
            ),
            const SizedBox(height: 20),
            Text('Длительность: ${_calculateDuration().toStringAsFixed(2)} ч'),
            const SizedBox(height: 20),
            _saving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                onPressed: _saveRecord, child: const Text('Сохранить')),
          ],
        ),
      ),
    );
  }
}
