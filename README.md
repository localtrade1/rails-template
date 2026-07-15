# Machina — an opinionated, agent-native Rails template

A `rails new` template for building **production** Rails apps that are meant to
be worked on by AI coding agents (Claude Code and friends) as much as by
humans. It's the template ZAR uses internally — the same one our
non-programmer CEO uses to ship real apps to production — with the internal
plumbing stripped out so you can use it too.

"Agent-native" means the generated app doesn't just contain code — it contains
the **operating manual an agent needs to change that code correctly**: a
`CLAUDE.md` orientation file, 32 curated Claude skills, and 17 path-scoped
coding rules that auto-apply based on which file the agent is editing.

```bash
gh repo clone obie/rails-template ~/rails-template
MACHINA_PORT=3042 rails new myapp \
  -m ~/rails-template/template.rb \
  --skip-test --skip-git
```

## Why this exists

Most Rails templates give you a stack. This one also gives you the **conventions
and guardrails** that keep an autonomous agent on the rails (pun intended) while
it builds features for you:

- **`CLAUDE.md`** — a per-app orientation file: stack, auth flow, dev commands,
  conventions, and hard "never do this" rules an agent reads on the way in.
- **`.claude/skills/`** — 32 curated skills covering Ruby/Rails craft
  (`ruby`, `layered-rails`, `sandi-metz-rules`, `37signals-style`,
  `test-driven-development`), a full Hotwire pack (`hwc-*`), workflow skills
  (`writing-plans`, `executing-plans`, `using-git-worktrees`, `handoff`), and
  app patterns (`rails-activity-timeline`, `rails-tiptap-autosave`,
  `mcp-oauth-setup`, `design-system`).
- **`.claude/rules/`** — 17 path-scoped rules (migrations, controller scoping,
  CRUD routing, service objects, testing conventions, schema hygiene, …). Each
  has a `paths:` frontmatter so the agent only loads the rules relevant to the
  file it's touching.

The result: you (or your CEO) describe a feature, and the agent builds it the
way a senior Rails engineer on the team would — because the team's standards
ship inside the repo.

## The stack

- **Rails edge** (`github: "rails/rails", branch: "main"`), **Ruby 4.0.1**
- **SQLite** in development/test, **PostgreSQL** in production
- **Solid Queue / Cache / Cable** + Mission Control (no Redis needed)
- **Hotwire** (Turbo + Stimulus), **Tailwind**, **Importmap**, **Propshaft**
- **LLM stack**: Raix + OpenRouter + RubyLLM (talk to Claude / OpenAI / Gemini)
- **ViewComponent**, **Servus** (service objects), **state_machines**, **Pagy**
- **RSpec** + **WebMock** + **VCR** (real cassettes, no mocks)
- **Sentry**, **Brakeman**, **bundler-audit**, **Lefthook** pre-commit
- **machina-auth** — optional SSO layer (see [Authentication](#authentication))
- A production **`Dockerfile`**, a **CI workflow**, a **`justfile`** task runner,
  **`mise.toml`** for tool versions, and a wired **`/up` health check**

### Deliberately not included

- **Deploy infrastructure** — this template is infra-agnostic. See
  [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) for what a production setup needs
  and bring your own (Kamal, Fly, Render, ECS, k8s, …).
- **pgvector / MCP server / media pipeline** — opt-in per app; these are
  domain-specific and left out of the base template.

## Prerequisites

- **Ruby 4.0.1** — install via [mise](https://mise.jdx.dev/)
  (`mise use --global ruby@4.0.1`)
- A recent **`rails`** gem on PATH to exec the template. The generated
  `Gemfile` pins edge Rails (`github: "rails/rails"`), which bundle installs
  afterward.
- **PostgreSQL client libraries** for the `pg` gem's C extension
  (`brew install libpq` on macOS). Dev runs on SQLite, so this only matters
  for `bundle install` and production.

## Generating an app

The template is **non-interactive** by design — it's built to be driven by a
Claude Code agent or any scripted/CI environment. Two inputs:

- `MACHINA_PORT` — **required**. The port for `bin/dev` and the OAuth callback.
  Pick a free port (3000 is almost always taken):
  ```bash
  ruby -rsocket -e 'TCPServer.new(3042).close' && echo free
  ```
- The app name — the standard `rails new <name>` argument.

```bash
MACHINA_PORT=3042 rails new myapp \
  -m ~/rails-template/template.rb \
  --skip-test \
  --skip-git
```

**Flag notes:**

- `--skip-test` — recommended; we use RSpec, so Minitest scaffolding is cruft.
- `--skip-git` — recommended; the template does its own `git init` + initial
  commit.
- Do **not** pass `--skip-bundle` — the template's `after_bundle` hook runs
  `rspec:install`, `tailwindcss:install`, `db:prepare`, and the initial commit.

The template aborts with a clear message if `MACHINA_PORT` is missing/invalid.

## Quickstart after generation

```bash
cd myapp
cp .env.example .env.local      # fill in what you need (see below)
bin/setup                       # bundle install + db:prepare
bin/dev                         # web + css + worker on $MACHINA_PORT
```

Environment variables (all optional unless you use the feature):

```
MACHINA_ORG_DOMAIN=example.com   # org email domain for User#org_member?
MACHINA_PRODUCT_ID=...           # only if you keep machina-auth
MACHINA_SERVICE_TOKEN=...        # only if you keep machina-auth
MACHINA_IDENTITY_URL=...         # your identity service (SSO)
OPENROUTER_API_KEY=...           # only for the LLM stack
SENTRY_DSN=...                   # only for error tracking
```

## Authentication

The generated app wires up **`machina-auth`**, a public gem on rubygems.org
that implements SSO against a Machina Console identity service (configured via
`MACHINA_IDENTITY_URL`). It's the standard ZAR internal auth layer, included
here as a working reference — but it only talks to a compatible identity
service, so **for most public users it's a starting point to replace**, not
keep as-is.

The auth layer is intentionally isolated so it's easy to swap. To replace it:

- Delete `app/controllers/auth_controller.rb`, the auth routes in
  `config/routes.rb`, `config/initializers/machina.rb`, and the OAuth bits of
  `app/models/user.rb`.
- Remove `gem "machina-auth"` from the `Gemfile` and drop the
  `Machina::ControllerHelpers` include + `before_action :authenticate!` from
  `ApplicationController`.
- Add Rails 8's built-in authentication generator, Devise, or OmniAuth.

Or, if you run your own compatible identity service, just point
`MACHINA_IDENTITY_URL` at it and keep everything.

## Deployment

Infra-agnostic on purpose. [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md) documents
the production contract (Docker image, Postgres, web + worker processes,
secrets, `/up` health check, object storage) and how the internal ZAR version
wires it up with AWS CDK, so you can reproduce the shape on any platform.

## Editing the template

Two places to change things — **not** interchangeable:

| Want to change… | Edit… |
|---|---|
| **Gemfile**, **routes**, **Procfile.dev**, **.env.example**, the **User migration** | `template.rb` (generated inline via heredocs) |
| **Anything else** — app/, bin/, config/, spec/, .github/, Dockerfile, CLAUDE.md, mise.toml, justfile, lefthook.yml, .claude/ | `files/` (copied verbatim at generation time) |
| **Substitution rules** or **validation/abort behavior** | `template.rb` |

### How substitution works

Files in `files/` use literal placeholder tokens that `template.rb` rewrites in
a single pass after copying:

| Token | Replaced with | Example |
|---|---|---|
| `APPNAME` | app name (snake_case) | `myapp` |
| `APPNAME_CLASS` | PascalCase | `Myapp` |
| `APPNAME_DASHED` | dashed | `my-app` |
| `APPNAME_PORT` | `ENV["MACHINA_PORT"]` | `3042` |
| `APPNAME_DOMAIN` | `ENV["MACHINA_ORG_DOMAIN"]` (default `example.com`) | `example.com` |

Most-specific tokens are replaced first (`APPNAME_CLASS` before bare
`APPNAME`). There is no ERB substitution — the token approach avoids escaping
headaches in JSON/YAML/shell files.

## Smoke testing changes

After editing `files/` or `template.rb`, dry-run the substitution without
running the full (~10 min edge-Rails bundle) `rails new`:

```bash
ruby script/smoke_test.rb
```

It copies `files/` to a tempdir, performs the rename + substitution exactly as
`template.rb` does, checks for leftover `APPNAME` tokens, and parses every
generated `.rb` and YAML file. Exits 0 on success, 1 on any failure.

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 ZAR / Obie Fernandez.
