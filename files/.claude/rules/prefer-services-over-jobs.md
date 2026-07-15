---
paths:
  - "app/jobs/**"
  - "spec/jobs/**"
---

# Prefer Services over Jobs

Prefer `call_async` over standalone job classes. Services provide schema validation, error handling, logging, benchmarking, and event emission that raw ActiveJob classes don't.

```ruby
# Preferred: use call_async
SendReminder::Service.call_async(user_id: user.id, wait: 1.day, queue: :notifications)
```

If a job is genuinely required (e.g., complex scheduling, cron jobs, or cases `call_async` can't cover), create the job but keep business logic in a service — the job should only call the service:

```ruby
class MyComplexJob < ApplicationJob
  def perform(user_id:)
    MyDomain::DoWork::Service.call(user_id: user_id)
  end
end
```

See the servus-patterns rule for full `call_async` documentation.
