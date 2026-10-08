import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/providers/dashboard_provider.dart';
import '../../../location/domain/entities/user_location.dart';
import '../../../serviceability/presentation/providers/serviceable_destination_provider.dart';
import '../../../restaurants/presentation/providers/restaurant_provider.dart';
import '../../data/datasources/search_firestore_datasource.dart';
import '../../data/repositories/search_repository_impl.dart';
import '../../domain/category_search_hits.dart';
import '../../domain/entities/search_result_entity.dart';
import '../../domain/repositories/search_repository.dart';
import '../../domain/usecases/search_usecase.dart';

/// Firebase
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Datasource
final searchDatasourceProvider = Provider<SearchFirestoreDatasource>((ref) {
  return SearchFirestoreDatasource(ref.read(firestoreProvider));
});

/// Repository
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepositoryImpl(ref.read(searchDatasourceProvider));
});

/// UseCase
final searchUseCaseProvider = Provider<SearchUseCase>((ref) {
  return SearchUseCase(
    ref.read(searchRepositoryProvider),
    ref.read(restaurantRepositoryProvider),
  );
});

/// Search Provider
final searchProvider =
    AsyncNotifierProvider<SearchNotifier, List<SearchResultEntity>>(
      SearchNotifier.new,
    );

class SearchNotifier extends AsyncNotifier<List<SearchResultEntity>> {
  Timer? _debounce;

  /// The query currently on screen (trimmed); empty when nothing is searched.
  String _activeQuery = '';

  /// The delivery destination the results on screen were computed for.
  UserLocation? _searchedDestination;
  bool _hasSearched = false;

  /// Drops the answer of a search that has been superseded (a newer query, a
  /// cleared box, or a destination change while it was in flight).
  int _generation = 0;

  @override
  Future<List<SearchResultEntity>> build() async {
    ref.onDispose(() {
      _debounce?.cancel();
    });

    // Results depend on WHERE the customer is ordering to. When the selected
    // destination changes, re-run the query on screen for the new one. The
    // phone's GPS is deliberately not watched: it never moves a selected
    // destination, so it cannot change search either.
    ref.listen<AsyncValue<UserLocation?>>(
      serviceableDeliveryDestinationProvider,
      (previous, next) {
        if (_activeQuery.isEmpty || next.isLoading || next.hasError) {
          return;
        }
        if (_debounce?.isActive ?? false) {
          // A pending search reads the fresh destination when it fires.
          return;
        }
        if (_hasSearched && next.value == _searchedDestination) {
          return;
        }
        _run(_activeQuery);
      },
    );

    return [];
  }

  Future<void> search(String query) async {
    _debounce?.cancel();

    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      _reset();
      return;
    }

    _activeQuery = trimmedQuery;
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _run(trimmedQuery),
    );
  }

  Future<void> _run(String query) async {
    final generation = ++_generation;
    state = const AsyncLoading();

    try {
      final destination = await ref.read(
        serviceableDeliveryDestinationProvider.future,
      );
      if (generation != _generation) {
        return;
      }
      _searchedDestination = destination;
      _hasSearched = true;

      final results = await ref
          .read(searchUseCaseProvider)
          .searchAll(query, destination: destination);
      final categories = await ref.read(getCategoriesUseCaseProvider)();
      final categoryHits = categorySearchHits(
        categories: categories,
        query: query,
      );

      if (generation != _generation) {
        return;
      }
      state = AsyncData([...categoryHits, ...results]);
    } catch (error, stackTrace) {
      if (generation != _generation) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  void clearSearch() {
    _debounce?.cancel();
    _reset();
  }

  Future<void> retry() async {
    if (_activeQuery.isEmpty) {
      return;
    }
    await _run(_activeQuery);
  }

  void _reset() {
    _generation++;
    _activeQuery = '';
    _hasSearched = false;
    _searchedDestination = null;
    state = const AsyncData([]);
  }
}
