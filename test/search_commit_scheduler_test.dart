import 'package:blindbox_app/core/search/search_commit_policy.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SearchCommitScheduler', () {
    test('does not commit before delay; only latest rapid query commits', () {
      fakeAsync((async) {
        final commits = <String>[];
        final scheduler = SearchCommitScheduler(
          delay: SearchCommitPolicy.localCatalog,
          onCommit: commits.add,
        );

        scheduler.schedule('h');
        scheduler.schedule('he');
        scheduler.schedule('hel');
        async.elapse(const Duration(milliseconds: 249));
        expect(commits, isEmpty);

        async.elapse(const Duration(milliseconds: 1));
        expect(commits, ['hel']);

        scheduler.dispose();
      });
    });

    test('empty query commits immediately', () {
      fakeAsync((async) {
        final commits = <String>[];
        final scheduler = SearchCommitScheduler(
          delay: SearchCommitPolicy.localCatalog,
          onCommit: commits.add,
        );

        scheduler.schedule('hello');
        async.elapse(SearchCommitPolicy.localCatalog);
        expect(commits, ['hello']);

        scheduler.schedule('');
        expect(commits, ['hello', '']);
        async.elapse(SearchCommitPolicy.localCatalog);
        expect(commits, ['hello', '']);

        scheduler.dispose();
      });
    });

    test('commitNow bypasses delay', () {
      fakeAsync((async) {
        final commits = <String>[];
        final scheduler = SearchCommitScheduler(
          delay: SearchCommitPolicy.remote,
          onCommit: commits.add,
        );

        scheduler.schedule('pending');
        scheduler.commitNow('now');
        expect(commits, ['now']);
        async.elapse(SearchCommitPolicy.remote);
        expect(commits, ['now']);

        scheduler.dispose();
      });
    });

    test('dispose cancels pending commit', () {
      fakeAsync((async) {
        final commits = <String>[];
        final scheduler = SearchCommitScheduler(
          delay: SearchCommitPolicy.localCatalog,
          onCommit: commits.add,
        );

        scheduler.schedule('ghost');
        scheduler.dispose();
        async.elapse(SearchCommitPolicy.localCatalog);
        expect(commits, isEmpty);
      });
    });

    test('policy durations: local 250ms, market 400ms', () {
      expect(SearchCommitPolicy.local, const Duration(milliseconds: 250));
      expect(SearchCommitPolicy.localCatalog, SearchCommitPolicy.local);
      expect(SearchCommitPolicy.localCollection, SearchCommitPolicy.local);
      expect(SearchCommitPolicy.remote, const Duration(milliseconds: 400));
      expect(SearchCommitPolicy.immediate, Duration.zero);
    });
  });
}
