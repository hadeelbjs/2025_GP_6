import '../data/laws_data.dart';

class LawsService {
  List<LawArticle> search(String query, List<LawArticle> articles) {
    if (query.trim().isEmpty) return articles;
    final q = query.trim().toLowerCase();
    return articles.where((a) {
      return a.title.contains(q) ||
          a.simplifiedText.contains(q) ||
          a.keywords.any((k) => k.contains(q));
    }).toList();
  }
}
