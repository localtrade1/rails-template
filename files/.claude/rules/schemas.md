---
paths:
  - "config/schemas/**"
  - "app/schemas/**"
---

# JSON Schema Conventions

## File locations

- **Model schemas:** `config/schemas/models/{namespace}/{model}.json`
- **Service schemas:** `config/schemas/services/{namespace}/{action}.json`
- **Endpoint schemas:** `config/schemas/endpoints/api/v1/{resource}/{action}.json`
- **Compiled monolith:** `app/schemas/schema.json`

All schemas must exist in both the individual file AND `app/schemas/schema.json`. Keep them in sync.

## Schema structure

- Schema IDs use double-colon namespace notation: `models::product::task`, `services::product::tasks::dismiss`, `endpoints::api::v1::tasks::completions::destroy`
- Model schemas define reusable `$defs` for each field (type, description, example)
- Service schemas have `$defs.arguments` (input) and `$defs.result` (output)
- Endpoint schemas have `$meta` (method, path, summary, tags, security, response mappings)

## DRY via `$ref`

- **Endpoint schemas `$ref` model schemas for field definitions.** Don't duplicate field types — reference `#/models::product::task/$defs/priority`.
- **Error responses reference shared schemas.** Use `"401": { "$ref": "#/endpoints::shared::errors/$defs/unauthorized" }`.
- **UUID fields use a `pattern` constraint**, not just `"type": "string"`.

## Don'ts

- Don't inline `schema arguments: { ... }` in the service class — always create a JSON schema file.
- Don't define field shapes in endpoint schemas when a model schema already defines them.
