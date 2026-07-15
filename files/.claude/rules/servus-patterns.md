---
paths:
  - "app/services/**"
  - "app/guards/**"
  - "app/events/**"
  - "app/controllers/**"
  - "spec/services/**"
  - "spec/guards/**"
  - "spec/events/**"
  - "spec/requests/**"
  - "config/schemas/**"
---

# Servus Framework Patterns

Servus is the app's service object framework. This rule covers services, guards, and event handlers.

## Services

### Directory Rules

`app/services/` exclusively contains `service.rb` files (inheriting `ApplicationService`) and their private support classes under a `support/` subdirectory within the same service namespace (e.g., `Domain::Action::Support::Helper`). Service-specific error classes go in `support/errors.rb` — never inline in the service class. Commitment-callback construction, step managers, and other orchestration helpers also go in `support/`. Shared modules, concerns, and utilities never go here — place those in `lib/`, `app/models/`, or another Rails namespace.

### Declaration

- All services inherit from `ApplicationService`.
- Parameters are declared with `option` (Dry-Initializer).
- The `call` method is the only public interface — it must return `success(data)` or `failure(message)`.

```ruby
module Domain
  module Action
    class Service < ApplicationService
      schema_key 'services::domain::action'

      option :user_id
      option :amount
      option :currency, default: -> { 'USDC' }
      option :metadata, optional: true

      rescue_from SomeExternalError

      def call
        return failure('Amount must be positive') unless amount > 0
        result = do_work
        success(result)
      end
    end
  end
end
```

### Schema Strictness

The JSON schema at `schema_key` is the service's contract — keep it strict so the service body can trust its inputs.

- **No type unions on arguments.** `"type": ["integer", "number", "string"]` means "I don't know what I accept." Pick one shape and normalize it in the service (`BigDecimal(amount.to_s)`, `Currency::USDCAmount.new(_, from: :ui)`) if the caller needs flexibility. Controllers passing query params get strings — the schema should say `string`.
- **No defensive `type:` procs when the schema already enforces the type.** `option :input_token, type: proc(&:to_s)` paired with a schema `"type": "string"` is redundant. Drop the proc — the schema is the contract.
- **Use `enum` for closed-world values.** Token symbols, status strings, swap directions, input units — all belong in a schema `"enum"`. With the enum present, the service body doesn't need `raise ArgumentError` fallbacks for "unknown value" cases. Invalid input is rejected at the boundary.

```ruby
# ✅ Schema enforces, service trusts
# config/schemas/services/gold/jupiter/fetch_quote.json
# "input_token": { "type": "string", "enum": ["GOLD", "USDC"] }

option :input_token

def resolve_mint(symbol)
  Solace::Tokens.fetch(symbol).mint_address
end

# ❌ Schema loose, service defends
option :input_token, type: proc(&:to_s)

def resolve_mint(symbol)
  token = Solace::Tokens.fetch(symbol)
  raise ArgumentError, "Unknown token: #{symbol}" unless token
  token.mint_address
end
```

**Rules:**
- Use `option` declarations, never custom `initialize`
- Use `lazily` for record lookups — accepts both IDs and loaded records transparently. The `option` name must match the `lazily` name:
  ```ruby
  option :user
  lazily :user, finds: User           # User.find(value) when given ID, passthrough when given record
  lazily :account, finds: Account, by: :uuid  # Account.find_by!(uuid: value)
  ```
  Resolution is lazy (first access) and memoized. Callers pass either records or IDs — keeps services `call_async`-ready without manual `@record ||= find` boilerplate.
- `schema_key` references schemas in `config/schemas/services/domain/action/{arguments,result}.json`
  - arguments validated before `call`
  - results validated after `success`
- Validate business rules at the top of `call` with early `return failure(...)` or guard enforcer.
- `failure` vs raising: use `failure()` for expected business-rule violations ("user not eligible"). Raise (e.g., `find_by!`) for system invariants that indicate misconfiguration ("product definition doesn't exist"). If a missing record means the system is broken, don't mask it with a failure response.
- A service that doesn't do what its name says should `failure`, not `success(skipped: true)`. Skipping is the caller's concern — the service either performed its action or it didn't.
- Return honest result flags reflecting what actually happened. Instead of echoing input booleans (e.g. `push:, whatsapp:`), return outcome flags (`push_sent`, `email_sent`) indicating whether each action was dispatched.
- **When two sibling orchestrators need the same derivation**, extract it into a shared service (e.g., `ResolveMerchantFees` called by both `PrepareDeposit` and `PrepareClaim`). Don't duplicate.
- Never create `success()`/`failure()` in private methods — only in `call`

### Response Object (`Servus::Support::Response`)

```ruby
result = MyService.call(user: user, amount: 100)

result.success?        # => true/false
result.data            # success data (nil on failure)
result.error           # Servus::Support::Errors::ServiceError (nil on success)
result.error.message   # error message string
result.error.api_error # { code: :symbol, message: string }
```

### Error Handling

**`failure(message, type:)`** — returns a failure response (preferred for expected errors):
```ruby
return failure('Not found')
return failure('Bad input', type: Servus::Support::Errors::BadRequestError)
return failure(type: Servus::Support::Errors::NotFoundError)  # uses default message
```

**`error!(message, type:)`** — raises an exception, halting execution (for exceptional cases):
```ruby
error!('Critical failure') if system_down?
```

**`rescue_from`** — declares automatic exception-to-failure conversion:
```ruby
# Without block: wraps in specified error type (default: ServiceError)
rescue_from Net::HTTPError, Timeout::Error, use: Servus::Support::Errors::ServiceUnavailableError

# With block: custom handling, must return success() or failure()
rescue_from ActiveRecord::RecordInvalid do |exception|
  failure("Validation failed: #{exception.message}", type: Servus::Support::Errors::ValidationError)
end
```

Use `rescue_from` for external/system exceptions (blockchain, APIs, DB). Use early `return failure(...)` for business logic validation.

**Error types** (all under `Servus::Support::Errors`):

### Service Composition

Always check `.success?` when calling other services:
```ruby
def call
  result = OtherService.call(param: value)
  return result unless result.success?

  success(result.data)
end
```

Private methods should return plain data or pass through service responses from other services — never create new `success()`/`failure()` responses in private methods.

### Async Execution

Services support background execution via `call_async`, which enqueues the service as an ActiveJob:

```ruby
# Basic async call
MyDomain::DoSomething::Service.call_async(user_id: user.id)

# With delay
SendReminder::Service.call_async(user_id: user.id, wait: 1.day)

# With queue and priority
ProcessPayment::Service.call_async(order_id: order.id, queue: :critical, priority: 10)

# With specific execution time
GenerateReport::Service.call_async(report_type: :sales, wait_until: Date.tomorrow.beginning_of_day)
```

**Job options:** `wait:`, `wait_until:`, `queue:`, `priority:`, `job_options:` (Hash for additional ActiveJob options).

**Prefer `call_async` over custom jobs.** If you need background work, write a service with `call_async` instead of creating a standalone job in `app/jobs/`. Services provide schema validation, error handling, logging, and benchmarking that raw jobs don't.

### Controller Integration

Controllers use `run_service` and `validate_body` from `Servus::Helpers::ControllerHelpers`:

```ruby
class Api::V1::SomeController < Api::ApiController
  def create
    run_service MyDomain::DoSomething::Service, user: current_user, **create_params
  end

  private

  def create_params
    validate_body('endpoints::api::v1::some::create')
  end
end
```

- `run_service(klass, **params)` calls the service, stores result in `@result`, and auto-renders errors on failure via `render_service_error`
- `validate_body(schema_key)` validates request body against JSON schema, returns validated data or throws Validation error (handled by ApiController)

**Strong-params idiom** — mirror `ActionController::Parameters` naming. Extract the `validate_body` / `validate_query` call into a same-verb private method and `**splat` it into the service call:

- `show_params` for `def show`
- `index_params` for `def index`
- `create_params` for `def create`
- `update_params` for `def update`
- `destroy_params` for `def destroy`

```ruby
# ✅ Strong-params style
def show
  run_service MyService, **show_params
end

private

def show_params
  validate_query('endpoints::...').slice(:amount, :input_unit)
end

# ❌ Inline validate + positional named args
def show
  query = validate_query('endpoints::...')
  run_service MyService, amount: query[:amount], input_unit: query[:input_unit]
end
```

If the schema constrains the keys, `**splat` is safe. If you want to be defensive against schema drift, use `.slice(:known, :keys)` before the splat.

**Early-return on service failure.** Prefer the leading `return` — it reads top-to-bottom as a guard. The trailing `and return` idiom is harder to scan.

```ruby
# ✅
return render_service_error(result.error) unless result.success?

# ❌
render_service_error(result.error) and return unless result.success?
```

**Access `result.data` by method, not by hash key.** `Servus::Support::Response#data` wraps the success hash in a `DataObject` (a `SimpleDelegator` with `method_missing`), so keys are accessible as methods. The method-access form catches typos as `NoMethodError` instead of silent `nil`.

```ruby
# ✅
@swap = swap_result.data.swap
transaction = swap_result.data.transaction

# ❌ silently returns nil on a typo
@swap = swap_result.data[:swpa]
```

Nested hashes are recursively wrapped, so chained access works: `result.data.user.email`.

---

## Guards

Guards encapsulate reusable validation logic with declarative error metadata. They live in `app/guards/`.

### Using Guards in Services

Every guard class automatically registers two methods on all services:
- **`enforce_<name>!(**kwargs)`** — throws `:guard_failure` on validation failure (halts service with error)
- **`check_<name>?(**kwargs)`** — returns `true`/`false` without halting

```ruby
class Service < ApplicationService
  def call
    enforce_not_discarded!(record: device)           # halts with 404 if discarded
    enforce_ownership!(by: user, of: device)         # halts with 403 if not owner

    success(data)
  end
end
```

### Creating Custom Guards

Always use the generator.

```sh
bundle exec rails g servus:guard my_custom
```

```ruby
# app/guards/my_custom_guard.rb
class MyCustomGuard < Servus::Guard
  http_status 422
  error_code 'my_error'

  message :my_custom do
    { value: kwargs[:value] }
  end

  def test(value:)
    SomeModel.exists?(code: value)
  end
end
```

This auto-registers `enforce_my_custom!` and `check_my_custom?` on all services.

**DSL methods:**
- `http_status(code)` — HTTP status for error response (default: 422)
- `error_code(code)` — error code string for API response (default: `'validation_failed'`)
- `message(template) { block }` — template is an I18n key (Symbol), string with `%{interpolation}`, or Hash. Block returns interpolation data.

**I18n translations** go in `config/locales/en/guards/guards.en.yml`:
```yaml
en:
  guards:
    my_custom: "Invalid value: %{value}"
```

### Testing Guards

Guard specs live in `spec/app/guards/`:

```ruby
RSpec.describe MyCustomGuard do
  describe '#test' do
    it 'returns true when valid' do
      guard = described_class.new(value: 'valid_code')
      expect(guard.test(value: 'valid_code')).to be true
    end

    it 'returns false when invalid' do
      guard = described_class.new(value: 'bad_code')
      expect(guard.test(value: 'bad_code')).to be false
    end
  end

  describe '#error' do
    it 'returns a GuardError with correct metadata' do
      error = described_class.new(value: 'bad').error
      expect(error).to be_a(Servus::Support::Errors::GuardError)
      expect(error.code).to eq('my_error')
      expect(error.http_status).to eq(422)
    end
  end
end
```

---

## Event Handlers

Always use the generator.

```sh
bundle exec rails g servus:event_handler my_event
```

Event handlers subscribe to events and invoke services. They live in `app/events/`.

### Emitting Events from Services

```ruby
class Service < ApplicationService
  emits :referral_created, on: :success, with: :success_payload
  emits :referral_failed,  on: :failure

  def call
    success(data)
  end

  private

  def success_payload(result_data)
    {
      referral_id: referral.id,
      referrer_id: referrer.id,
      referee_id: result_data[:id]
    }
  end
end
```

Events emit automatically after service completion — no manual emission needed in `call`.

### Handling Events

```ruby
class ReferralCreatedHandler < Servus::EventHandler
  handles :referral_created

  # Synchronous invocation
  invoke GrantRewards::Service do |payload|
    { user_id: payload[:referrer_id] }
  end

  # Async invocation with conditions
  invoke SendNotification::Service, async: true, queue: :notifications,
         if: ->(p) { p[:premium] } do |payload|
    { user_id: payload[:user_id] }
  end
end
```

**`handles(event_name)`** — declares which event to subscribe to (one per handler, called once).

**`invoke(service_class, **options) { |payload| ... }`** — declares a service to call when the event fires:
- `async: true` — run via background job
- `queue: :name` — Sidekiq queue for async jobs
- `if: ->(payload) { ... }` — conditional invocation
- `unless: ->(payload) { ... }` — negative condition

- Block maps event payload to service arguments (required).
- NEVER add business logic to event handlers. Only map events to invoke services

Multiple `invoke` calls in one handler are supported.

**`emit(payload)`** — class method for imperative event emission from anywhere:
```ruby
ReferralCreatedHandler.emit({ user_id: user.id, referrer_id: referrer.id })
```

**`schema`** — optional payload validation:
```ruby
schema payload: {
  type: 'object',
  required: ['user_id'],
  properties: { user_id: { type: 'integer' } }
}
```

### Testing Events

```ruby
# Test that a service emits an event
RSpec.describe Referrals::CreateReferral::Service do
  it 'emits referral_created event on success' do
    expect { described_class.call(referee_id: referee.id) }
      .to emit_event(:referral_created)
      .with(hash_including(referral_id: anything, referrer_id: anything))
  end
end
```
