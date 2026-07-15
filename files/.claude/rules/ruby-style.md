---
paths:
  - "app/**/*.rb"
  - "lib/**/*.rb"
  - "config/**/*.rb"
  - "spec/**/*.rb"
---

# Ruby Style

Idioms that come up in review repeatedly. Most of these are fixes for symptoms that hide a deeper smell — don't paper over the symptom.

## Don't silence RuboCop

- **Don't disable RuboCop on a line or method.** If a line is too long or a method is too complex, fix the underlying issue: extract a private helper, move a long string to I18n, break a hash across lines. RuboCop comments accumulate as permanent debt; the refactor is usually two minutes.

## Long strings live in I18n

- **Put long strings in `config/locales/`.** Don't inline multi-sentence validation messages, error copy, or user-facing strings in Ruby files. The locale YAML is the home for translatable copy and stays out of the line-length budget.

## Methods stay short

- **Method too long? Extract private helpers.** Don't suppress the line-count cop; break the method into named private methods that each do one thing. The names become free documentation. Aim for the shape: one orchestrator method calling a handful of small private methods.

## Use Ruby's expressive constructs

- **Use `.name` for polymorphic `source_type`, not a string literal.** Write `Accounts::Device.name` instead of `'Accounts::Device'` — survives renames and refactors that the string wouldn't.
- **Use `filter_map` (or `.compact`) when a `map` block can return nil.** If you find yourself writing `array.map { … }.compact`, reach for `filter_map` instead. It's one pass and the intent is clearer.

## STI gotchas

- **STI subclasses don't inherit instance variables set on the parent's singleton class.** When working with class-level ivars in an STI hierarchy (e.g. `@registry` defined on the base), add a superclass fallback so subclasses don't silently see `nil`:
  ```ruby
  def self.registry
    @registry ||= superclass.respond_to?(:registry) ? superclass.registry.dup : {}
  end
  ```
