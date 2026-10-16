import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../services/network_stats.dart';

/// Throughput line chart: download speed on the primary (blue) line and
/// upload speed on the tertiary (green) line, from [NetworkStats.history].
///
/// Shows a placeholder when no samples have been recorded yet.
class SpeedGraph extends StatelessWidget {
  final List<SpeedSample> samples;
  final double height;

  const SpeedGraph({
    super.key,
    required this.samples,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (samples.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Waiting for transfer data…',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    List<FlSpot> spots(Iterable<double> values) {
      var i = 0.0;
      return [for (final v in values) FlSpot(i++, v < 0 ? 0 : v)];
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          titlesData: const FlTitlesData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colorScheme.outlineVariant,
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots(samples.map((s) => s.downBps)),
              isCurved: true,
              color: colorScheme.primary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.primary.withValues(alpha: 0.15),
              ),
            ),
            LineChartBarData(
              spots: spots(samples.map((s) => s.upBps)),
              isCurved: true,
              color: colorScheme.tertiary,
              barWidth: 2,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: colorScheme.tertiary.withValues(alpha: 0.15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
