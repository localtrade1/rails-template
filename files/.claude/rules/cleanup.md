---
paths:
  - "app/**"
  - "lib/**"
  - "spec/**"
---

# Cleanup Discipline

Leave the campsite cleaner than you found it. Dead code, stale comments, and silent rescues all rot the codebase from the inside.

## Strip before pushing

- **Delete stale TODOs and empty rescues.** A `# TODO: implement` comment sitting above real implementation is always caught in review. So is a `rescue ArgumentError` with an empty body. Strip them before opening the PR.
- **Remove unused method arguments.** If a parameter is prefixed with `_` to suppress "unused" warnings, remove the parameter entirely or redesign the interface. The underscore is a band-aid, not a fix.
- **Delete dead code proactively when touching a subsystem.** When you're already in the file, remove what no longer belongs rather than leaving it for later. The next person to read the file shouldn't have to figure out which methods are still called.

## Don't swallow errors

- **Don't rescue broad exception classes without handling.** `rescue StandardError` or `rescue ArgumentError` that catches and ignores masks real bugs forever. Rescue the specific class you expect, do something meaningful with it (log with context, convert to a domain error, retry), and let everything else propagate.

## Mark temporary code

- **Tag throwaway code with a grep-able cleanup marker.** Adapter shims, dual-write bridges, and delegation layers that exist for a migration window get a marker like `PHASE3-CLEANUP` or a ticket number (`# Fizzy #1082`) in a comment. Document the grep command in the PR body so a follow-up PR can mechanically delete every tagged site instead of doing archaeology to find them.
