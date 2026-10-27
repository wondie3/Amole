import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/catalog_providers.dart';
import 'search_logic.dart';

class SearchState {
  const SearchState({
    this.text = '',
    this.categoryId = 'all',
    this.mode = SearchMode.dishes,
    this.sort = SortOption.recommended,
  });

  final String text;
  final String categoryId;
  final SearchMode mode;
  final SortOption sort;

  bool get isFiltered => text.trim().isNotEmpty || categoryId != 'all';

  SearchState copyWith({
    String? text,
    String? categoryId,
    SearchMode? mode,
    SortOption? sort,
  }) {
    return SearchState(
      text: text ?? this.text,
      categoryId: categoryId ?? this.categoryId,
      mode: mode ?? this.mode,
      sort: sort ?? this.sort,
    );
  }
}

class SearchNotifier extends Notifier<SearchState> {
  @override
  SearchState build() => const SearchState();

  void setText(String value) => state = state.copyWith(text: value);

  void setCategory(String id) => state = state.copyWith(categoryId: id);

  /// Switching mode resets sorting, because the valid options differ.
  void setMode(SearchMode mode) =>
      state = state.copyWith(mode: mode, sort: SortOption.recommended);

  void setSort(SortOption sort) => state = state.copyWith(sort: sort);

  void reset() => state = const SearchState();
}

final searchStateProvider = NotifierProvider<SearchNotifier, SearchState>(
  SearchNotifier.new,
);

final searchResultsProvider = Provider<AsyncValue<SearchResults>>((ref) {
  final catalog = ref.watch(homeDataProvider);
  final s = ref.watch(searchStateProvider);
  return catalog.whenData(
    (d) => runSearch(
      dishes: d.dishes,
      restaurants: d.restaurants,
      text: s.text,
      categoryId: s.categoryId,
      sort: s.sort,
    ),
  );
});
