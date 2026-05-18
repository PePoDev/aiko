abstract interface class Repository<T> {
  Future<List<T>> list();
}

abstract interface class ArchiveRepository<T> implements Repository<T> {
  Future<T> save(T value);

  Future<void> archive(String id);
}
