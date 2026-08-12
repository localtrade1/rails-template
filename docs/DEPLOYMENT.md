# Deployment — bring your own infra

This template is **infrastructure-agnostic**. It generates a standard,
container-ready Rails app and gets out of your way on the deploy side — pick
Kamal, Fly.io, Render, Heroku, ECS/Fargate, Kubernetes, or anything else that
can run a Docker image and a Postgres database.

The generated app already ships everything a deploy target needs:

- **`Dockerfile`** — a production, multi-stage build (Thruster in front of Puma).
- **`bin/docker-entrypoint`** — prepares the database on boot.
- **Health check** — `GET /up` (Rails' `rails/health#show`), wired in `routes.rb`.
  Point your load balancer / orchestrator liveness probe here.
- **`Procfile.dev`** — the local dev fleet (web + Tailwind watch + Solid Queue).
  For production, run the web process and a separate worker process.
- **Solid Queue / Cache / Cable** — database-backed, so you don't need Redis.
  In production these use the Postgres database configured in `config/database.yml`.

## What a production setup needs to wire up

Whatever platform you choose, a production deployment of an app from this
template requires:

1. **A Docker image** built from the shipped `Dockerfile` and pushed to a
   registry your platform can pull from.
2. **A PostgreSQL database.** `config/database.yml` is configured for a
   multi-database production layout (primary + `cache`, `queue`, and `cable`
   databases for the Solid trinity). You can collapse these to a single
   database if you prefer — adjust `database.yml` accordingly.
3. **A web process** running the image (Thruster/Puma), fronted by your load
   balancer, with the liveness/readiness probe pointed at `/up`.
4. **A worker process** running `bin/rails solid_queue:start` for background jobs.
5. **Secrets / environment** delivered to both processes:
   - `RAILS_MASTER_KEY` (or `config/credentials`), `DATABASE_URL`(s)
   - `MACHINA_PRODUCT_ID`, `MACHINA_SERVICE_TOKEN`, `MACHINA_IDENTITY_URL`,
     `BASE_URL` (the app's public origin; the machina-auth callback
     `<BASE_URL>/machina/callback` is derived from it) — only if you keep the
     machina-auth layer (see "Authentication" below)
   - `OPENROUTER_API_KEY` — only if the app uses the LLM stack
   - `SENTRY_DSN` — only if you want error tracking
6. **Object storage** (S3 or compatible) for Active Storage in production.
   The `aws-sdk-s3` gem is already in the Gemfile.

### Reference: how the internal version deploys

ZAR's private variant of this template ships an AWS CDK (`infra/`) tree with
three stacks, described here so you can reproduce the shape on any platform:

- **Foundation** — ECR repository, ECS cluster, RDS (Postgres), S3 bucket, and
  a secrets construct (AWS Secrets Manager).
- **Application** — the web service and the worker service running the image,
  behind an Application Load Balancer with the `/up` health check.
- **Monitoring** — CloudWatch alarms routed to a chat channel.

That CDK tree depends on a private, ZAR-internal construct library and is **not**
included in this public template. The list above is the contract; implement it
with whatever IaC you already use.

## Authentication and deployment

The auth layer (`machina-auth`) speaks an SSO protocol against an identity
service configured by `MACHINA_IDENTITY_URL`. If you are not running a
compatible identity service, either:

- point `MACHINA_IDENTITY_URL` at your own compatible service, or
- replace the auth layer with Rails 8's built-in authentication generator,
  Devise, or OmniAuth (delete `AuthController`, the auth routes, the
  `machina.rb` initializer, and the OAuth bits of the `User` model), or
- comment out `gem "machina-auth"` in the `Gemfile` and remove the
  `before_action :authenticate!` / `Machina::ControllerHelpers` usage in
  `ApplicationController`.

See the README's authentication section for more detail.
