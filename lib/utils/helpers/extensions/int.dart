extension IntExtensionHelper on int {
  void forEach(void Function(int index) f) {
    for (var i = 0; i < this; i++) {
      f(i);
    }
  }

  List<T> map<T>(T Function(int index) f) {
    final List<T> values = [];
    for (var i = 0; i < this; i++) {
      values.add(f(i));
    }
    return values;
  }
}
