# n8n Sandbox — Requirements

A disposable sandbox for learning n8n. These requirements stay deliberately light. Tasks
and open questions live in [TODO.md](../TODO.md), not here. The instance itself (what's
running, addresses, reach, rules) is described in [n8n-instance.md](n8n-instance.md).

## Shared constraints
- **Throwaway.** Nothing here is production. Anything worth keeping graduates to a new
  project.
- **Use the instance, don't run it.** This project never starts, stops, recreates or
  reconfigures the n8n machine or container. Changes go to the operator as requests.
- **Git is the durable copy.** Workflow data lives in a VM volume on a learning
  instance, so anything worth keeping is pulled into `workflows/`.
- **No Claude inside n8n.** There is no Anthropic API key, and a subscription can't be
  used from n8n. In-workflow AI uses the existing `n8n Assistant model` credential
  (local oMLX). Keep prompts small, because the model is shared.
- **Secrets** go in `.env.local` only (gitignored, ansible-vault encrypted). A tracked
  `.env.local.example` shows the variable names. Scripts read them from the environment.
- **Tooling:** Bash + `curl` + `jq`.

## Track 1 — Workflows as code (WFC)

**Objective:** Claude Code manages n8n workflows from the Mac over the REST API, with the
workflow JSON version-controlled in this repo.

- **API:** `http://localhost:5678/api/v1`, header `X-N8N-API-KEY: $N8N_API_KEY`.
  Swagger is at `/api/v1/docs/`. Every script checks `/healthz/readiness` first and exits
  with a clear message if n8n is down.
- **Layout:** `workflows/<slug>.json`, one workflow per file, with the slug derived from
  the workflow name. Scripts go in `scripts/`.
- **Pull** writes every workflow from n8n to `workflows/`. Output is normalised: volatile
  fields are stripped and keys sorted, so a pull with no UI changes gives an empty
  `git diff`. Exports keep credential references (ID and name), never secret values.
  Pinned data and hard-coded node values are flagged for review before commit.
- **Push** takes one or more files. A file with an `id` updates that workflow. A file
  without one creates a new workflow and writes the returned `id` back into the file.
  Push never deletes and never activates. Activation is explicit.
- **Both directions are valid.** Workflows can be authored in git and pushed, or built
  in the UI and pulled.
- **Done when:** T-WFC-05's round trip passes.

## Track 2 — Transcript summary (XSUM)

**Objective:** a transcript file in the inbox is summarised by the local LLM through
n8n, and the summary is written to the outbox.

- **I/O:** read from `/home/node/.n8n-files/inbox`, which is read-only. Write to
  `/home/node/.n8n-files/outbox`. The default output is a Markdown file that reuses the
  transcript's base name.
- **Idempotence:** the workflow can't move or delete inbox files, so it must not
  re-summarise a file it has already done. The simplest check is to skip a file when its
  summary already exists in the outbox.
- **Trigger choice:** confirm whether n8n 2.x ships the Local File Trigger disabled. If
  it does, poll on a schedule rather than ask for an instance change.
- **Model:** the `n8n Assistant model` credential, through an OpenAI-compatible chat
  model node. Keep the prompt small, and handle a transcript too long for the model's
  context by truncating or chunking it.
- **Authoring:** the workflow is built and pushed through Track 1 tooling.
- **Done when:** a transcript in the inbox produces a summary in the outbox without
  manual steps.

## External references
- `http://localhost:5678/api/v1/docs/`: the instance's own Swagger, authoritative for
  this version.
- n8n's MCP options and AI-node details are event follow-ups (TODO.md §3).
