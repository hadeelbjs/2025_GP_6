import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/laws_data.dart';
import '../services/laws_service.dart';

class LawsScreen extends StatefulWidget {
  const LawsScreen({super.key});

  @override
  State<LawsScreen> createState() => _LawsScreenState();
}

class _LawsScreenState extends State<LawsScreen> {
  static const _primary = Color(0xFF2D1B69);
  static const _primaryLight = Color(0xFFEEEBF8);
  static const _fontFamily = 'IBMPlexSansArabic';

  static const _severityColors = <String, Color>{
    '٣': Color(0xFFB8A9E8),  
    '٤': Color(0xFF9C8FD4),  
    '٥': Color(0xFF6B5B95),  
    '٦': Color(0xFF4A3880),  
    '٧': Color(0xFF2D1B69), 
    '٨': Color(0xFF6B5B95),
    '٩': Color(0xFF6B5B95),
    '١٠': Color(0xFF6B5B95),
  };

  final TextEditingController _searchController = TextEditingController();
  final LawsService _service = LawsService();
  List<LawArticle> _filtered = saudiCybercrimeLaw.articles;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _filtered = _service.search(query, saudiCybercrimeLaw.articles);
    });
  }

  Future<void> _launchSource() async {
    final uri = Uri.parse(saudiCybercrimeLaw.sourceUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showArticleSheet(LawArticle article) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                    children: [
                      Text(
                        article.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _primary,
                          fontFamily: _fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'المادة ${article.articleNumber}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade500,
                          fontFamily: _fontFamily,
                        ),
                      ),
                      const SizedBox(height: 20),

                      _sectionLabel('ماذا تعني هذه الجريمة؟'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _primaryLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          article.simplifiedText,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.75,
                            color: _primary,
                            fontFamily: _fontFamily,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _sectionLabel('العقوبة'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3F3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.gavel_rounded,
                              color: Color(0xFFD32F2F),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                article.penalty,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFD32F2F),
                                  fontFamily: _fontFamily,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      _sectionLabel('مثال توضيحي'),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lightbulb_outline_rounded,
                              color: Color(0xFF6B5B95),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                article.example,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.6,
                                  color: Color(0xFF424242),
                                  fontFamily: _fontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      GestureDetector(
                        onTap: _launchSource,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.open_in_new_rounded,
                              size: 14,
                              color: Color(0xFF6B5B95),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              saudiCybercrimeLaw.sourceName,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B5B95),
                                decoration: TextDecoration.underline,
                                fontFamily: _fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: _primaryLight,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text(
                            'إغلاق',
                            style: TextStyle(
                              color: _primary,
                              fontWeight: FontWeight.w600,
                              fontFamily: _fontFamily,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: _primary,
        fontFamily: _fontFamily,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text(
            'قوانين الجرائم الإلكترونية',
            style: TextStyle(
              color: _primary,
              fontFamily: _fontFamily,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: Colors.white,
          foregroundColor: _primary,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: true,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearch,
                textDirection: TextDirection.rtl,
                style: const TextStyle(
                  fontFamily: _fontFamily,
                  fontSize: 14,
                  color: _primary,
                ),
                decoration: InputDecoration(
                  hintText: 'ابحث عن جريمة أو موضوع...',
                  hintStyle: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _primary,
                    size: 20,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: Colors.grey.shade400,
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F3FC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            // ── Law header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            saudiCybercrimeLaw.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontFamily: _fontFamily,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'المملكة العربية السعودية  •  ${saudiCybercrimeLaw.year}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.75),
                              fontFamily: _fontFamily,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Article list
            Expanded(
              child: _filtered.isEmpty
                  ? _buildNoResults()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildArticleCard(_filtered[i]),
                    ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: GestureDetector(
            onTap: _launchSource,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade100),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.open_in_new_rounded,
                    size: 14,
                    color: Color(0xFF6B5B95),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'المصدر: ${saudiCybercrimeLaw.sourceName}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B5B95),
                      decoration: TextDecoration.underline,
                      fontFamily: _fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildArticleCard(LawArticle article) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _showArticleSheet(article),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E4F3)),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    color: _severityColors[article.articleNumber] ?? _primary,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              article.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _primary,
                                fontFamily: _fontFamily,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 14,
                            color: Color(0xFF9E9E9E),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off_rounded, size: 70, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        const Text(
          'لم يتم العثور على نتائج',
          style: TextStyle(color: Colors.grey, fontFamily: _fontFamily),
        ),
      ],
    );
  }
}
