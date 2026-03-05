import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:jk_inventory_system/models/outing_record.dart';
import 'package:jk_inventory_system/models/product.dart';
import 'package:jk_inventory_system/providers/outing_provider.dart';
import 'package:jk_inventory_system/providers/product_provider.dart';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({
    super.key,
    required this.productProvider,
    required this.outingProvider,
  });

  final ProductProvider productProvider;
  final OutingProvider outingProvider;

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.productProvider, widget.outingProvider]),
      builder: (context, _) {
        final products = widget.productProvider.items;
        final outings = widget.outingProvider.history;
        final analytics = _buildAnalytics(
          products: products,
          outings: outings,
          selectedMonth: _selectedMonth,
        );

        return ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _changeMonth(-1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Text(
                            DateFormat('MMMM yyyy').format(_selectedMonth),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _changeMonth(1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Profit from Capital',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    _SummaryRow(label: 'Capital', value: analytics.totalCapital),
                    _SummaryRow(label: 'Gross Sales', value: analytics.totalGross),
                    _SummaryRow(label: 'Profit', value: analytics.totalProfit, emphasize: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showAllMonthlyItems(context, analytics.allSorted),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Highest Gross Items (Top 5)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (analytics.topFive.isEmpty)
                        const Text('No sold data for this month.')
                      else
                        ...analytics.topFive.map((item) => _RankTile(item: item)),
                      const SizedBox(height: 12),
                      Divider(color: Theme.of(context).dividerColor),
                      const SizedBox(height: 12),
                      Text('Lowest Gross Items (Bottom 3)', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      if (analytics.bottomThree.isEmpty)
                        const Text('No sold data for this month.')
                      else
                        ...analytics.bottomThree.map((item) => _RankTile(item: item)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 16,
                            color: Theme.of(context).hintColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tap to view full list',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).hintColor,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Week Graph: Sold vs Returned', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _LegendRow(
                      firstLabel: 'Sold',
                      firstColor: Colors.teal,
                      secondLabel: 'Returned',
                      secondColor: Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _WeeklyBarChart(
                      labels: analytics.weekLabels,
                      firstValues: analytics.weekSold,
                      secondValues: analytics.weekReturned,
                      firstColor: Colors.teal,
                      secondColor: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Week Graph: Discarded vs Replaced', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _LegendRow(
                      firstLabel: 'Discarded',
                      firstColor: Colors.red,
                      secondLabel: 'Replaced',
                      secondColor: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _WeeklyBarChart(
                      labels: analytics.weekLabels,
                      firstValues: analytics.weekDiscarded,
                      secondValues: analytics.weekReplaced,
                      firstColor: Colors.red,
                      secondColor: Colors.orange,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAllMonthlyItems(BuildContext context, List<_ProductGrossStat> items) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.8,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Gross Ranking', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Expanded(
                    child: items.isEmpty
                        ? const Center(child: Text('No sold data for this month.'))
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return ListTile(
                                dense: true,
                                title: Text('${index + 1}. ${item.productName}'),
                                subtitle: Text('Sold: ${item.sold.toStringAsFixed(2)}'),
                                trailing: Text(_currency(item.gross)),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label),
          const Spacer(),
          Text(_currency(value), style: style),
        ],
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({required this.item});

  final _ProductGrossStat item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(item.productName),
      subtitle: Text('Sold: ${item.sold.toStringAsFixed(2)}'),
      trailing: Text(_currency(item.gross)),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.firstLabel,
    required this.firstColor,
    required this.secondLabel,
    required this.secondColor,
  });

  final String firstLabel;
  final Color firstColor;
  final String secondLabel;
  final Color secondColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _LegendDot(label: firstLabel, color: firstColor),
        const SizedBox(width: 16),
        _LegendDot(label: secondLabel, color: secondColor),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({
    required this.labels,
    required this.firstValues,
    required this.secondValues,
    required this.firstColor,
    required this.secondColor,
  });

  final List<String> labels;
  final List<double> firstValues;
  final List<double> secondValues;
  final Color firstColor;
  final Color secondColor;

  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(
      firstValues.isEmpty ? 0 : firstValues.reduce(math.max),
      secondValues.isEmpty ? 0 : secondValues.reduce(math.max),
    );
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return SizedBox(
      height: 170,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(labels.length, (index) {
          final first = firstValues[index];
          final second = secondValues[index];
          final firstH = (first / safeMax) * 110;
          final secondH = (second / safeMax) * 110;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: first <= 0 ? 2 : firstH,
                        decoration: BoxDecoration(
                          color: firstColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        width: 10,
                        height: second <= 0 ? 2 : secondH,
                        decoration: BoxDecoration(
                          color: secondColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(labels[index], style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _AnalyticsData {
  _AnalyticsData({
    required this.topFive,
    required this.bottomThree,
    required this.allSorted,
    required this.totalGross,
    required this.totalCapital,
    required this.totalProfit,
    required this.weekLabels,
    required this.weekSold,
    required this.weekReturned,
    required this.weekDiscarded,
    required this.weekReplaced,
  });

  final List<_ProductGrossStat> topFive;
  final List<_ProductGrossStat> bottomThree;
  final List<_ProductGrossStat> allSorted;
  final double totalGross;
  final double totalCapital;
  final double totalProfit;
  final List<String> weekLabels;
  final List<double> weekSold;
  final List<double> weekReturned;
  final List<double> weekDiscarded;
  final List<double> weekReplaced;
}

class _ProductGrossStat {
  _ProductGrossStat({
    required this.productId,
    required this.productName,
    required this.sold,
    required this.gross,
    required this.capital,
  });

  final String productId;
  final String productName;
  final double sold;
  final double gross;
  final double capital;
}

_AnalyticsData _buildAnalytics({
  required List<Product> products,
  required List<OutingRecord> outings,
  required DateTime selectedMonth,
}) {
  final productMap = <String, Product>{for (final p in products) p.id: p};
  final monthOutings = outings.where((record) {
    return record.date.year == selectedMonth.year && record.date.month == selectedMonth.month;
  }).toList();

  final soldByProduct = <String, double>{};
  final returnedByDay = <DateTime, double>{};
  final soldByDay = <DateTime, double>{};
  final discardedByDay = <DateTime, double>{};
  final replacedByDay = <DateTime, double>{};

  for (final record in monthOutings) {
    final displayedMap = <String, double>{};
    final returnedMap = <String, double>{};
    final replacedMap = <String, double>{};

    for (final line in record.displayedProducts) {
      displayedMap.update(line.productId, (v) => v + line.value, ifAbsent: () => line.value);
    }
    for (final line in record.returnedProducts) {
      returnedMap.update(line.productId, (v) => v + line.value, ifAbsent: () => line.value);
    }
    for (final line in record.replacedDiscardedProducts) {
      replacedMap.update(line.productId, (v) => v + line.value, ifAbsent: () => line.value);
    }

    final productIds = {...displayedMap.keys, ...returnedMap.keys, ...replacedMap.keys};
    for (final productId in productIds) {
      final sold = (displayedMap[productId] ?? 0) - (returnedMap[productId] ?? 0) + (replacedMap[productId] ?? 0);
      if (sold > 0) {
        soldByProduct.update(productId, (v) => v + sold, ifAbsent: () => sold);
      }
    }
  }

  final allStats = soldByProduct.entries.map((entry) {
    final product = productMap[entry.key];
    final gross = entry.value * (product?.sellingPrice ?? 0);
    final capital = entry.value * (product?.costPrice ?? 0);
    return _ProductGrossStat(
      productId: entry.key,
      productName: product?.name ?? 'Unknown Product',
      sold: entry.value,
      gross: gross,
      capital: capital,
    );
  }).toList();

  allStats.sort((a, b) => b.gross.compareTo(a.gross));
  final topFive = allStats.take(5).toList();

  final ascending = List<_ProductGrossStat>.from(allStats)..sort((a, b) => a.gross.compareTo(b.gross));
  final bottomThree = ascending.take(3).toList();

  final totalGross = allStats.fold<double>(0, (sum, item) => sum + item.gross);
  final totalCapital = allStats.fold<double>(0, (sum, item) => sum + item.capital);
  final totalProfit = totalGross - totalCapital;

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(Duration(days: today.weekday - DateTime.monday));
  final weekDays = List.generate(7, (index) => monday.add(Duration(days: index)));
  final weekMap = <DateTime, List<OutingRecord>>{};

  for (final day in weekDays) {
    weekMap[day] = [];
  }

  for (final record in outings) {
    final day = DateTime(record.date.year, record.date.month, record.date.day);
    if (weekMap.containsKey(day)) {
      weekMap[day]!.add(record);
    }
  }

  for (final day in weekDays) {
    final records = weekMap[day] ?? const <OutingRecord>[];
    var dayDisplayed = 0.0;
    var dayReturned = 0.0;
    var dayDiscarded = 0.0;
    var dayReplaced = 0.0;

    for (final record in records) {
      for (final line in record.displayedProducts) {
        dayDisplayed += line.value;
      }
      for (final line in record.returnedProducts) {
        dayReturned += line.value;
      }
      for (final line in record.discardedProducts) {
        dayDiscarded += line.value;
      }
      for (final line in record.replacedDiscardedProducts) {
        dayReplaced += line.value;
      }
    }

    final daySold = dayDisplayed - dayReturned + dayReplaced;
    soldByDay[day] = daySold > 0 ? daySold : 0;
    returnedByDay[day] = dayReturned;
    discardedByDay[day] = dayDiscarded;
    replacedByDay[day] = dayReplaced;
  }

  return _AnalyticsData(
    topFive: topFive,
    bottomThree: bottomThree,
    allSorted: allStats,
    totalGross: totalGross,
    totalCapital: totalCapital,
    totalProfit: totalProfit,
    weekLabels: weekDays.map((d) => DateFormat('E').format(d)).toList(),
    weekSold: weekDays.map((d) => soldByDay[d] ?? 0).toList(),
    weekReturned: weekDays.map((d) => returnedByDay[d] ?? 0).toList(),
    weekDiscarded: weekDays.map((d) => discardedByDay[d] ?? 0).toList(),
    weekReplaced: weekDays.map((d) => replacedByDay[d] ?? 0).toList(),
  );
}

String _currency(double value) {
  return NumberFormat.currency(symbol: '₱', decimalDigits: 2).format(value);
}
