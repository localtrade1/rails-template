---
paths:
  - "app/**"
---

# Code Conventions

The app follows Rails conventions with purposeful extensions. These anti-patterns are the most common mistakes to avoid.

## Don't: Business logic in models

```ruby
# WRONG
class User < ApplicationRecord
  def transfer_funds(recipient, amount)
    # Complex business logic
  end
end

# RIGHT — use a service
Transfers::Create::Service.call(sender:, recipient:, amount:)
```

Models are for persistence: associations, scopes, basic validations. Business logic always goes in Servus services.

## Don't: Business logic in callbacks

```ruby
# WRONG
class Order < ApplicationRecord
  after_create :send_notifications
  after_create :update_inventory
end

# RIGHT — use events for fan-out
class Orders::Create::Service < ApplicationService
  emits :order_created, on: :success
end
```

Only technical callbacks are acceptable (UUID generation, soft-delete cleanup, code generation).

## Don't: Fat controllers

Controllers handle HTTP concerns only: validate input, call service, render response. No queries, no calculations, no data assembly.

```ruby
# WRONG
def create
  order = Order.new(order_params)
  order.calculate_totals
  order.apply_discounts
  NotificationMailer.order_created(order).deliver_later
  render json: order
end

# RIGHT
def create
  run_service Orders::Create::Service, **create_params
end

private

def create_params
  validate_body('endpoints::api::v1::orders::create')[:data]
end
```

## Don't: Complex database queries in controllers

```ruby
# WRONG
def index
  @users = User.active
               .joins(:orders)
               .where('orders.created_at > ?', 1.month.ago)
               .where.not(graduated_at: nil)
               .group_by(orders: :id)
               .order(initial_queue_position: :desc)
end

# RIGHT
def index
  run_service Users::ListActiveCustomers::Service, since: 1.month.ago
end
```

## Don't: Business logic in controller concerns

A concern that does queries, state management, or data transformation is a service object in disguise. Extract it.

## When to use what

| Scenario | Solution |
|----------|----------|
| Complex business operation | Servus service object |
| Cross-cutting concern (notifications, rewards) | Event handler |
| Common validation (ownership, soft-delete) | Guard object |
| Background processing | Job that calls a service |
| External API integration | Service in `app/services/external_providers/` |
| Isolated subsystem | Rails engine |

## Don't: Top-level models

Models **must** be namespaced under a domain module. Never define `FeeConfig` — use `Merchants::FeeConfig`.

## Don't: Source-specific columns on reusable STI types

When an STI type must work across products, use `store_accessor :metadata, :source_type, :source_id` instead of adding source-specific columns. Keeps the type reusable.

## Do: DB-backed singleton config with in-memory map

For config that lives in the DB (e.g., fee configs per country):
```ruby
class << self
  def for(key)
    config_map[key] || config_map[GLOBAL_DEFAULT]
  end

  private

  def config_map
    @config_map ||= all.index_by(&:key)
  end

  def reload_singleton!
    @config_map = nil
  end
end

after_commit :reload_singleton!
```

## Do: RESTful resource modeling

Model domain actions as REST resources, not custom verbs:
- "Dismiss a task" = `DELETE /tasks/:task_id/completion`, not `POST /tasks/:id/dismiss`
- Use singular `resource :completion` for 1:1 sub-resources

## Do: Initializers that touch the DB must be boot-safe

```ruby
rescue ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
  # Tolerate db:create / db:migrate
```

Honor `ENV['SKIP_SEEDS']` as an escape hatch for CI/tooling.

See `backend/AGENTS.md` for the full controller rules, naming conventions, and architectural patterns.
