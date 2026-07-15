---
paths:
  - "app/controllers/**/webhooks/**"
  - "app/services/**/webhooks/**"
  - "spec/**/webhooks/**"
---

# Webhook Conventions

## Response rules

- **Return 2xx for payloads that don't map to local state.** Log at `warn` with enough context to trace, echo the external ID back. A `failure` causes the provider to retry forever.
- **Webhook handler work must run async.** If the controller dispatches via `call_async`, child services can run synchronously within that job. Never do slow I/O in the request cycle.

## Data handling

- **Stash raw provider payloads in `metadata`.** Persist the untouched body under a namespaced key (e.g., `metadata['<provider>_payload'] = body`) plus a sibling `_at` timestamp. Don't invent flattened columns for provider-owned data.
- **Design for idempotent handling via dedup keys.** External webhooks may arrive before or after internal processing. Stamp records with the dedup key synchronously so the webhook's dedup check finds the existing record.

## Testing

- **Use captured-payload JSON fixtures, not inline hashes.** Organize as `spec/support/fixtures/<provider>/webhooks/<resource>/<action>.json`.
- **Assert JSON columns with string keys.** JSON columns deserialize with string keys — `metadata['<provider>_payload']`, not `metadata[:<provider>_payload]`.
- **`freeze_time` around `_at` timestamp assertions.** Any assertion comparing against `Time.current` needs `freeze_time do ... end`.
