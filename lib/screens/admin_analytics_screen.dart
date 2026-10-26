import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../models/admin_analytics.dart';
import '../services/admin_analytics_service.dart';
import '../ui/app_shell.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  final String userName;

  const AdminAnalyticsScreen({
    super.key,
    required this.userName,
  });

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _service = AdminAnalyticsService();
  late Future<AdminAnalytics> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getAnalytics();
  }

  void _reload() {
    setState(() {
      _future = _service.getAnalytics();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      endDrawer: AppMenuDrawer(
        userName: widget.userName,
        activeScreen: 'Analytics',
        onClose: () => Navigator.of(context).pop(),
      ),
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              AppTopBar(
                onBack: () => Navigator.of(context).pop(),
                onMenu: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              LayoutBuilder(
                builder: (context, constraints) => Text(
                  'Analytics',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: kVividBlue,
                    fontSize: constraints.maxWidth < 390 ? 30 : 38,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<AdminAnalytics>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      );
                    }
                    if (snapshot.hasError) {
                      return _ErrorState(
                        message: _messageFor(snapshot.error!),
                        onRetry: _reload,
                      );
                    }
                    return _AnalyticsContent(
                      data: snapshot.requireData,
                      onRefresh: () async => _reload(),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  final AdminAnalytics data;
  final Future<void> Function() onRefresh;

  const _AnalyticsContent({
    required this.data,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 520;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(narrow ? 12 : 28, 0, narrow ? 12 : 28, 28),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  narrow ? 12 : 18,
                  16,
                  narrow ? 12 : 18,
                  18,
                ),
                color: Colors.white,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RatingBanner(summary: data.summary),
                    const SizedBox(height: 18),
                    const _SectionTitle('Monthly number of users:'),
                    _ChartBox(
                      height: 245,
                      child: CustomPaint(
                        painter: _LineChartPainter(data.monthlyUsers),
                      ),
                    ),
                    const SizedBox(height: 18),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final narrow = constraints.maxWidth < 760;
                        final charts = [
                          _MiniChartCard(
                            title: 'Sex:',
                            child: CustomPaint(
                              painter: _BarChartPainter(data.sexCounts),
                            ),
                          ),
                          _MiniChartCard(
                            title: 'Age of Users',
                            child: CustomPaint(
                              painter: _PieChartPainter(data.ageCounts),
                            ),
                          ),
                          _MiniChartCard(
                            title: 'User activity:',
                            child: CustomPaint(
                              painter: _DonutChartPainter(data.usageCounts),
                            ),
                          ),
                        ];
                        return narrow
                            ? Column(
                                children: charts
                                    .map((chart) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: chart,
                                        ))
                                    .toList(),
                              )
                            : Row(
                                children: charts
                                    .map((chart) => Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                                right: 12),
                                            child: chart,
                                          ),
                                        ))
                                    .toList(),
                              );
                      },
                    ),
                    const SizedBox(height: 18),
                    const _SectionTitle('Users'),
                    _UsersTable(users: data.users),
                    const SizedBox(height: 22),
                    _RatingsPanel(reviews: data.reviews),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBanner extends StatelessWidget {
  final AnalyticsSummary summary;

  const _RatingBanner({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF62DDE4),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Rate:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${summary.averageRating.toStringAsFixed(1)}/5',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 29,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${summary.ratingCount} ratings',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(width: 28),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: List.generate(5, (index) {
                  final filled = summary.averageRating >= index + 0.75;
                  final half = !filled && summary.averageRating > index + 0.25;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      filled
                          ? Icons.star_rounded
                          : half
                              ? Icons.star_half_rounded
                              : Icons.star_border_rounded,
                      color: const Color(0xFFFFF35A),
                      size: 66,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartBox extends StatelessWidget {
  final double height;
  final Widget child;

  const _ChartBox({
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFD6DDE8)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class _MiniChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _MiniChartCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1F2430),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _ChartBox(height: 170, child: child),
          ),
        ],
      ),
    );
  }
}

class _UsersTable extends StatelessWidget {
  final List<AnalyticsUser> users;

  const _UsersTable({required this.users});

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const _EmptyPanel(message: 'No users yet.');
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF5F7FA)),
          columnSpacing: 26,
          columns: const [
            DataColumn(label: _TableHead('NAME')),
            DataColumn(label: _TableHead('EMAIL')),
            DataColumn(label: _TableHead('Address')),
            DataColumn(label: _TableHead('Phone')),
            DataColumn(label: _TableHead('Sex')),
            DataColumn(label: _TableHead('Date')),
            DataColumn(label: _TableHead('Stars')),
          ],
          rows: users.take(20).map((user) {
            return DataRow(
              cells: [
                DataCell(_CellText(user.name, bold: true)),
                DataCell(_CellText(user.email)),
                DataCell(_CellText(user.address.isEmpty ? '-' : user.address)),
                DataCell(_CellText(user.phone.isEmpty ? '-' : user.phone)),
                DataCell(_CellText(user.sex.isEmpty ? '-' : user.sex)),
                DataCell(_CellText(_date(user.date))),
                DataCell(_CellText(user.stars.toString())),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _RatingsPanel extends StatelessWidget {
  final List<AnalyticsReview> reviews;

  const _RatingsPanel({required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF2DB2EC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'User Rating',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          if (reviews.isEmpty)
            const _EmptyPanel(message: 'No user ratings yet.')
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 820 ? 3 : 1;
                final width =
                    (constraints.maxWidth - (columns - 1) * 16) / columns;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: reviews.take(6).map((review) {
                    return SizedBox(
                      width: width,
                      child: _ReviewCard(review: review),
                    );
                  }).toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final AnalyticsReview review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 158,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE9F1F8),
                backgroundImage: review.photoUrl.isEmpty
                    ? null
                    : NetworkImage(review.photoUrl),
                child: review.photoUrl.isEmpty
                    ? const Icon(Icons.person_rounded, color: Color(0xFF148AB8))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF20242E),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < review.rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFF8C929),
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _daysAgo(review.date),
                style: const TextStyle(color: Color(0xFF8A94A6), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Text(
              review.review.isEmpty ? 'No written review.' : review.review,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF2F3541),
                fontSize: 12,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<MonthlyUsersPoint> points;

  _LineChartPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 44.0;
    const right = 18.0;
    const top = 18.0;
    const bottom = 42.0;
    final chart =
        Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final grid = Paint()
      ..color = const Color(0xFFE9EDF3)
      ..strokeWidth = 1;
    final axis = Paint()
      ..color = const Color(0xFFCAD2DE)
      ..strokeWidth = 1.2;
    final line = Paint()
      ..color = const Color(0xFF65D8D2)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = const Color(0xFF65D8D2);
    final maxValue =
        math.max(1, points.fold<int>(0, (max, p) => math.max(max, p.count)));

    for (var i = 0; i <= 5; i++) {
      final y = chart.bottom - chart.height * i / 5;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      _drawText(canvas, '${(maxValue * i / 5).round()}', Offset(8, y - 7), 11);
    }
    canvas.drawRect(chart, axis..style = PaintingStyle.stroke);

    if (points.isEmpty) return;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = points.length == 1
          ? chart.center.dx
          : chart.left + chart.width * i / (points.length - 1);
      final y = chart.bottom - chart.height * points[i].count / maxValue;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, dot);
      _drawText(canvas, points[i].count.toString(), Offset(x - 5, y - 18), 10);
      if (i.isEven || size.width > 720) {
        _drawText(
            canvas, points[i].label, Offset(x - 24, chart.bottom + 12), 10);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _BarChartPainter extends CustomPainter {
  final List<AnalyticsCount> counts;

  _BarChartPainter(this.counts);

  @override
  void paint(Canvas canvas, Size size) {
    final usable = counts.where((item) => item.count > 0).toList();
    final values =
        usable.isEmpty ? counts.take(2).toList() : usable.take(4).toList();
    final maxValue =
        math.max(1, values.fold<int>(0, (max, p) => math.max(max, p.count)));
    final colors = [
      const Color(0xFFF97068),
      const Color(0xFF19BFC4),
      kAccent,
      const Color(0xFFFFB347)
    ];
    final chart = Rect.fromLTRB(28, 14, size.width - 14, size.height - 36);
    final width = chart.width / math.max(1, values.length);

    for (var i = 0; i < values.length; i++) {
      final barHeight = chart.height * values[i].count / maxValue;
      final rect = Rect.fromLTWH(
        chart.left + i * width + width * 0.18,
        chart.bottom - barHeight,
        width * 0.64,
        barHeight,
      );
      canvas.drawRect(rect, Paint()..color = colors[i % colors.length]);
      _drawText(canvas, values[i].count.toString(),
          Offset(rect.center.dx - 6, rect.top - 14), 10);
      _drawText(
          canvas, values[i].label, Offset(rect.left, chart.bottom + 10), 10);
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.counts != counts;
}

class _PieChartPainter extends CustomPainter {
  final List<AnalyticsCount> counts;

  _PieChartPainter(this.counts);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFFE63714),
      const Color(0xFFFFA600),
      const Color(0xFF1ABD43),
      const Color(0xFF9D35D2),
      const Color(0xFF2F86FF),
      const Color(0xFF7A869A),
      const Color(0xFFCBD5E1),
    ];
    _drawCircularChart(canvas, size, counts, colors, donut: false);
  }

  @override
  bool shouldRepaint(covariant _PieChartPainter oldDelegate) =>
      oldDelegate.counts != counts;
}

class _DonutChartPainter extends CustomPainter {
  final List<AnalyticsCount> counts;

  _DonutChartPainter(this.counts);

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xFF2BB2EA),
      const Color(0xFF54D76A),
      const Color(0xFFB86ADB),
      const Color(0xFFFFB445),
    ];
    _drawCircularChart(canvas, size, counts, colors, donut: true);
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.counts != counts;
}

void _drawCircularChart(
  Canvas canvas,
  Size size,
  List<AnalyticsCount> counts,
  List<Color> colors, {
  required bool donut,
}) {
  final total = counts.fold<int>(0, (sum, item) => sum + item.count);
  final center = Offset(size.width * 0.36, size.height * 0.5);
  final radius = math.min(size.width, size.height) * 0.32;
  final rect = Rect.fromCircle(center: center, radius: radius);
  var start = -math.pi / 2;

  if (total == 0) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFE7EDF5));
  } else {
    for (var i = 0; i < counts.length; i++) {
      final sweep = (counts[i].count / total) * math.pi * 2;
      canvas.drawArc(
          rect, start, sweep, true, Paint()..color = colors[i % colors.length]);
      start += sweep;
    }
  }

  if (donut) {
    canvas.drawCircle(center, radius * 0.58, Paint()..color = Colors.white);
  }

  for (var i = 0; i < counts.length; i++) {
    final y = 24.0 + i * 24.0;
    final x = size.width * 0.68;
    canvas.drawCircle(
        Offset(x, y + 5), 5, Paint()..color = colors[i % colors.length]);
    _drawText(canvas, counts[i].label, Offset(x + 12, y), 11);
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF20242E),
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TableHead extends StatelessWidget {
  final String text;

  const _TableHead(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF687386),
        fontSize: 11,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CellText extends StatelessWidget {
  final String text;
  final bool bold;

  const _CellText(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 190),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: const Color(0xFF2F3541),
          fontSize: 12,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w500,
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final String message;

  const _EmptyPanel({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF596273),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33002693),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: kDeepBlue,
                size: 42,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF17354C),
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),
              GlassButton(label: 'Retry', onTap: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

void _drawText(Canvas canvas, String text, Offset offset, double size) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: const Color(0xFF687386),
        fontSize: size,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: 90);
  painter.paint(canvas, offset);
}

String _date(DateTime? date) {
  if (date == null) return '-';
  return '${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}/${date.year}';
}

String _daysAgo(DateTime? date) {
  if (date == null) return '';
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return '1d ago';
  return '${days}d ago';
}

String _messageFor(Object error) {
  if (error is AdminAnalyticsUnavailableException) {
    if (error.statusCode == 404) {
      return 'Analytics is not available on the current server yet. '
          'Deploy the backend version that includes /admin/analytics, then retry.';
    }
    if (error.statusCode != null) {
      return 'Analytics could not be loaded right now. '
          'Server response: ${error.statusCode}.';
    }
    if (error.failureType == DioExceptionType.connectionTimeout ||
        error.failureType == DioExceptionType.receiveTimeout) {
      return 'The analytics server at ${error.uri.host} is not responding. '
          'Your internet connection is working, but the deployed backend needs to be restarted or redeployed.';
    }
    return 'The analytics server at ${error.uri.host} could not be reached. '
        'Check the deployed backend, then retry.';
  }
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return error.message ?? 'Request failed.';
  }
  return error.toString().replaceFirst('Exception: ', '');
}
