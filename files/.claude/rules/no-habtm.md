---
paths:
  - "app/models/**"
---

# No `has_and_belongs_to_many`

**Never use `has_and_belongs_to_many`.** It's a deprecated dead-end — no place to attach attributes to the join, no callbacks, no validations on the relationship itself.

## What to do instead

- **Many-to-many that needs a real join row** — use `has_many :through` with an explicit join model. The join model is a first-class table with its own timestamps, validations, and any attributes the relationship carries (role, position, expires_at, etc.).
- **Not actually many-to-many** — use a plain `belongs_to`. Most "M:N" requirements collapse to "this record points to one of those" once you sketch the actual write paths.

```ruby
# WRONG
class User < ApplicationRecord
  has_and_belongs_to_many :projects
end

# RIGHT — explicit join model
class User < ApplicationRecord
  has_many :memberships
  has_many :projects, through: :memberships
end

class Membership < ApplicationRecord
  belongs_to :user
  belongs_to :project
  # role, joined_at, etc. live here
end

class Project < ApplicationRecord
  has_many :memberships
  has_many :users, through: :memberships
end
```

If you later need to record *when* a user joined a project, or *which role* they hold there, the explicit join model already has a home for it. HABTM would have forced a migration to a new model with data backfill — pay that cost upfront.
