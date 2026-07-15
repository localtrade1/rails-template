---
paths:
  - "app/views/**/*.jbuilder"
---

# Jbuilder View Conventions

## Response rendering

- **Never render JSON inline from a controller.** No `render json: { data: ... }` — always render a jbuilder view, even for simple responses.
- **Reference `@result.data.*` in views.** Use `@result.data.storefront`, not a manually-set `@storefront`. The view consumes the service result directly.

## Field formatting

- **Use `json.(object, :field1, :field2, ...)` shorthand.** Prefer the compact form over repeated `json.id task.id` lines.
- **All endpoints for a resource return the same complete field list.** Create, update, destroy, and custom actions all return identical shapes. When adding a field, update every view that returns that resource.

## Shape consistency

- **WebSocket broadcast payloads must mirror the API response shape.** When adding a field to a REST response, add it to the broadcast concern too.
- **Don't use views to communicate eligibility/state.** If a user shouldn't have access to X, they shouldn't receive an enrollment for X. Conditional `eligible`/`ineligibility_reason` fields are a code smell.
- **Don't fork views during migrations.** Use adapter models so the same view renders both old and new models identically.
