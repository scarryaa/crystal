class LRUCache<K, V> {
  final int maxSize;
  final Map<K, V> _cache = <K, V>{};

  LRUCache(this.maxSize);

  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    final value = _cache.remove(key) as V;
    _cache[key] = value; // Move to end
    return value;
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) _cache.remove(key);
    _cache[key] = value;
    if (_cache.length > maxSize) {
      _cache.remove(_cache.keys.first);
    }
  }
}
