---
paths:
  - "app/controllers/**"
---

# Controller Scoping: Scope at the Source

STRICTLY ENFORCED. Authorization and resource access should be handled by scoping at the point of loading — not by downstream checks.

## The Rule

When loading a resource, scope it to the current user's access level. If a user can only see their own trades, load trades through their association — don't load all trades and then check ownership later.

```ruby
# WRONG — loads globally, checks ownership downstream
def set_trade
  @trade = Trade.find(params[:id])
  forbidden unless @trade.initiator == current_user
end

# RIGHT — scoped at the source, impossible to access others' data
def set_trade
  @trade = current_user_trades.find(params[:id])
end
```

## Scoping Concerns

Use `ActiveSupport::Concern` modules to encapsulate resource loading for nested controllers. Each concern loads its parent resource via `before_action` and scopes it appropriately.

```ruby
# app/controllers/concerns/account_scoped.rb
module AccountScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_account
  end

  private

  def set_account
    @account = Account.find_by!(user_id: current_user.id)
  end
end
```

Nested controllers include the concern — no need to repeat the lookup or add ownership checks:

```ruby
class Accounts::BankAccountsController < BaseController
  include AccountScoped

  def create
    @bank_account = @account.bank_accounts.create!(bank_account_params)
    # Implicit jbuilder view renders automatically — no explicit render call
  end
end
```

## When to Scope vs. When to Load Globally

- **Scope to current user** when the resource belongs to them (my account, my trades, my bank accounts)
- **Scope to parent** when the resource is nested (rate's trades, trade's attachments)
- **Load globally** only when the resource is intentionally public (browsing all active rates)

## Key Principles

1. **Scope eliminates authorization** — if you load through `@account.bank_accounts`, you can never accidentally return another user's bank accounts
2. **Concerns compose** — a controller can include multiple scoping concerns if needed
3. **`find_by!` for unique lookups** — raises `RecordNotFound` (404) automatically instead of manual nil checks
4. **Shared helpers on concerns** — put rendering helpers or common queries on the concern if multiple controllers need them
5. **Implicit views** — always rely on jbuilder views matching the action name, never explicit `render` unless changing the status code or rendering a different action's view
