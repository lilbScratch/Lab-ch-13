import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/my_transaction.dart';
import '../providers/transaction_provider.dart';

class AddEditTransactionScreen extends StatefulWidget {
  const AddEditTransactionScreen({super.key, this.transaction});

  final MyTransaction? transaction;

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late DateTime _date;
  late TransactionType _type;
  bool _isSaving = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _titleController = TextEditingController(text: transaction?.title ?? '');
    _amountController = TextEditingController(
      text: transaction == null ? '' : transaction.amount.toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: transaction?.note ?? '');
    _date = transaction?.date ?? DateTime.now();
    _type = transaction?.type ?? TransactionType.expense;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    final amount = double.parse(
      _amountController.text.trim().replaceAll(',', ''),
    );
    final transaction = MyTransaction(
      id: widget.transaction?.id,
      title: _titleController.text.trim(),
      amount: amount,
      date: _date,
      type: _type,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    try {
      final provider = context.read<TransactionProvider>();
      if (_isEditing) {
        await provider.updateTransaction(transaction);
      } else {
        await provider.addTransaction(transaction);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกไม่สำเร็จ กรุณาลองอีกครั้ง')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'แก้ไขรายการ' : 'เพิ่มรายการ')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('รายจ่าย'),
                    icon: Icon(Icons.north_east),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('รายรับ'),
                    icon: Icon(Icons.south_west),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'ชื่อรายการ',
                  hintText: 'เช่น เงินเดือน, ค่าอาหาร',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'กรุณากรอกชื่อรายการ'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'จำนวนเงิน',
                  prefixText: '฿ ',
                ),
                validator: (value) {
                  final amount = double.tryParse(
                    (value ?? '').trim().replaceAll(',', ''),
                  );
                  if (amount == null || !amount.isFinite || amount <= 0) {
                    return 'กรอกจำนวนเงินที่มากกว่า 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'บันทึกเพิ่มเติม (ไม่บังคับ)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(
                  'วันที่  ${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_isEditing ? 'บันทึกการแก้ไข' : 'บันทึกรายการ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
