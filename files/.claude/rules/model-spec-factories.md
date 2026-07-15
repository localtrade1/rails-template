---
paths:
  - "spec/**/models/**"
  - "spec/models/**"
---

# Model Spec Factory Usage

Use `build` by default in model specs. Only use `create` when the test actually queries the database. Every `create` call costs ~7ms (DB insert + callbacks); `build` is in-memory only.

## When to use `build`

- Validation specs (`validate_presence_of`, `validate_uniqueness_of`, etc.)
- Enum specs (`define_enum_for`)
- Attribute and instance method specs that don't query the DB
- Association existence checks via shoulda-matchers (`belong_to`, `have_many`)

```ruby
subject { build(:user) }
it { is_expected.to validate_presence_of(:name) }
```

## When `create` is required

- Scope specs — scopes query the DB
- Specs that test association queries (`.count`, `.where`, `.includes`)
- Callbacks triggered by persistence (`after_commit`, `after_create`)
- Uniqueness constraints enforced at the DB level
- Tests that call `reload`

```ruby
it 'returns active users' do
  active = create(:user, active: true)
  create(:user, active: false)
  expect(User.active).to eq([active])
end
```
