CI for `output/event_bus/` keeps failing at random in `EventBus.DeliversPublishedEvent` and
sometimes in `MultipleSubscribers`. People just hit re-run until it's green. Please find out why,
and fix it properly in place:

- Make the tests deterministic. No sleeps or timing assumptions in the tests.
- If the flakiness hides real bugs in `EventBus` itself, fix those too. The header documents the
  contract the class is supposed to meet. Keep the public API source-compatible, though you may add
  to it.
- Add tests that would have caught each bug you fix.
- Everything must pass `ctest --repeat until-fail:50` and stay clean with
  `-Wall -Wextra -Wpedantic -Werror` and ThreadSanitizer.

Don't leave a build directory in `output/`.
