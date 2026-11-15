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

## 2026-11-13 — Local File Trigger check (CLI)

- The operator searched the UI node panel: "Local File Trigger" does not appear. It is
  excluded by n8n 2.x defaults (no `NODES_EXCLUDE` override in the container env).
- Decision: T-XSUM-03 uses a Schedule Trigger plus a read of the inbox, skipping files
  whose summary already exists in the outbox. Asking podmanager to enable the node was
  not pursued: the poll is enough for a sandbox.

**Commits:** `faab87f` (T-WFC-01), then the end-of-session commit recording this finding.
Session ended here. Next session starts at T-WFC-02.

## 2026-11-15 — Local-LLM workflows, credential cleanup, Track 1 complete (CLI)

**Done**
- Reviewed the operator's `My workflow 2`: the "Chat" node was Respond to Chat
  (`@n8n/n8n-nodes-langchain.chat`), not a trigger (executions 5–7 failed with "Workflow
  must be started from a chat trigger node"). The Agent's prompt was fixed text in the
  user-message field, and Convert to File read `json` instead of `output`.
- Created via the API: `Chat test (local LLM)` (Chat Trigger → AI Agent, prompt
  `{{ $json.chatInput }}`, system message in Options) and `Transcript summary (inbox to
  outbox)` (manual → read `inbox/*.txt` → Extract from File → Basic LLM Chain → Convert
  to File → write `outbox/<name>.summary.md`). Both ran. The summary of a 7-line sample
  was accurate. Node versions chosen from memory (chatTrigger 1.1, chainLlm 1.5,
  readWriteFile 1, extractFromFile 1) all load on 2.47.7. The binary `fileName`
  expression works. Qwen emitted no `<think>` tags.
- Credentials: two `openAiApi` credentials existed, both made in the UI on 2026-11-14.
  `POST /credentials/{id}/test`: `OpenAI account` → `ERR_BAD_REQUEST` (axios 4xx),
  `OpenAI account 2` → OK. The operator found the broken one lacked `http://` in the
  Base URL and deleted it. The working one was renamed `oMLX local` via
  `PATCH /credentials/{id}`.
- `n8n Assistant model` is not a workflow credential. It is the model for n8n's
  built-in Assistant (`instance-ai` module), set in the UI and pointed at oMLX. No
  `N8N_INSTANCE_AI_*` env vars are on the container (names only). Per n8n docs ("Set up
  n8n Assistant"), the Assistant needs a code sandbox: K8s + Sysbox, Daytona, or a
  bundled privileged Compose stack (dev/test). Recommended skipping it: small model,
  and Claude Code already fills the role. Recorded under TODO Unscheduled.
- T-WFC-02: `scripts/pull.sh`. Shared code: `scripts/lib/n8n.sh` (API call, key on
  stdin) and `scripts/lib/normalize.jq` (stored form, request body, warnings).
- T-WFC-03: committed `My workflow` plus the two new workflows. `My workflow 2` was
  deleted at the operator's request (archive, then `DELETE`).
- T-WFC-04: `scripts/push.sh`, with a conflict guard against the file's last commit,
  draft-by-default for published workflows (`--publish`), and post-push verification.
  First real use refreshed the cached credential name in both AI workflows.
- T-WFC-05: `Round-trip check` authored in git, pushed, run in the UI (execution 11),
  pulled back with a clean diff. The editor added nothing on open or run.
- T-PROJ-01: the public remote had existed since 2026-11-14, and the register was stale.
  Closed it and pushed. Local and `origin/main` are in sync.

**Decisions / reasoning**
- Basic LLM Chain over AI Agent for summarising: the Agent's tool-calling scaffolding
  is a poor fit for a 9B model.
- Credential name `oMLX local`, not "OMLX Qwen": the model is picked per node, not in
  the credential.
- Push refuses when n8n differs from `HEAD:<file>`, because pull strips `versionId`,
  so there is no optimistic lock to use. Verified by a forced conflict.
- Pull skips archived workflows, reports stale files (never deletes), and moves renamed
  workflows by id.

**Verified facts (from the instance's `/api/v1/openapi.yml`)**
- Writable workflow fields: name, nodes, connections, settings, nodeGroups, staticData,
  pinData, description. `settings` and nodes are `additionalProperties: false`.
- `PUT /workflows/{id}` re-publishes a published workflow unless `publishIfActive=false`.
- Archive is a soft delete: it unpublishes and keeps executions. `DELETE` removes the
  workflow and its executions for good.
- `GET /credentials/{id}` returns no secret data. `/credentials/{id}/test` and
  `/dependencies` exist.

**Ruled out / not done**
- `/types/nodes.json` for node versions: 401 without a UI session, again.
- Draft-vs-`--publish` push path: untested, since nothing is published.
- T-XSUM-03: held by the operator, who wants their real prompt from another project.

**Corrections made**
- I claimed T-PROJ-01 was open from the register without checking `git remote`. The
  operator corrected it. Lesson recorded in the CLAUDE.md continuity reminders.
- "Save the workflow in the UI": there is no Save button in 2.x (operator).

**Commits:** `ceb45e1`, `6071905`, `fafe935`, `07b045a`, `427e172`, `2b82f51`,
`9d9bdfd`, plus this end-of-session commit. All pushed.
Session ended here. Next session: get the operator's prompt, then T-XSUM-03.
