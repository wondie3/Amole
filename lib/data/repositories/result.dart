/// Outcome of a repository call that may not be available yet.
sealed class Result<T> {
  const Result();
}

class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

/// The feature needs a backend or provider that is not connected.
class NotAvailable<T> extends Result<T> {
  const NotAvailable(this.message);

  final String message;
}
