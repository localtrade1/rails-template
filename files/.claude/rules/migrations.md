---
paths:
  - "db/migrate/**"
  - "db/schema.rb"
---

# Migration Conventions

## Timestamps and ordering

- Migration timestamps must be newer than `main`'s schema version. When a long-lived branch falls behind, rename the migration to a current timestamp and bump `schema.rb`'s `version:`.
- Number seed files sequentially — renumber when files are added or removed.

## Column additions

- New columns on existing tables use `null: false` with a sensible `default` whenever possible.
- Use string-backed enums for type columns: `enum :step, { kyc: 'kyc' }`.

## Index additions

- **Always use `disable_ddl_transaction!` + `algorithm: :concurrently`** when adding indexes to existing tables. Combine with `if_not_exists: true` for idempotent reruns.
- Add unique indexes to enforce data integrity at the DB level. Don't rely solely on model validations.
- Use **partial unique indexes** for nullable unique columns: `unique: true, where: 'idempotency_key IS NOT NULL'`.

## Data migrations

- Data migrations use model classes (e.g., `Product::Enrollment.where(...)`), not raw SQL.
- Clean up orphaned records when restructuring data.
- **Irreversible down migrations are a no-op with a comment**, not `raise ActiveRecord::IrreversibleMigration`. This avoids crashing rollback chains.

## Destructive schema changes (`drop_table`, `remove_column`)

A migration that drops a table or column is fast SQL, but it is **unsafe under canary rollback**: if the new application image fails the canary validator and ECS reverts to the prior image, that image still references the now-missing table/column and crashes. Migrations are forward-only relative to canary — the rollback restores code, not schema.

Use a **two-release workflow**:

1. **Release A** — remove all Ruby references (delete the model, drop queries, add `self.ignored_columns` for columns). Merge, deploy, and let it fully bake on prod.
2. **Release B** — in a subsequent PR, drop the table/column. For `drop_table`, wrap in `safety_assured` with a comment linking Release A:
   ```ruby
   safety_assured { drop_table :foo } # references removed in <PR/release link>
   ```

`strong_migrations` blocks `drop_table` outside `safety_assured` to enforce this. `remove_column` is already blocked unless the column is in the model's `ignored_columns`.

## Canary deploys share the database — write migrations for both code versions

### The general principle (applies to any contract change, not just migrations)

**Contract changes ship in two stages.** PR A introduces the new contract terms *without enforcing them* and moves consumers onto the new terms. PR A merges, deploys, and bakes. PR B enforces the new contract and removes the deprecated terms.

Typical Machina app contracts that need this discipline:

- **DB ↔ backend** — the migrations covered here. PR A adds the new columns nullable + ships the application code that writes them. PR B flips `NOT NULL` and (eventually) drops the legacy columns.
- **backend ↔ external consumer** (mobile, partner integration, sibling service) — PR A adds the new wire fields and keeps the old ones; consumers cut over. PR B drops the legacy fields after every consumer has migrated.

Skipping the two-stage discipline is what causes Sentry bursts during canary bake. The rest of this section is the DB ↔ backend specifics.

### The canary mechanism

Our standard canary topology runs the schema migration **once** in the deploy pipeline, then for ~15 minutes both the new image (canary pods, 25%) and the prior image (75%) serve traffic against the same updated schema. The prior image cannot know about columns, callbacks, or accessors that landed with the new image. Every migration must therefore be safe for the **prior release's code to write into the new schema**, not just the new code.

This is a superset of the canary-rollback concern above. Even if no rollback fires, the prior pods still serve writes against the new schema for the duration of the bake.

### Hazardous shapes

- **NOT NULL added in the same release that introduces the column or bridge** that fills it. Prior pods don't populate the column → INSERTs fail under `null_violation` for the bake window.
- **Same-migration `add_column` + backfill + `change_column_null false`**. Prior pods receiving new traffic during bake write only the old columns → NOT NULL rejects the row.
- **Renaming or removing a column the prior release still reads or writes** (covered by the two-release workflow above).
- **Default values whose computation lives only in the new image's Ruby code.** The DB default fires on prior-image writes too; an inert default is fine, a computed one drifts.

### Two ways to make this safe

**Split across releases (preferred).**

- **Release A** — add new columns nullable; ship the application-level bridge / dual-write / accessors that populate them. Deploy, bake, promote. Wait for it to be the "prior release" everywhere.
- **Release B** (subsequent PR, subsequent deploy) — flip NOT NULL. By Release B, every pod (canary AND prior) has the bridge, so the constraint can't catch a write in flight.

This is the same shape as the `remove_column` / `drop_table` two-release workflow. Cite Release A in `safety_assured`:

```ruby
# safety_assured: <Release A PR URL — added input_atomic bridge in app code>
safety_assured do
  change_column_null :gold_swaps, :input_atomic, false
  change_column_null :gold_swaps, :input_symbol, false
end
```

**Deploy in hotfix mode.**

When splitting isn't feasible — typically because the bridge and the constraint are needed together for a bounded window — deploy via the app's hotfix-mode canary (collapses the standard 25% / 15-minute step bake into 100% / ~1-minute, total ~2-3 minutes). Old pods are taken out faster; the dangerous overlap window shrinks from 15 minutes to a couple of minutes.

The Sentry validator still runs in hotfix mode, so a real regression still gets caught — it just gets caught quicker, and the prior-image-writes-against-new-schema artefacts burn briefer.

### When you ship a hazardous migration

Add a one-line marker comment immediately above the hazardous step explaining the canary risk:

```ruby
# canary_unsafe: prior release does not write input_atomic; deploy via hotfix mode
# OR split into release A (bridge) + release B (this NOT NULL flip).
safety_assured do
  change_column_null :gold_swaps, :input_atomic, false
end
```

Reviewer can then check which mitigation the PR chose, and the deployer knows to select hotfix mode rather than the standard canary.

### Worked example: NOT NULL after a backfill

**Wrong**:

```ruby
def up
  add_amount_columns           # adds input_atomic, input_symbol etc, nullable
  backfill_input               # raw UPDATE from legacy columns
  add_not_null_constraints     # flips NOT NULL same migration
end
```

During canary bake of *this* release, prior pods still run the pre-bridge code → write only legacy columns on new swaps → INSERT fails on `input_atomic = null` for ~15 minutes. Sentry burst, no real rollback option (the schema is already in place; reverting the image just removes the bridge for everyone). Resolved by force-promoting the canary, which is the fix-forward, not the protection.

**Right (two-release):**

```ruby
# Release A — adds the columns nullable and backfills.
def up
  add_amount_columns
  backfill_input
end
```

Release A's application code ships the `before_validation :sync_amounts_from_legacy` bridge that writes the new columns. Deploy, bake, promote, let it become the "prior release" everywhere.

```ruby
# Release B (subsequent PR, subsequent deploy)
# safety_assured: <Release A PR URL — added the bridge>
safety_assured do
  change_column_null :gold_swaps, :input_atomic, false
  change_column_null :gold_swaps, :input_symbol, false
end
```

By Release B's canary bake, both old and new image have the bridge → the constraint can't catch a write in flight.

**Right (hotfix mode):**

Same migration as the wrong example, deployed via the app's hotfix-mode canary. Dangerous window shrinks to ~2 minutes. Acceptable trade-off when the splitting cost is high and the prod write volume during the window is small. Mark the migration `canary_unsafe:` so the deployer knows to use hotfix mode rather than the standard canary.

## Don'ts

- Don't create migrations that just assign attributes and save — that's a service or rake task, not a schema migration.
- Don't add a model-level `validates_uniqueness_of` when a DB unique index is the right enforcement mechanism.
- Don't drop tables/columns in the same release that removes the code referencing them — see the two-release workflow above.
