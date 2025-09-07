
import 'package:flamingo/utils/helpers/extensions/extensions.dart';

import '../type_defs.dart';

extension ListListMerging<T> on List<List<T>> {
  ///Do that:
  ///```dart
  /// //Input
  /// final List<List<T>> input = [
  ///   [elementT, elementT],
  ///   [elementT, elementT, elementT, elementT],
  ///   [elementT, elementT, elementT],
  /// ];
  ///
  /// final List<T> output = input.merge()
  ///
  /// //Printing result
  /// print(output);
  ///
  /// [
  ///   elementT,
  ///   elementT,
  ///   elementT,
  ///   elementT,
  ///   elementT,
  ///   elementT,
  ///   elementT,
  ///   elementT,
  ///   elementT,
  /// ]
  ///```
  List<T> merge() {
    return fold<List<T>>(
      [],
      (prev, element) => prev..addAll(element),
    );
  }

  ///Do that:
  ///```dart
  /// //Input
  /// final List<Widget> children = [
  ///   [SideBarMenuItem(), SideBarMenuItem, SideBarMenuItem()]
  ///   [SideBarMenuItem(), SideBarMenuItem()]
  /// ].fuse<Widget>(
  ///     (item) => SideBarMenuTile(item),
  ///     sepatarorBetweenItems: const Spacer(),
  ///     separatorBetweenLists: const BigSpacer()
  ///   );
  ///
  ///
  /// //Printing result
  /// print(children);
  ///
  /// [
  ///   SideBarMenuItem(),
  ///   const Spacer(),
  ///   SideBarMenuItem(),
  ///   const Spacer(),
  ///   SideBarMenuItem(),
  ///   const BigSpacer(),
  ///   SideBarMenuItem(),
  ///   const Spacer(),
  ///   SideBarMenuItem(),
  /// ]
  ///```
  List<E> fuse<E>(
    E Function(T e) element, {
    E? sepatarorBetweenItems,
    E? separatorBetweenLists,
  }) {
    final List<E> items = [];
    for (int i = 0; i < length; i++) {
      items.addAll([
        //...this[i].conditionalMapIndexed((index, e) => element(e), sepatarorBetweenItems),
        if (i != length - 1 && separatorBetweenLists != null)
          separatorBetweenLists
      ]);
    }
    return items;
  }
}

extension IterableMerging<T> on Iterable<T> {
  T? getFirst(ReplaceValidator<T> test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }

  Map<K, V> toMap<K, V>(MapEntry<K, V> Function(int index, T e) test) {
    final Map<K, V> map = {};
    for (var i = 0; i < length; i++) {
      final item = elementAt(i);
      final entry = test(i, item);
      map[entry.key] = entry.value;
    }
    return map;
  }

  bool containsWhere(ReplaceValidator<T> validator) {
    for (final item in this) {
      if (validator(item)) return true;
    }
    return false;
  }
}

extension ListNullableMerging<T> on List<T?> {
  //List<T> removeNulls() => conditionalMap((e) => e);
}

extension ListMerging<T> on List<T> {
  bool replaceWhere(ReplaceValidator<T> validator, ReplaceValue<T> newValue) {
    bool foundOne = false;
    for (int i = 0; i < length; i++) {
      final item = elementAt(i);
      if (validator(item)) {
        foundOne = true;
        this[i] = newValue(item);
      }
    }
    return foundOne;
  }

  T replaceAt(int index, T value) {
    final T last = removeAt(index);
    insert(index, value);
    return last;
  }

  List<T> textSearch(String query, Iterable<String> Function(T e) test) {
    final List<T> items = [];
    final String queryNormalized = query.toNormalize();
    for (final T item in this) {
      for (final String text in test(item)) {
        if (text.toNormalize().contains(queryNormalized)) {
          items.add(item);
          break;
        }
      }
    }
    return items;
  }

  List<T> repeat(int times) {
    final List<T> items = [];
    for (int i = 0; i < times; i++) {
      items.addAll(this);
    }
    return items;
  }

  ///Do that:
  ///```dart
  /// if (!contains(element)) add(element);
  ///```
  void addIfNotContains(T element) {
    if (!contains(element)) add(element);
  }

  void addIfNotContainsWhere(ReplaceValidator<T> validator, T element) {
    //if (!containsWhere(validator)) add(element);
  }

  void addAllIfNotContains(List<T> items) {
    for (final item in items) {
      addIfNotContains(item);
    }
  }

  void insertAll(int index, List<T> items) {
    for (final item in items) {
      insert(index, item);
    }
  }

  double foldTotal(
    double? Function(T e) builder, {
    double initial = 0,
  }) {
    return fold<double>(initial, (prev, e) {
      final double? value = builder(e);
      if (value != null) return prev + value;
      return prev;
    });
  }

  void addAllIfNotContainsWhere(
    bool Function(T e, T item) validator,
    List<T> items,
  ) {
    for (final item in items) {
      addIfNotContainsWhere((e) => validator(e, item), item);
    }
  }

  ///Do that:
  ///```dart
  /// //Input
  /// final List<Widget> children = [
  ///   ProductModel(),
  ///   ProductModel(),
  ///   ProductModel(),
  ///   ProductModel(),
  /// ].fuse<Widget>((index, product) {
  ///   return ProductTile(product);
  /// }, const Spacer());
  ///
  ///
  /// //Printing result
  /// print(children);
  ///
  /// [
  ///   ProductTile(),
  ///   const Spacer(),
  ///   ProductTile(),
  ///   const Spacer(),
  ///   ProductTile(),
  ///   const Spacer(),
  ///   ProductTile(),
  /// ]
  ///```
  List<E> fuse<E>(E Function(int index, T e) element, [E? separator]) {
    final List<E> items = [];
    for (int i = 0; i < length; i++) {
      items.addAll([
        element(i, this[i]),
        if (i != length - 1 && separator != null) separator
      ]);
    }
    return items;
  }

  int? removeFirstWhere(ReplaceValidator<T> f) {
    for (var i = 0; i < length; i++) {
      if (f(this[i])) {
        removeAt(i);
        return i;
      }
    }
    return null;
  }

  void removeAll(List<Object?> values) {
    for (final item in values) {
      remove(item);
    }
  }

  List<E> removeMapDuplicates<E>(E Function(T e) f) {
    return map(f).toSet().toList();
  }

  List<T> removeDuplicates() {
    return toSet().toList();
  }

  List<T> removeDuplicatesWhere<E>(E Function(T e) test) {
    //return toMap<E, T>((index, e) => MapEntry(test(e), e)).values.toList();
    return [];
  }

  List<E> mapIndexed<E>(E Function(int index, T e) f) {
    return conditionalMapIndexed(f);
  }

  /// Reduces a collection to a single value by iteratively combining each
  /// element of the collection with an existing value
  ///
  /// Uses [initialValue] as the initial value,
  /// then iterates through the elements and updates the value with
  /// each element using the [combine] function, as if by:
  /// ```
  /// var value = initialValue;
  /// for (E element in this) {
  ///   value = combine(value, element);
  /// }
  /// return value;
  /// ```
  /// Example of calculating the sum of an iterable:
  /// ```dart
  /// final numbers = <double>[10, 2, 5, 0.5];
  /// const initialValue = 100.0;
  /// final result = numbers.fold<double>(
  ///     initialValue, (previousValue, element) => previousValue + element);
  /// print(result); // 117.5
  /// ```
  E foldIndexed<E>(
    E initialValue,
    E Function(int index, E previousValue, T element) combine,
  ) {
    var value = initialValue;
    for (var i = 0; i < length; i++) {
      value = combine(i, value, this[i]);
    }
    return value;
  }

  List<E> conditionalMap<E>(E? Function(T e) f) {
    return conditionalMapIndexed((_, e) => f(e));
  }

  List<E> conditionalMapIndexed<E>(E? Function(int index, T e) f) {
    final List<E> items = [];
    for (int i = 0; i < length; i++) {
      final value = f(i, this[i]);
      if (value != null) items.add(value);
    }
    return items;
  }

  ///Do that:
  ///```dart
  /// //Input
  /// final output = [
  ///   ProductTile(),
  ///   ProductTile(),
  ///   ProductTile(),
  ///   ProductTile(),
  /// ].separete(const Spacer());
  ///
  ///
  /// //Printing result
  /// print(output);
  ///
  /// [
  ///   ProductTile(),
  ///   const Spacer(),
  ///   ProductTile(),
  ///   const Spacer(),
  ///   ProductTile(),
  ///   const Spacer(),
  ///   ProductTile(),
  /// ]
  ///```
  List<T> separete(T separator) {
    final List<T> items = [];
    for (int i = 0; i < length; i++) {
      items.addAll([this[i], if (i != length - 1) separator]);
    }
    return items;
  }
}
