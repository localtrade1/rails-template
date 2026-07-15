---
paths:
  - "spec/**"
---

# Testing Conventions

## Test structure

```
spec/
├── app/services/     # Service unit tests (bulk of testing)
├── app/controllers/  # Controller unit tests
├── app/models/       # Model tests
├── app/jobs/         # Job tests
├── app/events/       # Event handler tests
├── app/guards/       # Guard tests
├── app/mailers/      # Mailer tests
├── lib/              # Library tests
├── requests/         # HTTP request tests
├── integration/      # Rswag API integration tests (generate OpenAPI docs)
├── factories/        # FactoryBot factories (58+ files)
├── support/          # Test helpers (27+ modules)
└── cassettes/        # VCR recorded HTTP interactions
```

## Service tests (most common)

```ruby
RSpec.describe Domain::Action::Service, type: :service do
  subject(:result) { described_class.call(**params) }

  before { stub_external_apis }

  context 'with valid params' do
    it { is_expected.to be_success }
    it 'creates expected records' do
      expect { result }.to change(Model, :count).by(1)
    end
  end

  context 'with invalid params' do
    it { is_expected.not_to be_success }
  end
end
```

- Mock all external dependencies (see mock modules below)
- Use `freeze_time` for time-dependent assertions
- Test both success and failure paths
- Use `servus_success_result(data)` / `servus_failure_result(msg)` for mocking service responses

## Integration tests (schema-driven)

Use `describe_endpoint` for all new API endpoint specs. It auto-configures auth from the schema's `$meta.security`, provides `make_request` for sending signed requests, and validates responses against the JSON schema. These specs also generate Orval types for the mobile app.

```ruby
RSpec.describe 'Merchant Program Fee API', type: :request do
  describe_endpoint 'endpoints::api::v1::merchant_program::fees::show' do
    let(:country_code) { nil } # query param — let name matches schema property

    it 'returns the fee config' do
      make_request
      expect(response).to have_http_status(:ok)
      expect(response_data['fee_bps']).to eq(100)
    end

    context 'when unauthenticated' do
      let(:'X-App-Public-Key') { nil }

      it 'returns 401' do
        make_request
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
```

- Schema key maps to `config/schemas/endpoints/...` — add `"security": ["deviceSignatureAuth"]` to `$meta` for auto-auth
- `make_request` builds headers, signs the request, and validates the response schema
- `response_data` is shorthand for `response.parsed_body[:data]`
- `let` names matching schema query/path properties are auto-resolved into the request
- Specs live in `spec/integration/`

## Mock modules

Stub external APIs through dedicated `Mock<Provider>` modules under
`spec/support/` rather than scattering WebMock stubs through specs. Each
module owns the URL patterns, response shapes, and credential injection for
one external dependency. Services include the relevant mock module in their
`before` block; cross-cutting tests stub all of them via a shared helper.

## Event handler specs

Use the `call_service` custom matcher to assert async dispatch:
```ruby
expect { described_class.handle(payload) }
  .to call_service(SendNotification::Service).async.with(user_id: user.id)
```

## Idempotency testing

Step managers and services with dedup logic need explicit idempotency specs:
```ruby
context 'when called twice' do
  before { described_class.new(enrollment).call }

  it 'does not create a duplicate task' do
    expect { described_class.new(enrollment).call }
      .not_to change(Product::Tasks::ReferralTask.where(enrollment: enrollment), :count)
  end
end
```

## Edge-case coverage

Each business rule gets its own `context` block named after the scenario, not the assertion:
- `context 'when task is not dismissable'` (not `context 'returns 403'`)
- Cover: happy path, unauthorized, not found, already completed, already dismissed, wrong owner, etc.

## Factory conventions

Numeric, amount, and timestamp attributes in FactoryBot factories should default to randomized values within a realistic range. Constant literals make co-created records suspiciously identical and mask specs that accidentally depend on factory-side values.

```ruby
# ✅ Random default within realistic range
factory :gold_swap, class: 'Gold::Swap' do
  input_amount { Faker::Number.between(from: 1_000_000, to: 100_000_000) } # 1–100 USDC atomic
  expected_output_amount { Faker::Number.between(from: 1_000, to: 100_000) }
end

# ❌ Constant literals
factory :gold_swap, class: 'Gold::Swap' do
  input_amount { 10_000_000 }
  expected_output_amount { 3_268 }
end
```

Specs that care about a specific value pass it explicitly — the override stays local to the spec that depends on it:

```ruby
create(:gold_swap, :buy, :completed, user: user, input_amount: 50_000_000)
```

Attributes derived from other attributes (e.g., `net_invested_usdc { input_amount - fee }`) stay derived so they follow whatever override the spec passes.

## Key conventions

- Coverage minimum: **90%** (SimpleCov with branch coverage)
- Database strategy: transactional fixtures, pre-suite truncation
- Feature flags: in-memory Flipper adapter (`Flipper.enable(:flag)` in `before` block)
- CI: 4 parallel workers via `PARALLEL_TEST_PROCESSORS`
- Factories use dynamic values for any field that should vary (e.g., crypto keypairs via `RbNaCl::SigningKey.generate` when applicable)
- Factory traits model state variations (`:dismissed`, `:completed`). Use `parent:` to inherit from base factories.
- Reference constants from the class under test (`described_class::TASK_LABEL`) rather than hardcoding strings.

## Discipline

- **Test failures are always our responsibility.** Don't dismiss a red build as "pre-existing" or "unrelated" — fix every failure before declaring work done. A green suite is a prerequisite for shipping, period.
- **Never run migrations directly against the test database.** Run `bin/rails db:migrate` in development only. The test database is prepared via `bin/rails test:prepare` (or automatically when running tests), which loads `db/schema.rb`. Running `RAILS_ENV=test bin/rails db:migrate` causes schema drift between development and test.
