# frozen_string_literal: true

# Allow state_machine event names to shadow Kernel methods on host models
# (e.g. `fail!` on a domain model). The warning is just informational;
# scoping to AR instances is exactly what we want.
StateMachines::Machine.ignore_method_conflicts = true
