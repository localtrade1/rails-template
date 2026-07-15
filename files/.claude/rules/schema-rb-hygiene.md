---
paths:
  - "db/migrate/**"
  - "db/schema.rb"
---

# schema.rb Hygiene

## When to commit schema.rb

Only commit `db/schema.rb` when your changeset includes new migrations. If schema.rb has drifted without a migration, revert it:

```bash
git checkout -- backend/db/schema.rb
```

## When committing migrations: regenerate schema.rb from scratch

A `rails db:migrate` on an existing development database produces a schema dump that reflects **accumulated database state**, not necessarily the state that migrations alone produce. This causes drift — phantom indexes, wrong column types, stale comments, or missing constraints.

Before committing schema.rb alongside a migration, regenerate it cleanly:

```bash
just backend-exec rails db:schema:dump
```

Then verify the diff only contains changes related to your migration. If you see unrelated changes (columns you didn't touch, indexes you didn't add), those are signs of pre-existing drift — do not include them in your migration PR. Either:

1. Fix them in a separate cleanup PR, or
2. Revert the unrelated hunks before committing.

## Common drift patterns to watch for

- **Column comments** appearing or disappearing (hand-edited schema.rb)
- **`bigint` vs `integer`** type mismatches (stale dump from older DB state)
- **Phantom indexes** (single-column index listed when only composites exist in migrations)
- **Foreign key names** changing (Rails auto-generates names; different DB states produce different names)
- **Index uniqueness** flags not matching the actual migration

## Gemfile.lock sort order

Different bundler versions may sort the DEPENDENCIES section differently. If `Gemfile.lock` has sort-order-only changes after `bundle install`, commit them — the canonical order is whatever the current bundler produces.
