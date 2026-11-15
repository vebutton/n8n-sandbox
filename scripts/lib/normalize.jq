# Shared by pull.sh and push.sh: how a workflow is stored in git, and what push sends.

# File name stem from the workflow name ("" when the name has no letters or digits).
def slug: ascii_downcase | gsub("[^a-z0-9]+"; "-") | gsub("^-+|-+$"; "");

# The stored form: volatile and read-only API fields stripped, nodes sorted by name.
# Callers sort keys with `jq -S`.
def norm: {
    id, name, active,
    nodes: (.nodes | sort_by(.name)),
    connections, settings,
    pinData: (.pinData // {}),
    staticData,
    tags: ([.tags[]? | if type == "object" then .name else . end] | sort)
  } + (if (.nodeGroups // [] | length) > 0 then {nodeGroups} else {} end);

# The request body for create/update: only the fields the API accepts.
def body: {name, nodes, connections, settings, pinData: (.pinData // {})}
  + (if .staticData != null then {staticData} else {} end)
  + (if (.nodeGroups // [] | length) > 0 then {nodeGroups} else {} end);

# Pinned data, and literal values in secret-looking parameters. Locations only, no values.
def secretish: type == "string"
  and test("pass(word)?|secret|token|api[-_ ]?key|authorization|bearer|cookie"; "i");
def literal: type == "string" and length > 0 and (startswith("=") | not);
def warnings: [
    (if (.pinData // {} | length) > 0
      then "pinned data on: \(.pinData | keys | join(", "))" else empty end),
    (.nodes[] | .name as $n | (.parameters // {}) |
      ( paths(scalars) as $p
        | select(($p[-1] | secretish) and (getpath($p) | literal))
        | "\($n): literal value at \($p | map(tostring) | join("."))" ),
      ( .. | objects | select((.name | secretish) and (.value | literal))
        | "\($n): literal value for \(.name)" ))
  ] | unique;
