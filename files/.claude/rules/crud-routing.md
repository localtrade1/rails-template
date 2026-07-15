---
paths:
  - "config/routes.rb"
  - "config/routes/**"
  - "**/config/routes.rb"
  - "**/config/routes/**"
---

# Routing: Everything is CRUD

STRICTLY ENFORCED. No exceptions without explicit user approval.

## Rules

1. **Only CRUD actions.** Controllers expose only `index`, `show`, `create`, `update`, `destroy`. Never define custom actions via `member`, `collection`, or match routes to non-CRUD methods.

2. **No `only:` or `except:`.** Define the full resource. If a controller doesn't implement an action, Rails returns 404 naturally. `only:` clutters routes with implementation details.

```ruby
# WRONG
resources :orders, only: %i[index show create]

# RIGHT
resources :orders
```

3. **Max one level of nesting.** `resources :cards { resources :comments }` is the deepest allowed. Never nest three levels.

4. **New noun, not new verb.** When an action doesn't fit CRUD on the existing resource, model it as a new resource. If you're naming a verb (`prepare`, `attach`, `cancel`, `skip`, `monitor`), stop — that verb is a `create` on a noun (`preparation`, `attachment`, `cancellation`), or a `show` on an existing one.

5. **`scope module:` for sub-resources.** Keeps URL nesting to one level while organizing controllers into modules.

6. **`resource` (singular) for one-per-parent.** A wallet has one transaction per request. Use `resource` (no `:id` in URL) — the parent's ID is the only identifier needed. Use `resources` (plural) for has-many.

7. **No bare match/get/post routes.** Every route goes through `resources` or `resource`. The only exceptions are `root`, engine `mount`, and `resolve`.

8. **Namespaces provide context, not behavior.** Namespaces group related resources under a URL prefix and controller module. The resources inside are still nouns with standard CRUD.

9. **`resolve` for polymorphic URL generation.** When `polymorphic_url` needs custom routing logic, use `resolve` blocks — not helper overrides.

## Example: Wallets

**Bad** — custom verbs, bare routes, namespace-as-controller:

```ruby
# v1
namespace :wallets do
  post 'prepare_bulk_transfer', to: 'bulk_transfers#prepare'
  post 'prepare_update_owner', to: 'update_owner#prepare'
  post 'prepare_add_signer', to: 'smart_account#prepare_add_signer'
  post 'prepare_remove_signer', to: 'smart_account#prepare_remove_signer'

  get 'binance_topup/info', to: 'binance_topup#info'
  get 'binance_topup/status', to: 'binance_topup#status'

  get ':address/tokens', to: 'tokens#index'
end

# non-versioned
namespace :wallets do
  get '/me', to: 'squads_multisigs#show'
  post '/', to: 'squads_multisigs#create'

  get '/enc', to: 'encryption_keys#encrypt_mnemonic'
  get '/dec', to: 'encryption_keys#decrypt_mnemonic'

  resources :transactions, only: %i[index]
end
```

**Good** — wallet is the resource, everything hangs off it as one level of nesting:

```ruby
resources :wallets do                        # GET index, POST create, GET show — wallet address is the :id
  scope module: :wallets do
    resources :tokens                        # GET index — list token balances
    resources :transactions                  # GET index — list transaction history
    resource :bulk_transfer                  # POST create — build an unsigned bulk transfer tx
    resource :ownership                      # POST create — build an unsigned ownership transfer tx
    resource :signer                         # POST create (add signer), DELETE destroy (remove signer)
    resource :binance_topup                  # GET show — topup config, limits, and status
    resource :mnemonic                       # GET show (decrypted), POST create (encrypt)
  end
end
```

Each sub-resource gets its own controller in the `Wallets::` module (e.g., `Wallets::TokensController`, `Wallets::SignersController`). Every action is standard CRUD. Opposing operations (add/remove, encrypt/decrypt) are opposing CRUD actions on the same noun — not separate resources.

## Example: Orders

**Bad** — custom member and collection actions:

```ruby
resources :orders, only: %i[index show create destroy] do
  collection do
    get :preview
    get :analytics
  end
  member do
    post :attach
    post :prepare_transaction
    post :monitor_transaction
  end
end
```

**Good** — each concern is its own resource nested under orders:

```ruby
resources :orders do                         # GET index, GET show, POST create, DELETE destroy
  scope module: :orders do
    resource :preview                        # GET show — preview order details before creation
    resource :analytics                      # GET show — fetch analytics for this order
    resource :transaction                    # POST create (prepare unsigned tx), GET show (monitor tx status)
    resources :attachments                   # POST create — attach files (receipts, screenshots) to the order
  end
end
```

## How to Apply

When adding a new endpoint, ask: "What is the resource noun?" When reviewing existing routes, flag violations but do not refactor unless the user explicitly requests it.
