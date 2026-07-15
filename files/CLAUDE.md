# APPNAME — Agent Notes

APPNAME is a Machina app, generated from the
[Machina Rails template](https://github.com/obie/rails-template).

## Quick orientation

- **Stack**: Rails edge, Ruby 4.0.1, SQLite (dev/test) + PostgreSQL (production),
  Hotwire, Tailwind, Importmap, machina-auth.
- **Port**: `APPNAME_PORT` in development.
- **Auth**: SSO via `machina-auth` (points at the identity service in
  `MACHINA_IDENTITY_URL`). Permissions defined in `config/machina.yml`.
  The auth layer is optional — see the template README for how to swap or
  remove it.
- **Worker**: Solid Queue. Consider different queues for different types of jobs.

## Running locally

```bash
mise install      # ruby 4.0.1
bin/setup         # bundle + db:prepare
bin/dev           # foreman fleet from Procfile.dev (web + css + worker)
```

The fleet runs on port `APPNAME_PORT`.

## Auth flow

1. Unauthenticated request hits any controller → `before_action :authenticate!`
   redirects to `/login`.
2. `AuthController#login` renders a link to the identity service authorize URL.
3. User completes OAuth at the identity service, which redirects back to
   `/auth/machina/callback?token=...`.
4. `AuthController#machina_callback` sets the `machina_session` cookie.
5. `ApplicationController#current_user` resolves the session and lazily
   upserts the `User` record from the authorized session attributes.

Org email domain `APPNAME_DOMAIN` is treated as the internal-only allow-list
boundary (enforced upstream by the identity service).

## Conventions

- **No mocks in integration tests** — use VCR cassettes for external API calls.
- **State transitions are the only way to advance ARs with state_machines.**
  Don't update `state` columns directly.
- **Jobs are thin.** They orchestrate state and persistence; real work lives
  in service objects (`app/services/`, `Servus::Base`).
- **Active Storage, not filesystem state.** No filesystem-as-message-bus.

## Agent guidelines

- **Never store credentials anywhere in the repo or memory files.** No
  passwords, API keys, session tokens, or specific account details in
  `MEMORY.md`, skill files, or agent notes.
- **Use `rails runner`, not `rails console`.** The Bash tool can't drive an
  interactive console.
- **Prefer Tailwind utility classes** over hand-written CSS to the extent
  possible.
- **Ask the user to verify non-trivial UI changes in a browser.**
- **Read before assuming.** Before using an internal gem, JS library, or
  in-house API, grep the codebase for existing usages — don't guess at the
  shape.
- **`bin/dev` runs in tmux**, not a devcontainer. The dev fleet is foreman
  driving Procfile.dev → web + tailwind watcher + Solid Queue.
- **Never use `--no-verify` on commits.** If a pre-commit hook fails, fix the
  underlying issue and create a new commit — don't skip the hook.

## Bundled skills

This app ships with curated Claude skills in `.claude/skills/`:

- **Ruby / Rails core**: `ruby`, `rails-guides`, `rails-upgrade`,
  `37signals-style`, `sandi-metz-rules`, `test-driven-development`,
  `verification-before-completion`, `brakeman`, `ruby-commit-message`,
  `systematic-debugging`, `layered-rails`
- **Hotwire pack**: `hwc-stimulus-fundamentals`, `hwc-forms-validation`,
  `hwc-navigation-content`, `hwc-realtime-streaming`, `hwc-media-content`,
  `hwc-ux-feedback`, `better-stimulus`
- **Workflow**: `writing-plans`, `executing-plans`, `requesting-code-review`,
  `receiving-code-review`, `using-git-worktrees`,
  `finishing-a-development-branch`, `handoff`, `handoff-resume`, `handoff-list`
- **Dev tooling**: `bindev`, `design-system`
- **App patterns**: `rails-activity-timeline`, `rails-tiptap-autosave`,
  `mcp-oauth-setup`

Invoke a skill with `/<skill-name>` in Claude Code.

## Bundled rules

This app also ships with auto-applicable Rails coding rules in
`.claude/rules/` — each file has a `paths:` frontmatter that scopes it to
matching paths in the working tree:

- **Code & architecture**: `code-conventions`, `controller-scoping`,
  `crud-routing`, `servus-patterns`, `no-habtm`
- **Ruby style & hygiene**: `ruby-style`, `cleanup`
- **Persistence**: `migrations`, `schema-rb-hygiene`, `seeds`
- **API surface**: `schemas`, `views`, `webhooks`
- **Workers & mail**: `prefer-services-over-jobs`, `mailers`
- **Testing**: `testing-conventions`, `model-spec-factories`

Read all rules under `.claude/rules/` whose `paths:` match the file you're
about to touch before making changes there.

## When in doubt

Follow the conventions already established in this codebase and the bundled
rules under `.claude/rules/`. Prefer the smallest change that fits the existing
patterns for auth, dev tooling, RSpec setup, and Gemfile structure.
