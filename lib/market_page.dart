import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

import 'mobile_web_view.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  static const endpoint =
      'https://pinchetulum.com/market/prediction-lab/data/public.json';

  Map<String, dynamic>? data;
  String? error;
  int section = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final response = await http
          .get(Uri.parse(endpoint))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final result = jsonDecode(response.body) as Map<String, dynamic>;

      if (!mounted) return;
      setState(() {
        data = result;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
    }
  }

  String? percentage(Object? value) {
    if (value is! num || !value.isFinite || value < 0 || value > 1) {
      return null;
    }
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  String? dateOnly(Object? value) => RegExp(
    r'^\d{4}-\d{2}-\d{2}',
  ).firstMatch(value?.toString() ?? '')?.group(0);

  Uri? httpsLink(Object? value) {
    if (value is! String) return null;
    final link = Uri.tryParse(value);
    return link != null &&
            link.scheme == 'https' &&
            link.host.isNotEmpty &&
            link.userInfo.isEmpty
        ? link
        : null;
  }

  void openLink(String title, Uri url) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => _MarketLinkPage(title: title, url: url),
      ),
    );
  }

  Widget predictionCard(Map<String, dynamic> item) {
    final outcomeA = item['outcome_a']?.toString() ?? 'Yes';
    final outcomeB = item['outcome_b']?.toString() ?? 'No';
    final marketA = item['market_probability'];
    final marketPercentA = percentage(marketA);
    final market = marketA is num && marketPercentA != null
        ? '$outcomeA $marketPercentA · $outcomeB ${percentage(1 - marketA)}'
        : 'Pending';

    final version = item['model_version']?.toString() ?? '';
    final choice = item['barakat_choice']?.toString();
    final hasCall =
        version.isNotEmpty &&
        !version.startsWith('baseline') &&
        choice != null &&
        (choice == outcomeA || choice == outcomeB);
    final probability = item['barakat_probability'];
    final barakatPercentA = percentage(probability);
    final barakatOdds = probability is num && barakatPercentA != null
        ? '$outcomeA $barakatPercentA · $outcomeB ${percentage(1 - probability)}'
        : null;
    final date = hasCall ? dateOnly(item['predicted_at']) : null;
    final barakat = hasCall
        ? [barakatOdds ?? choice, ?date].join(' · ')
        : 'Pending';

    final stamp = item['stamp'];
    final hash = stamp is Map ? stamp['hash'] : null;
    final stampLink = stamp is Map ? httpsLink(stamp['explorer_url']) : null;
    final explorer = stampLink?.host == 'agroland.theagrostore.com'
        ? stampLink
        : null;
    final verifiedStamp =
        hasCall &&
        stamp is Map &&
        stamp['status'] == 'verified' &&
        hash is String &&
        RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(hash) &&
        explorer != null;
    final explanation = item['explanation']?.toString().trim() ?? '';
    final evidence = item['evidence'];
    final notes = evidence is List ? evidence.whereType<Map>() : const <Map>[];

    return Card(
      child: ExpansionTile(
        title: Text(
          item['question']?.toString() ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Polymarket · $market'),
              Text('Barakat · $barakat'),
            ],
          ),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (hasCall) ...[
            const Text('Stamp', style: TextStyle(fontWeight: FontWeight.bold)),
            if (verifiedStamp)
              TextButton(
                onPressed: () => openLink('Stamp', explorer),
                child: Text(hash.toString(), softWrap: true),
              )
            else
              const Text('Verification pending'),
            if (explanation.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Why Barakat says $choice',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(explanation),
            ],
            for (final note in notes)
              if (httpsLink(note['url']) case final Uri link)
                if (link.host == 'pinchetulum.com' &&
                    link.path.startsWith('/articles/'))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      note['title']?.toString() ?? 'Pinche Tulum article',
                    ),
                    onTap: () => openLink(
                      note['title']?.toString() ?? 'Pinche Tulum article',
                      link,
                    ),
                  ),
          ] else
            const Text(
              'Barakat has not published a position on this question.',
            ),
          if (item['result'] != null) ...[
            const SizedBox(height: 12),
            Text('Result · ${item['result']}'),
            if (hasCall && item['correct'] is bool)
              Text(item['correct'] == true ? 'Correct' : 'Incorrect'),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = data?['active_predictions'] as List? ?? [];
    final resolved = data?['resolved_predictions'] as List? ?? [];
    final stats = data?['performance_by_model'] as Map? ?? {};
    final models = data?['machine_learning'] as List? ?? [];

    if (data == null && error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Pinche Market',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final entry in [
                'Active (${active.length})',
                'Results (${resolved.length})',
                'Performance',
                'Learning',
              ].asMap().entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: section == entry.key,
                  onSelected: (_) => setState(() => section = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (error != null) Text(error!),
          if (section == 0 || section == 1)
            for (final item in section == 0 ? active : resolved)
              predictionCard(Map<String, dynamic>.from(item)),
          if (section == 1 && resolved.isEmpty)
            const Text('No resolved predictions yet.'),
          if (section == 2)
            for (final entry in stats.entries)
              Card(
                child: ListTile(
                  title: Text(entry.key.toString()),
                  subtitle: Text(
                    'Resolved: ${entry.value['resolved']}\n'
                    'Correct: ${entry.value['correct']}\n'
                    'Incorrect: ${entry.value['incorrect']}\n'
                    'Accuracy: ${entry.value['accuracy_pct'] ?? 'Pending'}\n'
                    'Brier score: ${entry.value['brier_score'] ?? 'Pending'}',
                  ),
                ),
              ),
          if (section == 3) ...[
            if (models.isEmpty)
              const Text('Collecting resolved examples for neural training.'),
            for (final model in models)
              Card(
                child: ListTile(
                  title: Text(model['version'].toString()),
                  subtitle: Text(
                    "Training examples: ${model['training_examples']}\n"
                    "Trained: ${model['trained_at']}",
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MarketLinkPage extends StatefulWidget {
  const _MarketLinkPage({required this.title, required this.url});

  final String title;
  final Uri url;

  @override
  State<_MarketLinkPage> createState() => _MarketLinkPageState();
}

class _MarketLinkPageState extends State<_MarketLinkPage> {
  late final WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => fitMobileWebPage(controller),
          onNavigationRequest: (request) {
            final link = Uri.tryParse(request.url);
            return link?.scheme == 'https' && link?.host == widget.url.host
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(widget.url);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: WebViewWidget(controller: controller),
  );
}
