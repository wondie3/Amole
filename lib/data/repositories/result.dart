/// Outcome of a repository call.
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

/// The call reached a backend and failed. [message] is safe to show.
class Failure<T> extends Result<T> {
  const Failure(this.message);

  final String message;
}
