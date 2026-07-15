---
paths:
  - "app/mailers/**"
  - "app/views/**/mailer*/**"
  - "spec/mailers/**"
---

# Mailer Conventions

## One mailer per domain concept

Don't create a generic `TemplatedMailer`. Each email type gets its own mailer class scoped to its domain (e.g., `Notifications::GraduationMailer`).

## File layout

- Mailer class: `app/mailers/<namespace>/<name>_mailer.rb`
- Templates: `app/views/<namespace>/<name>_mailer/<action>.{html,text}.erb`
- Always provide both HTML and plain-text templates for transactional emails.

## Implementation

- Mailer actions accept **keyword arguments**, not positional: `graduation_welcome(user:, idempotency_key: nil)`
- All user-facing copy is **I18n-keyed**: strings live under `mailers.<namespace>.<email_type>.*` in locale YAML. Templates use `t()` exclusively.
- Use the `Contactable` concern for channel reachability checks — don't roll ad-hoc `email_reachable?` predicates per service.
  
