/**
 * Process-lifetime lazy loader for Cloud Functions entrypoints.
 *
 * Loads a module graph on first use and reuses the resolved value for the
 * rest of the instance — never request-scoped.
 */
export function lazySingleton<T>(load: () => Promise<T>): () => Promise<T> {
  let value: T | undefined;
  let pending: Promise<T> | undefined;

  return () => {
    if (value !== undefined) {
      return Promise.resolve(value);
    }
    pending ??= load()
      .then((resolved) => {
        value = resolved;
        return resolved;
      })
      .finally(() => {
        pending = undefined;
      });
    return pending;
  };
}
