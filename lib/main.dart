import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'market_page.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'mobile_web_view.dart';

const apiBase = 'https://sales.theagrostore.com';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();

    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidPlayIntegrityProvider(),
      providerApple: const AppleAppAttestProvider(),
    );
  } catch (error) {
    debugPrint('Firebase initialization: $error');
  }

  runApp(const PincheTulumApp());
}

class PincheTulumApp extends StatelessWidget {
  const PincheTulumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pinche Tulum',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2459D3),
          brightness: Brightness.dark,
        ),
        cardTheme: const CardThemeData(color: Color(0xFF0A0A0A)),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF101010),
          indicatorColor: const Color(0xFF2459D3),
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xFFE6EDF3),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF101010),
          selectedColor: const Color(0xFF2459D3),
          labelStyle: TextStyle(
            color: WidgetStateColor.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : const Color(0xFFE6EDF3),
            ),
          ),
        ),
        inputDecorationTheme: const InputDecorationThemeData(
          filled: true,
          fillColor: Color(0xFF101010),
          prefixIconColor: Color(0xFF58A6FF),
        ),
        useMaterial3: true,
      ),
      home: const DashboardPage(),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedIndex = 0;
  Article? openedArticle;

  static const destinations = [
    NavigationDestination(
      icon: Icon(Icons.newspaper_outlined),
      selectedIcon: Icon(Icons.newspaper),
      label: 'Latest',
    ),
    NavigationDestination(
      icon: Icon(Icons.play_circle_outline),
      selectedIcon: Icon(Icons.play_circle),
      label: 'Videos',
    ),
    NavigationDestination(
      icon: Icon(Icons.archive_outlined),
      selectedIcon: Icon(Icons.archive),
      label: 'Archive',
    ),
    NavigationDestination(
      icon: Icon(Icons.show_chart_outlined),
      selectedIcon: Icon(Icons.show_chart),
      label: 'Pinche Market',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        foregroundColor: Colors.white,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PINCHE TULUM',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2.5),
            ),
            Text(
              'Independent news, technology & culture.',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Colors.white,
                letterSpacing: .2,
              ),
            ),
          ],
        ),
      ),
      body: openedArticle != null
          ? ArticleWebViewPage(
              title: openedArticle!.title,
              url: openedArticle!.url,
              onClose: () {
                setState(() {
                  openedArticle = null;
                });
              },
            )
          : IndexedStack(
              index: selectedIndex,
              children: [
                NewsPage(
                  latestOnly: true,
                  title: 'Latest 100 Stories',
                  onOpenArticle: (article) {
                    setState(() {
                      openedArticle = article;
                    });
                  },
                ),
                const VideosPage(),
                NewsPage(
                  latestOnly: false,
                  title: 'News Archive',
                  onOpenArticle: (article) {
                    setState(() {
                      openedArticle = article;
                    });
                  },
                ),
                const MarketPage(),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        destinations: destinations,
        onDestinationSelected: (index) {
          setState(() {
            openedArticle = null;
            selectedIndex = index;
          });
        },
      ),
    );
  }
}

class Article {
  const Article({
    required this.rowId,
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.url,
    required this.source,
  });

  final int rowId;
  final String id;
  final String title;
  final String category;
  final String date;
  final String url;
  final String source;

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      rowId: (json['row_id'] as num?)?.toInt() ?? 0,
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
    );
  }
}

class NewsPage extends StatefulWidget {
  const NewsPage({
    super.key,
    required this.latestOnly,
    required this.title,
    required this.onOpenArticle,
  });

  final bool latestOnly;
  final String title;
  final ValueChanged<Article> onOpenArticle;

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  final ScrollController scrollController = ScrollController();

  final List<Article> articles = [];
  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  static const hybridSearch = MethodChannel('pinchetulum/hybrid_search');

  bool smartSearching = false;
  String? searchMode;

  Future<void> runSmartSearch() async {
    final original = searchController.text.trim();
    if (original.isEmpty || smartSearching) return;

    setState(() => smartSearching = true);

    String query = original;
    String mode = 'Archive search used';

    try {
      final response = await hybridSearch
          .invokeMethod<Object>('searchTerms', {'query': original})
          .timeout(const Duration(seconds: 20));

      final terms = response is Map ? response['terms'] : response;
      if (terms is String && terms.trim().isNotEmpty) {
        query = terms.trim();
        final source = response is Map ? response['source'] : null;
        mode = switch (source) {
          'ON_DEVICE' => 'Smart Search · On-device Gemini',
          'IN_CLOUD' => 'Smart Search · Cloud Gemini',
          _ => 'Smart Search · Inference route unavailable',
        };
      }
    } catch (_) {
      // Use the original archive query if AI is unavailable.
    }

    if (!mounted) return;
    setState(() {
      smartSearching = false;
      searchQuery = query;
      searchMode = mode;
    });

    await _load(reset: true);
  }

  int totalResults = 0;
  int requestGeneration = 0;

  bool initialLoading = true;
  bool loadingMore = false;
  bool hasMore = true;
  String? error;

  int offset = 0;

  int get pageSize => widget.latestOnly ? 100 : 50;

  @override
  void initState() {
    super.initState();

    if (!widget.latestOnly) {
      scrollController.addListener(_onScroll);
    }

    _load(reset: true);
  }

  void _onScroll() {
    if (!scrollController.hasClients ||
        loadingMore ||
        !hasMore ||
        initialLoading) {
      return;
    }

    final threshold = scrollController.position.maxScrollExtent - 700;

    if (scrollController.position.pixels >= threshold) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      setState(() {
        initialLoading = true;
        loadingMore = false;
        error = null;
        offset = 0;
        hasMore = true;
      });
    } else {
      if (loadingMore || !hasMore || widget.latestOnly) {
        return;
      }

      setState(() {
        loadingMore = true;
      });
    }

    try {
      final generation = ++requestGeneration;

      final uri = Uri.parse('$apiBase/api/news').replace(
        queryParameters: {
          'limit': '$pageSize',
          'offset': '$offset',
          if (searchQuery.isNotEmpty) 'q': searchQuery,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      if (!mounted || generation != requestGeneration) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      final raw = (data['articles'] as List<dynamic>?) ?? [];

      final incoming = raw
          .map((item) => Article.fromJson(item as Map<String, dynamic>))
          .toList();

      if (!mounted) return;

      setState(() {
        if (reset) {
          articles.clear();
        }

        articles.addAll(incoming);
        totalResults = (data['total'] as num?)?.toInt() ?? articles.length;

        offset = widget.latestOnly
            ? articles.length
            : (data['next_offset'] as num?)?.toInt() ?? articles.length;

        hasMore = widget.latestOnly ? false : data['has_more'] == true;

        initialLoading = false;
        loadingMore = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        initialLoading = false;
        loadingMore = false;
        error = e.toString();
      });
    }
  }

  Future<void> _openArticle(Article article) async {
    widget.onOpenArticle(article);
  }

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && articles.isEmpty) {
      return ErrorView(error: error!, onRetry: () => _load(reset: true));
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        itemCount: articles.length + 1 + (loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _NewsHeader(title: widget.title, latestOnly: widget.latestOnly),
                if (!widget.latestOnly) ...[
                  TextField(
                    controller: searchController,
                    textInputAction: TextInputAction.search,
                    readOnly: smartSearching,
                    onSubmitted: (value) {
                      if (smartSearching) return;
                      searchMode = null;
                      searchQuery = value.trim();
                      _load(reset: true);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search the news archive',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: smartSearching
                            ? null
                            : () {
                                searchMode = null;
                                searchQuery = searchController.text.trim();
                                _load(reset: true);
                              },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: smartSearching ? null : runSmartSearch,
                    icon: const Icon(Icons.auto_awesome),
                    label: Text(
                      smartSearching ? 'Searching...' : 'Smart Search',
                    ),
                  ),
                  if (searchMode case final String mode) Text(mode),
                  Text('$totalResults stories found'),
                  const SizedBox(height: 16),
                ],
              ],
            );
          }

          final articleIndex = index - 1;

          if (articleIndex >= articles.length) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final article = articles[articleIndex];

          return ArticleCard(
            article: article,
            onTap: () => _openArticle(article),
          );
        },
      ),
    );
  }
}

class _NewsHeader extends StatelessWidget {
  const _NewsHeader({required this.title, required this.latestOnly});

  final String title;
  final bool latestOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            latestOnly
                ? 'Browse the latest 100 stories from Pinche Tulum.'
                : 'Search and explore the Pinche Tulum news archive.',
            style: TextStyle(
              color: const Color(0xFFB6C0CC),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          if (latestOnly) ...[
            const SizedBox(height: 8),
            Text(
              'New coverage is continuously added to the archive.',
              style: TextStyle(color: const Color(0xFFB6C0CC), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class ArticleCard extends StatelessWidget {
  const ArticleCard({super.key, required this.article, required this.onTap});

  final Article article;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      article.category.toUpperCase(),
                      style: TextStyle(
                        color: const Color(0xFFB6C0CC),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  Text(
                    article.date,
                    style: TextStyle(
                      color: const Color(0xFFB6C0CC),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                article.title,
                style: const TextStyle(
                  fontSize: 19,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Text(
                    'Read Article',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 5),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArticleWebViewPage extends StatefulWidget {
  const ArticleWebViewPage({
    super.key,
    required this.title,
    required this.url,
    required this.onClose,
  });

  final String title;
  final String url;
  final VoidCallback onClose;

  @override
  State<ArticleWebViewPage> createState() => _ArticleWebViewPageState();
}

class _ArticleWebViewPageState extends State<ArticleWebViewPage> {
  late final WebViewController webController;

  int progress = 0;

  @override
  void initState() {
    super.initState();

    webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;

            setState(() {
              progress = value;
            });
          },
          onPageFinished: (_) => fitMobileWebPage(webController),
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame != true) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not load article: ${error.description}'),
              ),
            );
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _handleBack() async {
    if (await webController.canGoBack()) {
      await webController.goBack();
      return;
    }

    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack();
      },
      child: Column(
        children: [
          Container(
            height: 50,
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: _handleBack,
                  icon: const Icon(Icons.arrow_back),
                ),
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
          if (progress < 100)
            LinearProgressIndicator(value: progress / 100, minHeight: 2),
          Expanded(child: WebViewWidget(controller: webController)),
        ],
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 48),
      children: [
        const Text(
          'About PincheTulum',
          style: TextStyle(
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Independent news, technology, culture and original media powered by an autonomous editorial workflow.',
          style: TextStyle(
            color: const Color(0xFFB6C0CC),
            fontSize: 16,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),

        _AboutCard(
          icon: Icons.auto_awesome,
          title: 'Autonomous Newsroom',
          text:
              'PincheTulum uses OpenClaw to support continuous monitoring, curation, editorial production and distribution across a growing network of verified technical, economic and cultural sources.',
        ),
        const SizedBox(height: 12),

        _AboutCard(
          icon: Icons.public,
          title: 'Coverage',
          text:
              'AI, technology, blockchain, robotics, infrastructure, databases, machine learning, gaming, chess, digital economy, cinema, culture and emerging technologies.',
        ),
        const SizedBox(height: 12),

        _AboutCard(
          icon: Icons.movie_creation_outlined,
          title: 'Original Video',
          text:
              'PincheTulum produces original AI-assisted video publications including Cinema, Technology and future editorial editions. Each publication can be viewed, shared and distributed across the PincheTulum ecosystem.',
        ),
        const SizedBox(height: 12),

        _AboutCard(
          icon: Icons.hub_outlined,
          title: 'OpenClaw',
          text: 'Monitoring → Curation → Editorial Production → Distribution',
        ),
        const SizedBox(height: 12),

        _AboutCard(
          icon: Icons.business_outlined,
          title: 'The AgroStore',
          text:
              'PincheTulum is part of the technology and media ecosystem developed by The AgroStore LLC, Delaware, USA.',
        ),
        const SizedBox(height: 28),

        const Text(
          'Legal & Support',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => launchUrl(
            Uri.parse('https://pinchetulum.com/privacy/'),
            mode: LaunchMode.externalApplication,
          ),
        ),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => launchUrl(
            Uri.parse('https://pinchetulum.com/terms/'),
            mode: LaunchMode.externalApplication,
          ),
        ),

        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.email_outlined),
          title: const Text('Contact'),
          subtitle: const Text('no-reply@theagrostore.com'),
          trailing: const Icon(Icons.open_in_new, size: 18),
          onTap: () => launchUrl(
            Uri.parse('mailto:no-reply@theagrostore.com'),
            mode: LaunchMode.externalApplication,
          ),
        ),

        const SizedBox(height: 28),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF292929)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PINCHE TULUM',
                style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2),
              ),
              const SizedBox(height: 8),
              Text(
                'Autonomous Agentic Media',
                style: TextStyle(color: const Color(0xFFB6C0CC), fontSize: 16),
              ),
              const SizedBox(height: 14),
              Text(
                'From verified sources to governed, traceable and distributable AI media.',
                style: TextStyle(color: const Color(0xFFB6C0CC), height: 1.5),
              ),
              const SizedBox(height: 18),
              Text(
                '© 2026 PincheTulum / The AgroStore LLC. All rights reserved.',
                style: TextStyle(color: const Color(0xFFB6C0CC), fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF292929)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(color: const Color(0xFFB6C0CC), height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class Publication {
  const Publication({
    required this.id,
    this.date = '',
    required this.category,
    required this.presenter,
    required this.headline,
    required this.sha256,
    required this.videoUrl,
    required this.downloadUrl,
    required this.bitcoinAddress,
  });

  final String id;
  final String date;
  final String category;
  final String presenter;
  final String headline;
  final String sha256;
  final String videoUrl;
  final String downloadUrl;
  final String bitcoinAddress;

  factory Publication.fromJson(Map<String, dynamic> json) {
    final video = (json['video'] as Map<String, dynamic>?) ?? {};

    final bitcoin = (json['bitcoin'] as Map<String, dynamic>?) ?? {};

    String absoluteUrl(dynamic value) {
      final path = value?.toString() ?? '';

      if (path.startsWith('http://') || path.startsWith('https://')) {
        return path;
      }

      return '$apiBase$path';
    }

    return Publication(
      id: json['publication_id']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      presenter: json['presenter']?.toString() ?? '',
      headline: json['headline']?.toString() ?? '',
      sha256: json['sha256']?.toString() ?? '',
      videoUrl: absoluteUrl(video['path']),
      downloadUrl: absoluteUrl(video['download']),
      bitcoinAddress: bitcoin['address']?.toString() ?? '',
    );
  }
}

class GrowthVideo {
  const GrowthVideo({
    required this.id,
    required this.period,
    required this.title,
    required this.videoUrl,
  });

  final String id;
  final String period;
  final String title;
  final String videoUrl;

  factory GrowthVideo.fromJson(Map<String, dynamic> json) {
    return GrowthVideo(
      id: json['id']?.toString() ?? '',
      period: json['period']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Video',
      videoUrl: json['video_url']?.toString() ?? '',
    );
  }
}

class GrowthCollection {
  const GrowthCollection({
    required this.id,
    required this.section,
    required this.name,
    required this.videos,
  });

  final String id;
  final String section;
  final String name;
  final List<GrowthVideo> videos;

  factory GrowthCollection.fromJson(Map<String, dynamic> json) {
    final raw = (json['videos'] as List<dynamic>?) ?? [];

    return GrowthCollection(
      id: json['id']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      videos: raw
          .map((item) => GrowthVideo.fromJson(item as Map<String, dynamic>))
          .where((item) => item.videoUrl.isNotEmpty)
          .toList(),
    );
  }
}

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  final List<Publication> publications = [];
  final videoScroll = ScrollController();
  final playerKey = GlobalKey();
  int videoLimit = 8;
  String videoQuery = '';
  String videoSection = 'All';

  List<Publication> get filteredPublications => publications.where((item) {
    final matchesSection =
        videoSection == 'All' || item.category == videoSection;
    final text = '${item.headline} ${item.category} ${item.id}'.toLowerCase();
    return matchesSection && text.contains(videoQuery.toLowerCase());
  }).toList();
  final List<GrowthCollection> growthCollections = [];

  Publication? selected;
  GrowthVideo? selectedGrowth;
  String? selectedGrowthCollection;

  VideoPlayerController? controller;

  bool loading = true;
  bool selectingVideo = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    const catalogs = {
      'technology': 'Technology',
      'cinema': 'Cinema',
      'chess': 'Chess',
      'agroceans': 'AgroCeans',
    };

    final items = <Publication>[];
    final failures = <String>[];

    for (final section in catalogs.entries) {
      try {
        final response = await http
            .get(
              Uri.parse('https://pinchetulum.com/videos/${section.key}.json'),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final entries =
            (data['videos'] ?? data['items'] ?? data['articles']) as List;

        for (final raw in entries) {
          final item = raw as Map<String, dynamic>;
          final media = item['media'] as Map<String, dynamic>? ?? {};
          final url = (media['url'] ?? item['media_url'] ?? item['url'] ?? '')
              .toString();

          if (url.isEmpty) continue;

          final id = (item['publicationId'] ?? item['id'] ?? url).toString();

          final date =
              (item['date'] ??
                      item['published_at'] ??
                      item['publishedAt'] ??
                      RegExp(r'\d{4}-\d{2}-\d{2}').firstMatch(id)?.group(0) ??
                      '')
                  .toString();

          final rawTitle = item['title'];
          final title = rawTitle is Map
              ? (rawTitle['en'] ?? rawTitle['es'] ?? '').toString()
              : (rawTitle ?? item['text'] ?? '').toString();

          items.add(
            Publication(
              id: id,
              date: date,
              category: section.value,
              presenter: 'Alejandro Barakat',
              headline: title.trim().isEmpty
                  ? '${section.value} — $date'
                  : title.split('\n').first,
              sha256: (media['sha256'] ?? item['sha256'] ?? '').toString(),
              videoUrl: url,
              downloadUrl: url,
              bitcoinAddress: '',
            ),
          );
        }
      } catch (_) {
        failures.add(section.value);
      }
    }

    final seen = <String>{};
    final unique = items
        .where((item) => seen.add('${item.category}:${item.videoUrl}'))
        .toList();

    unique.sort((a, b) {
      final dateOrder = b.date.compareTo(a.date);
      return dateOrder != 0 ? dateOrder : a.id.compareTo(b.id);
    });

    if (!mounted) return;

    setState(() {
      publications
        ..clear()
        ..addAll(unique);
      growthCollections.clear();
      loading = false;
      error = unique.isEmpty
          ? 'Video catalogs unavailable: ${failures.join(", ")}'
          : null;
    });
  }

  Future<void> _selectOriginal(Publication item) async {
    await _loadPlayer(
      url: item.videoUrl,
      onReady: () {
        selected = item;
        selectedGrowth = null;
        selectedGrowthCollection = null;
      },
    );
  }

  Future<void> _selectGrowth(GrowthVideo item, String collectionName) async {
    await _loadPlayer(
      url: item.videoUrl,
      onReady: () {
        selectedGrowth = item;
        selectedGrowthCollection = collectionName;
      },
    );
  }

  Future<void> _loadPlayer({
    required String url,
    required VoidCallback onReady,
  }) async {
    if (selectingVideo) return;

    setState(() {
      selectingVideo = true;
    });

    final previous = controller;
    final next = VideoPlayerController.networkUrl(Uri.parse(url));

    try {
      await next.initialize();
      await next.setLooping(true);

      if (!mounted) {
        await next.dispose();
        return;
      }

      setState(() {
        onReady();
        controller = next;
        loading = false;
        selectingVideo = false;
        error = null;
      });

      await previous?.dispose();
    } catch (e) {
      await next.dispose();

      if (!mounted) return;

      setState(() {
        selectingVideo = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not load video: $e')));
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);

    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

  Future<void> _copy(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    videoScroll.dispose();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return ErrorView(
        error: error!,
        onRetry: () {
          setState(() {
            loading = true;
            error = null;
          });

          _load();
        },
      );
    }

    final video = controller;
    final visibleVideos = filteredPublications;
    final shownVideos = visibleVideos.take(videoLimit).toList();
    final sections = [
      'All',
      ...publications.map((p) => p.category).toSet().toList()..sort(),
    ];

    final campaignCollections = growthCollections
        .where((item) => item.section == 'campaign')
        .toList();

    final businessCollections = growthCollections
        .where((item) => item.section == 'business')
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: videoScroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          const Text(
            'Pinche Tulum Originals',
            style: TextStyle(
              fontSize: 28,
              height: 1.05,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Original reporting and video editions from Pinche Tulum.',
            style: TextStyle(color: const Color(0xFFB6C0CC), height: 1.4),
          ),
          const SizedBox(height: 20),

          TextField(
            onChanged: (value) => setState(() {
              videoQuery = value.trim();
              videoLimit = 8;
            }),
            decoration: const InputDecoration(
              hintText: 'Search videos',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: sections
                .map(
                  (section) => ChoiceChip(
                    label: Text(section),
                    selected: videoSection == section,
                    onSelected: (_) => setState(() {
                      videoSection = section;
                      videoLimit = 8;
                    }),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          Text('${visibleVideos.length} videos'),
          const SizedBox(height: 16),

          if (visibleVideos.isEmpty)
            Text(
              'No original videos available.',
              style: TextStyle(color: const Color(0xFFB6C0CC)),
            ),

          if (selectedGrowth == null && selected != null && video != null) ...[
            Text(
              selected!.category.toUpperCase(),
              style: TextStyle(
                color: const Color(0xFFB6C0CC),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              selected!.headline,
              style: const TextStyle(
                fontSize: 24,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (selected!.presenter.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                selected!.presenter,
                style: TextStyle(color: const Color(0xFFB6C0CC)),
              ),
            ],
            const SizedBox(height: 18),
            KeyedSubtree(key: playerKey, child: _videoPlayer(video)),
            const SizedBox(height: 14),
            _controls(selected!, video),
            const SizedBox(height: 24),
            _metadata(selected!),
          ],

          if (selectingVideo) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],

          for (var i = 0; i < shownVideos.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: videoCard(shownVideos[i])),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < shownVideos.length
                        ? videoCard(shownVideos[i + 1])
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          if (visibleVideos.length > shownVideos.length)
            OutlinedButton(
              onPressed: () => setState(() => videoLimit += 8),
              child: const Text('Show more videos'),
            ),

          if (selectedGrowth != null &&
              selectedGrowthCollection != null &&
              video != null)
            _growthPlayer(selectedGrowth!, selectedGrowthCollection!, video),

          if (campaignCollections.isNotEmpty) ...[
            const SizedBox(height: 34),
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              'Featured Campaign',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Growth AI campaign content produced for PincheTulum.',
              style: TextStyle(color: const Color(0xFFB6C0CC), height: 1.4),
            ),
            const SizedBox(height: 14),
            ...campaignCollections.map(_collectionTile),
          ],

          if (businessCollections.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Divider(),
            const SizedBox(height: 20),
            const Text(
              'Business Stories',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Featured business and Growth AI productions.',
              style: TextStyle(color: const Color(0xFFB6C0CC), height: 1.4),
            ),
            const SizedBox(height: 14),
            ...businessCollections.map(_collectionTile),
          ],
        ],
      ),
    );
  }

  Widget videoCard(Publication item) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: selectingVideo
            ? null
            : () async {
                await _selectOriginal(item);
                if (!mounted) return;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  final playerContext = playerKey.currentContext;
                  if (playerContext != null) {
                    Scrollable.ensureVisible(
                      playerContext,
                      duration: const Duration(milliseconds: 250),
                    );
                  }
                });
              },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _VideoThumbnail(key: ValueKey(item.videoUrl), url: item.videoUrl),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      item.category,
                      if (item.date.isNotEmpty) item.date,
                    ].join(' · '),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _collectionTile(GrowthCollection collection) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        title: Text(
          collection.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text('${collection.videos.length} videos'),
        children: collection.videos.map((item) {
          final active = selectedGrowth?.id == item.id;

          return Column(
            children: [
              ListTile(
                selected: active,
                leading: Icon(
                  active ? Icons.play_circle_fill : Icons.play_circle_outline,
                ),
                title: Text(item.title),
                subtitle: Text(item.period),
                trailing: Icon(
                  active ? Icons.keyboard_arrow_up : Icons.chevron_right,
                ),
                onTap: selectingVideo
                    ? null
                    : () => _selectGrowth(item, collection.name),
              ),
              if (active &&
                  controller != null &&
                  selectedGrowthCollection == collection.name)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: _growthPlayer(item, collection.name, controller!),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _videoPlayer(VideoPlayerController video) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: video.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(video),
              AnimatedBuilder(
                animation: video,
                builder: (context, _) {
                  if (video.value.isPlaying) {
                    return const SizedBox.shrink();
                  }

                  return Container(
                    decoration: const BoxDecoration(
                      color: Color(0x44000000),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      iconSize: 58,
                      onPressed: () {
                        video.play();
                        setState(() {});
                      },
                      icon: const Icon(Icons.play_arrow),
                    ),
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  video,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(Publication item, VideoPlayerController video) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () {
            setState(() {
              if (video.value.isPlaying) {
                video.pause();
              } else {
                video.play();
              }
            });
          },
          icon: Icon(video.value.isPlaying ? Icons.pause : Icons.play_arrow),
          label: Text(video.value.isPlaying ? 'Pause' : 'Play'),
        ),
        OutlinedButton.icon(
          onPressed: () => _open(item.downloadUrl),
          icon: const Icon(Icons.download),
          label: const Text('Download'),
        ),
        OutlinedButton.icon(
          onPressed: () => _copy(item.videoUrl, 'Video link copied'),
          icon: const Icon(Icons.share),
          label: const Text('Share'),
        ),
        if (item.bitcoinAddress.isNotEmpty)
          OutlinedButton.icon(
            onPressed: () =>
                _copy(item.bitcoinAddress, 'Bitcoin address copied'),
            icon: const Icon(Icons.currency_bitcoin),
            label: const Text('Bitcoin'),
          ),
      ],
    );
  }

  Widget _growthPlayer(
    GrowthVideo item,
    String collectionName,
    VideoPlayerController video,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 18, bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF292929)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            collectionName.toUpperCase(),
            style: TextStyle(
              color: const Color(0xFFB6C0CC),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          _videoPlayer(video),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    if (video.value.isPlaying) {
                      video.pause();
                    } else {
                      video.play();
                    }
                  });
                },
                icon: Icon(
                  video.value.isPlaying ? Icons.pause : Icons.play_arrow,
                ),
                label: Text(video.value.isPlaying ? 'Pause' : 'Play'),
              ),
              OutlinedButton.icon(
                onPressed: () => _open(item.videoUrl),
                icon: const Icon(Icons.download),
                label: const Text('Download'),
              ),
              OutlinedButton.icon(
                onPressed: () => _copy(item.videoUrl, 'Video link copied'),
                icon: const Icon(Icons.share),
                label: const Text('Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metadata(Publication item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF292929)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PUBLICATION',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(item.id),
          if (item.sha256.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'SHA256',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              item.sha256,
              style: TextStyle(color: const Color(0xFFB6C0CC), fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoThumbnail extends StatefulWidget {
  const _VideoThumbnail({super.key, required this.url});

  final String url;

  @override
  State<_VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<_VideoThumbnail> {
  late final preview = VideoThumbnail.thumbnailData(
    video: widget.url,
    imageFormat: ImageFormat.JPEG,
    maxWidth: 360,
    quality: 75,
  );

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ColoredBox(
        color: const Color(0xFFE6EDF3),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder(
              future: preview,
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                return bytes == null
                    ? const SizedBox.shrink()
                    : Image.memory(bytes, fit: BoxFit.cover);
              },
            ),
            const Center(
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                child: Icon(Icons.play_arrow),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Could not load PincheTulum',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: const Color(0xFFB6C0CC)),
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class PincheLivePage extends StatefulWidget {
  const PincheLivePage({super.key});

  @override
  State<PincheLivePage> createState() => _PincheLivePageState();
}

class _PincheLivePageState extends State<PincheLivePage> {
  static final liveUrl = Uri.parse(
    'https://twitch.theagrostore.com/pinche-live',
  );

  late final WebViewController controller;
  bool loadFailed = false;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (mounted && error.isForMainFrame == true) {
              setState(() => loadFailed = true);
            }
          },
        ),
      )
      ..loadRequest(liveUrl);
  }

  void retry() {
    setState(() => loadFailed = false);
    controller.loadRequest(liveUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pinche Live')),
      body: SafeArea(
        child: loadFailed
            ? Center(
                child: FilledButton(
                  onPressed: retry,
                  child: const Text('Reintentar directo'),
                ),
              )
            : WebViewWidget(controller: controller),
      ),
    );
  }
}
