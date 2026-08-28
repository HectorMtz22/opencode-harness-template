# Tracker configuration

Single source of truth for this repo's issue tracker. Written by `/harness-setup`
and read by `/harness-bootstrap`, `/task-init`, and `/task-implement`. Committed
on purpose — it's harness config, not a scratch spec.

```yaml
tracker:       plane          # plane | linear | github | other
mcp_prefix:    mcp__plane      # MCP tool namespace, e.g. mcp__plane__create_cycle
project_code:  PROJ            # short id used in issue identifiers (PROJ-12)
project_id:    <uuid-or-slug>  # set if the MCP server needs one (Plane does)
has_cycles:    true            # true → time-boxed cycles; false → milestones/none
cycle_length:  1w              # cycle duration (weekly)
cycle_anchor:  monday          # week runs Monday → Sunday
```

Run `/harness-setup` to (re)generate this file; run `/harness-bootstrap` to
create the project, states, type labels, and cycles in the live tracker.
