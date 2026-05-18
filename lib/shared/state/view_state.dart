sealed class ViewState<T> {
  const ViewState();
}

class LoadingState<T> extends ViewState<T> {
  const LoadingState();
}

class EmptyState<T> extends ViewState<T> {
  const EmptyState(this.message);

  final String message;
}

class DataState<T> extends ViewState<T> {
  const DataState(this.value);

  final T value;
}

class ErrorState<T> extends ViewState<T> {
  const ErrorState(this.message);

  final String message;
}
