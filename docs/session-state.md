# Session State — Archaeology

> Backward-looking detail: thread-by-thread work, decisions and reasoning, ruled-out
> paths, commits, memories banked. The forward-looking brief lives in CLAUDE.md ->
> Session State. Consult this file on demand when depth is needed.

## 2026-11-13 — Preflight of the n8n environment (CLI)

**Done**
- Read-only preflight. All checks are reproducible with curl and podman inspect:
  - Podman machine `n8n` running; `opencode`, `opencode-lab` stopped.
  - Container `n8n`, `docker.io/n8nio/n8n:2.47.7`, `127.0.0.1:5678->5678`.
  - `/healthz` 200, `/healthz/readiness` 200, `/api/v1/workflows` without a key: 401.
  - Mounts: `/home/node/.n8n` rw (n8n_data), `.n8n-files/inbox` ro, `.n8n-files/outbox` rw.
  - Container env names: no `NODES_EXCLUDE` and no `N8N_RESTRICT_FILE_ACCESS_TO`, so
    n8n 2.x defaults apply.
  - oMLX on host `localhost:8000/v1/models`: 200 with `OMLX_API_KEY`, 401 without. The
    one model is `Qwen3.5-9B-oQ4e-mtp`.
- Shell env: `OMLX_API_KEY` and `N8N_ENCRYPTION_KEY` set, `N8N_API_KEY` not set.
- `.env.local` confirmed ansible-vault encrypted (`$ANSIBLE_VAULT` header) and
  gitignored. It was not decrypted.

**Decisions / method**
- Operator instruction: the vault keys are env vars and must not be exposed to context.
  Checks report presence only. Secret headers go to curl on stdin (`curl -K -`) so they
  never appear in argv or output.
- The operator updates the vault themselves (`ansible-vault edit --vault-password-file
  collateral/vault-pass.sh .env.local`), sources it, and restarts Claude Code.

**Findings raised, not acted on**
- `.env.local.example` is podmanager's template copied verbatim. It doesn't fit this
  project (it lacks `N8N_API_KEY` and includes `N8N_ENCRYPTION_KEY`). A change was
  proposed, with no answer yet.
- The docs describe the key as read "from the file". The env-var model is what is
  actually in use.

**Ruled out**
- zsh: `${!k}` indirect expansion errors out. Use `printenv`.

**Commits:** none this session.

## 2026-11-13 — T-WFC-01: API key verified (CLI)

**Done**
- `N8N_API_KEY` set in the shell (presence only). Readiness 200.
- Authenticated `GET /api/v1/workflows`: HTTP 200. One workflow, `My workflow`
  (id `BUfTdWopbSCXMfMd`, inactive, `manualTrigger` → `httpRequest`). `nextCursor` null.
  The `X-N8N-API-KEY` header works on 2.47.7 as documented (closes that TODO §3 question).
- Key passing: `printf 'header = "X-N8N-API-KEY: %s"\n' "$N8N_API_KEY" | curl -K -`.
  `printf` is a zsh builtin, so the value never reaches a process argv.
- `.env.local.example` rewritten for this project: only `N8N_API_KEY`, vault commands
  use `--vault-password-file collateral/vault-pass.sh`. Operator-approved.
- Wording fixed in CLAUDE.md, TODO.md, requirements.md: scripts read the key from the
  environment, not from the file.

**Findings**
- Local File Trigger still unconfirmed. Container env (names only) has no
  `NODES_EXCLUDE`, so defaults apply. `/types/nodes.json` returns 401 with no UI session,
  so the API key can't read the node catalog. Asked the operator to check the UI node
  panel.

**Ruled out**
- `/types/nodes.json` as a node-availability check from the CLI (needs a session cookie).

**Commits:** the one made at the end of this thread (T-WFC-01).
