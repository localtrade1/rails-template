---
paths:
  - "db/seeds/**"
  - "db/seeds.rb"
---

# Seeds Rules

Read `backend/db/seeds/README.md` before modifying any seed file.

## Hard rules

1. **`find_or_create_by!` only.** Every seed must use `find_or_create_by!` with a block. Never use `find_or_initialize_by` + `save!` — that is an upsert and will overwrite production data.

2. **No environment checks.** Never use `Rails.env.development?`, `Rails.env.test?`, `Rails.env.local?`, or any environment guard to conditionally skip or include data. Every seed runs in every environment.

3. **No test or development data.** Seeds are for records the application requires to function — roles, products, compliance policies, etc. Test fixtures, fake users, sample merchants, historical backfills, and demo content do not belong here.

4. **Idempotency key must be meaningful.** The lookup key in `find_or_create_by!` must be a stable, unique business identifier (e.g., `code`, `name`, `client_type`, `[code, version]`). Never use database IDs or timestamps.

5. **Block sets attributes, not the caller.** All attribute assignment goes inside the `find_or_create_by!` block via `assign_attributes`. The block only executes on create, so existing records are never touched.

```ruby
# Correct
Model.find_or_create_by!(code: attrs[:code]) do |record|
  record.assign_attributes(attrs)
end

# Wrong — upsert pattern
record = Model.find_or_initialize_by(code: attrs[:code])
record.assign_attributes(attrs)
record.save!
```

## Adding a new seed

1. Create a new file with the next sequential number prefix (e.g., `08_new_thing.rb`)
2. Use `find_or_create_by!` with a clear idempotency key
3. Update `backend/db/seeds/README.md` if the design principles change
