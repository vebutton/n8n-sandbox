# n8n Sandbox — Project Context for Claude Code

> **File roles:** CLAUDE.md (this file) = project context. `TODO.md` = the task register.
> `docs/requirements.md` = the spec. This is an app project, so there is no system prompt.

## User
The operator: a technical presales/solutions person who is comfortable with containers,
Podman and Claude Code but **new to n8n**. Explain n8n concepts as they come up and skip
the container basics. Committed files never name the user or their employer: both live
in `CLAUDE.local.md`, so this file reads correctly in any teammate's session.

## Environment
- First started: CLI
- Date: 2026-11-13

## This Project
A **disposable sandbox for learning n8n**, set up around an upcoming n8n event (date in
`CLAUDE.local.md`). It **uses** a local n8n instance that a sibling infra project
(podmanager) owns and runs. This project owns only its workflows and its own API key.
Claude Code manages the workflows from the Mac through n8n's REST API, and the workflow
JSON is version-controlled here. If something more compelling comes out of it, that
becomes a **new project**. Keep it light: no polish, no multi-tenancy.

- **Instance handoff:** [docs/n8n-instance.md](docs/n8n-instance.md). What's running,
  addresses, what n8n can reach, what's unavailable, and the rules. Read it before
  touching n8n.
- **Full requirements:** [docs/requirements.md](docs/requirements.md)
- **Task register:** [TODO.md](TODO.md), the only durable task list. Read it before
  planning any work.
- **Internal details:** `CLAUDE.local.md`, gitignored. Read it every session.

## Input / Output
- **Input:** workflow JSON in `workflows/` (authored in git or exported from the n8n UI).
  For Track 2, transcript files in the inbox. n8n reads them at
  `/home/node/.n8n-files/inbox`, which is **read-only**.
- **Output:** workflows created or updated in n8n. For Track 2, summaries written to the
  outbox, which n8n sees at `/home/node/.n8n-files/outbox` (read-write).
- The Mac-side folders behind the inbox and outbox are in `CLAUDE.local.md`.

## Interface
Claude Code CLI on the Mac, plus the n8n web UI at `http://localhost:5678` (use
`localhost`, because secure cookies are on).

## Key Integrations
- **n8n public REST API** at `http://localhost:5678/api/v1`, authenticated with the
  `X-N8N-API-KEY` header. Swagger is at `/api/v1/docs/`. The key is `N8N_API_KEY` in the
  vault-encrypted `.env.local` (gitignored). The operator sources it into the shell, and
  scripts read `$N8N_API_KEY` from the environment and pass the header to curl on stdin
  (`curl -K -`). Never pass it on a command line.
- **Local LLM**: oMLX, OpenAI-compatible, reached from n8n at
  `http://host.containers.internal:8000/v1`. The workflow credential is **`oMLX local`**
  (id `4w0q11tHyjp3OV4R`, type OpenAI with a custom Base URL; the model is picked per
  node). Use it in AI nodes and don't create a second one. The model is shared with
  another project, so keep prompts small. The `n8n Assistant model` named in
  `docs/n8n-instance.md` is not a workflow credential. It is the model for n8n's
  built-in Assistant (the `instance-ai` module), set in the UI and pointed at oMLX.
  The Assistant also needs a code sandbox, which is not set up (see TODO.md Unscheduled).
- **No Anthropic API key**, and a Claude subscription cannot be used from n8n. Don't
  design anything that assumes Claude inside n8n.

## Tech / Tooling
- **Scripts:** Bash + `curl` + `jq` (all present). No Python unless a script outgrows
  Bash. If it does, use pyenv + uv.
- **Instance:** n8n `2.47.7` (version pinned), bound to `127.0.0.1:5678`. Full detail is
  in `docs/n8n-instance.md`.
- **Not available:** the code sandbox service (ordinary Code nodes work), inbound
  webhooks from outside the host, email/SMTP, and paid features.

## How to Work With This User
- Direct and concise. Explain *n8n-specific* behaviour, not general dev concepts.
- Label claims about n8n features as verified (tested here) or from memory. n8n changes
  fast, especially its AI and MCP features.
- **Never manage the instance from this project.** No `podman machine` or `podman run/rm`
  commands, and no changes to `n8n_data`. Any change to env vars, ports, mounts, nodes or
  version is a request to the operator for podmanager. Read-only checks (`curl`,
  `podman ps`, `podman inspect`) are fine.

---

## Tracks

> A **track** is a distinct workstream with its own objective. Item IDs in `TODO.md` use
> the track slug: `T-<SLUG>-<nn>`. Slugs are permanent.

### Track 1 — Workflows as code (WFC)
- **Objective:** Claude Code on the Mac can pull workflows from n8n into `workflows/` and
  push them back over the REST API. The existing test workflow (`My workflow`, a manual
  trigger → HTTP request) is committed as the first example.
- **Status:** Not started. It is blocked only on the API key (T-WFC-01).
- **Depends on:** Nothing. This is the first track.

### Track 2 — Transcript summary (XSUM)
- **Objective:** a transcript dropped into the inbox is picked up by n8n, summarised by
  the local LLM, and the summary is written to the outbox.
- **Status:** The infrastructure is ready: inbox, outbox and model credential exist.
  Only the workflow remains (T-XSUM-03). Secondary to Track 1. If the event provides its
  own lab sandbox, try it there too.
- **Depends on:** Track 1 (may depend). Its workflow is authored and pushed as code via
  WFC.

**Further tracks:** None yet. When adding one, state explicitly whether it may depend on
an existing track or must stand alone.

---

## Session State

> Forward-looking operating context only. Archaeology lives in `docs/session-state.md`.
> Task state lives in `TODO.md`.

**Last (2026-11-13):** T-WFC-01 done. Authenticated `GET /api/v1/workflows` returns 200
with one workflow, `My workflow` (id `BUfTdWopbSCXMfMd`, inactive, manual trigger →
HTTP Request). `.env.local.example` now lists only `N8N_API_KEY`. Local File Trigger
confirmed unavailable, so T-XSUM-03 will poll on a schedule.

**Next session — pick up here:**
1. Cold start: re-read CLAUDE.md, CLAUDE.local.md and `docs/n8n-instance.md`. Consult
   docs/session-state.md on demand.
2. Check that n8n is up: `curl -fsS -o /dev/null -w '%{http_code}\n'
   http://localhost:5678/healthz/readiness` should print 200. If it doesn't, ask the
   operator to start it from podmanager. Don't start it from here.
3. Confirm `N8N_API_KEY` is set (presence only, via `printenv K >/dev/null`). Pass the
   header to curl on stdin: `printf 'header = "X-N8N-API-KEY: %s"\n' "$N8N_API_KEY" |
   curl -sS -K - <url>`. Never put it in argv.
4. T-WFC-02: the pull script, then T-WFC-03 (commit `My workflow`).
5. Ask how the event went (on or after 2026-11-14). Its answers feed TODO.md §3.

**Continuity reminders:**
- n8n is often **stopped**. Only one Podman machine runs at a time on this host, so n8n
  goes down whenever another machine is in use.
- File nodes may only use paths under `/home/node/.n8n-files`. The inbox is read-only,
  so a workflow cannot move or delete processed transcripts. Track processed files
  another way, or have the operator clear them by hand.
- Verified 2026-11-13 (operator, UI node panel): the Local File Trigger node is not
  available. n8n 2.x excludes it by default and no `NODES_EXCLUDE` override is set.
  T-XSUM-03 uses a schedule-plus-read poll. Enabling the node is a podmanager change.
- Verified 2026-11-15: an OpenAI-type credential's Base URL needs the scheme
  (`http://host.containers.internal:8000/v1`). Without `http://` the credential test
  fails with `ERR_BAD_REQUEST`. `POST /api/v1/credentials/{id}/test` checks a credential
  without exposing its secrets.
- From memory, unverified: the workflow update endpoint rejects read-only fields such as
  `id`, `active`, `tags` and timestamps. Strip them on push (T-WFC-04).
- Exports reference credentials by ID and name, not by secret value, but pinned data and
  hard-coded node values do get exported. Check pulls before committing.
- Secrets: `.env.local` is ansible-vault encrypted. There is no `ansible.cfg` here, so
  use `--vault-password-file collateral/vault-pass.sh` (a macOS dialog). Never decrypt
  or read it from Claude. The keys arrive as env vars, and checks report only set/not set.
- The shell is zsh, so `${!k}` indirection fails. Use `printenv "$k" >/dev/null`.

**Session continuity:** Next session is a cold start, so re-read CLAUDE.md before doing
anything. Sessions are never re-entered. End-of-session updates cover three layers: this
brief, `docs/session-state.md`, and `TODO.md`.
Full archaeology: `docs/session-state.md` — consult when prior-thread depth, decision
reasoning, or ruled-out paths are needed.
