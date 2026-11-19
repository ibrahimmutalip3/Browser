/// A configurable search engine option. The address bar builds queries via
/// [queryTemplate], where "%s" is replaced with the URL-encoded search
/// terms — see UrlUtils.buildSearchUrl.
///
/// Search engine choice is never hardcoded elsewhere in the app; every
/// place that needs to run a search reads the user's selection from
/// PreferencesService.searchEngineId and looks it up here.
class SearchEngine {
  const SearchEngine({
    required this.id,
    required this.name,
    required this.queryTemplate,
    required this.homeUrl,
  });

  final String id;
  final String name;
  final String queryTemplate;
  final String homeUrl;

  static const SearchEngine google = SearchEngine(
    id: 'google',
    name: 'Google',
    queryTemplate: 'https://www.google.com/search?q=%s',
    homeUrl: 'https://www.google.com',
  );

  static const SearchEngine bing = SearchEngine(
    id: 'bing',
    name: 'Bing',
    queryTemplate: 'https://www.bing.com/search?q=%s',
    homeUrl: 'https://www.bing.com',
  );

  static const SearchEngine duckDuckGo = SearchEngine(
    id: 'duckduckgo',
    name: 'DuckDuckGo',
    queryTemplate: 'https://duckduckgo.com/?q=%s',
    homeUrl: 'https://duckduckgo.com',
  );

  static const List<SearchEngine> all = <SearchEngine>[google, bing, duckDuckGo];

  static SearchEngine byId(String id) {
    return all.firstWhere((SearchEngine e) => e.id == id, orElse: () => google);
  }
}
