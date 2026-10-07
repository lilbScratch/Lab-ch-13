import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/my_transaction.dart';
import '../providers/transaction_provider.dart';
import 'add_edit_transaction_screen.dart';

class TransactionListScreen extends StatelessWidget {
  const TransactionListScreen({super.key});

  static const _incomeColor = Color(0xFF16845B);
  static const _expenseColor = Color(0xFFD3544A);

  String _money(double value) =>
      '฿${NumberFormat('#,##0.00').format(value)}';

  Future<void> _openForm(BuildContext context, [MyTransaction? transaction]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => AddEditTransactionScreen(transaction: transaction),
      ),
    );
  }

  Future<void> _delete(BuildContext context, MyTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรายการนี้?'),
        content: Text('ต้องการลบ “${transaction.title}” หรือไม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบรายการ'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TransactionProvider>().deleteTransaction(transaction.id!);
    }
  }

  Future<void> _showImportComparison(BuildContext context) async {
    final provider = context.read<TransactionProvider>();
    final method = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ทดสอบนำเข้า 100 รายการ'),
        content: const Text(
          'แต่ละวิธีจะเพิ่มรายการตัวอย่างลงในบัญชี เพื่อให้เปรียบเทียบเวลาได้จริง',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'single'),
            child: const Text('ทีละรายการ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'batch'),
            child: const Text('Batch'),
          ),
        ],
      ),
    );
    if (method == null || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(children: [
          CircularProgressIndicator(),
          SizedBox(width: 20),
          Text('กำลังนำเข้ารายการ...'),
        ]),
      ),
    );
    try {
      final elapsed = method == 'batch'
          ? await provider.importSamplesBatch()
          : await provider.importSamplesOneByOne();
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${method == 'batch' ? 'Batch' : 'ทีละรายการ'}: 100 รายการ ใช้เวลา ${elapsed.inMilliseconds} ms',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('นำเข้ารายการไม่สำเร็จ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('บัญชีของฉัน', style: TextStyle(fontWeight: FontWeight.w700)),
            Text('รายรับ · รายจ่าย', style: TextStyle(fontSize: 13, color: Colors.black54)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'เปรียบเทียบการนำเข้า 100 รายการ',
            icon: const Icon(Icons.speed_outlined),
            onPressed: () => _showImportComparison(context),
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          return RefreshIndicator(
            onRefresh: provider.fetchAndSetTransactions,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                _BalanceCard(
                  balance: provider.balance,
                  income: provider.incomeTotal,
                  expense: provider.expenseTotal,
                  money: _money,
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(
                      child: Text('รายการล่าสุด', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    ),
                    Text('${provider.transactions.length} รายการ', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
                const SizedBox(height: 12),
                if (provider.isLoading && provider.transactions.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (provider.error != null)
                  _ErrorMessage(onRetry: provider.fetchAndSetTransactions)
                else if (provider.transactions.isEmpty)
                  const _EmptyState()
                else
                  ...provider.transactions.map(
                    (tx) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TransactionTile(
                        transaction: tx,
                        amount: _money(tx.amount),
                        incomeColor: _incomeColor,
                        expenseColor: _expenseColor,
                        onTap: () => _openForm(context, tx),
                        onDelete: () => _delete(context, tx),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มรายการ'),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance, required this.income, required this.expense, required this.money});

  final double balance;
  final double income;
  final double expense;
  final String Function(double) money;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF176B5B), Color(0xFF238B72)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ยอดคงเหลือ', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(money(balance), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _BalanceItem(label: 'รายรับ', value: income, icon: Icons.south_west)),
              Expanded(child: _BalanceItem(label: 'รายจ่าย', value: expense, icon: Icons.north_east)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceItem extends StatelessWidget {
  const _BalanceItem({required this.label, required this.value, required this.icon});

  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('฿${NumberFormat('#,##0.00').format(value)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ]),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.amount, required this.incomeColor, required this.expenseColor, required this.onTap, required this.onDelete});

  final MyTransaction transaction;
  final String amount;
  final Color incomeColor;
  final Color expenseColor;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final color = isIncome ? incomeColor : expenseColor;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.10),
                foregroundColor: color,
                child: Icon(isIncome ? Icons.south_west : Icons.north_east),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(transaction.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      [
                        DateFormat('dd/MM/yyyy').format(transaction.date),
                        if (transaction.note?.trim().isNotEmpty == true)
                          transaction.note!.trim(),
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${isIncome ? '+' : '−'}$amount', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: 'ลบรายการ',
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline, size: 19, color: Colors.black45),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: const Column(children: [
          Icon(Icons.receipt_long_outlined, size: 42, color: Color(0xFF91A09A)),
          SizedBox(height: 12),
          Text('ยังไม่มีรายการ', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('กด “เพิ่มรายการ” เพื่อเริ่มบันทึกรายรับหรือรายจ่าย', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54)),
        ]),
      );
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Column(children: [
        const Text('โหลดข้อมูลไม่สำเร็จ'),
        TextButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
      ]);
}
