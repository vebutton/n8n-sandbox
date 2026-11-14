# n8n Sandbox — ToDo

> The single durable task register. Committed, so every line stays generic: people's
> names, hosts, internal product names, credentials and customer-tied dates live in
> `CLAUDE.local.md` and are referenced, never copied here. Build and resolution dates
> are fine.

## Rules
- **ID:** `T-<SLUG>-<nn>`. Permanent, never reused, never renumbered. Numbered per track.
- **Slugs** come from CLAUDE.md → Tracks, plus `PROJ` for project/repo plumbing that
  belongs to no track. A new track is added to CLAUDE.md first, by agreement, never
  invented here.
- **An item is work that finishes.** Anything that recurs, or would never close, is a
  Standing operation (section 4): no ID, no checkbox.
- **Track and deliverable are fixed at creation.** If the deliverable changes, close the
  item with a pointer and open a new one that references the old ID. Don't retitle.
- **New items** append at the end of their track. Propose each one with a proposed ID
  and wait for agreement.
- **Closed items** stay in place, ticked: `(resolved YYYY-MM-DD: outcome)`. Move them to
  Archive only when the resolution no longer informs current work.
- **Item detail is current state only:** what's left, what it waits on, priority,
  dependencies, pointers. What happened and when goes in `docs/session-state.md`.
- **Open questions live only here** (section 3). Requirements and design docs point to
  this section instead of keeping their own lists.
- **This is the only durable task list.** The in-session todo tool is scratch. At end of
  session, reconcile it into this file, and give every open or next-step line written to
  `docs/session-state.md` an ID or an Unscheduled line, or drop it deliberately.
- **Refer to items by ID everywhere** (CLAUDE.md, docs, commit messages), never by
  position ("pickup item 3"). A commit that does an item's work names its ID.

## 1. Items

### PROJ — Project and repo plumbing
- [ ] T-PROJ-01 Create the GitHub remote and push the first commit (visibility undecided)

### WFC — Track 1: Workflows as code
- [x] T-WFC-01 Create an n8n API key, store it in `.env.local` with a tracked `.env.local.example`, and verify an authenticated `GET /api/v1/workflows` (resolved 2026-11-13: GET returns 200 with the key passed to curl on stdin; template lists only `N8N_API_KEY`)
- [ ] T-WFC-02 Pull script: export every workflow from n8n into `workflows/<slug>.json`, normalised for clean diffs
- [ ] T-WFC-03 Commit the existing manual-trigger → HTTP-request workflow as the first example
- [ ] T-WFC-04 Push script: create or update an n8n workflow from a repo JSON file
- [ ] T-WFC-05 Round-trip check: author a small workflow in git, push it, run it in the UI, pull it back, and confirm a clean diff

### XSUM — Track 2: Transcript summary
- [x] T-XSUM-01 Script the container recreate with Mac inbox/outbox bind mounts, keeping `n8n_data`, the image tag and the `127.0.0.1:5678` binding (resolved 2026-11-13: done by podmanager, which owns the instance; inbox read-only and outbox read-write under `/home/node/.n8n-files`; see `docs/n8n-instance.md`)
- [x] T-XSUM-02 Make the local MLX model available as a credential for in-workflow model nodes (resolved 2026-11-13: the existing `n8n Assistant model` credential, oMLX at `host.containers.internal:8000/v1`, serves both the builder and workflow nodes)
- [ ] T-XSUM-03 Build the transcript summary workflow (inbox → local LLM → outbox), authored and pushed via WFC

## 2. Item detail

### WFC
- **T-WFC-02:** strip volatile fields (timestamps, `versionId`, and similar) so pulls
  diff cleanly. Choose a filename slug from the workflow name, and keep the n8n `id` in
  the file so push can tell an update from a create. Flag pinned data and hard-coded
  values before commit. Like every script here, it reads `$N8N_API_KEY` from the
  environment (the operator sources the vault) and passes the header to curl on stdin
  (`curl -K -`), never in argv.
- **T-WFC-04:** create a workflow that has no `id`, and update one that has an `id`. Send
  only the fields the API accepts on update (see the CLAUDE.md continuity reminder).
  Activation is a separate call.

### XSUM
- **T-XSUM-03:** trigger is a Schedule Trigger plus a read of the inbox folder, because
  the Local File Trigger node is not available on this instance (checked in the UI on
  2026-11-13). The inbox is read-only, so skip a transcript when its summary already
  exists in the outbox. Waits
  on T-WFC-04.

## 3. Open questions
- **Where should summaries go?** The outbox is the default and now exists. Email isn't
  available (no SMTP). A note app would mean an API reached over the internet.
  → T-XSUM-03
- **Can a small local model drive n8n's AI workflow builder at all?** Ask at the event.
  Accepted as event research, with no item.
- **What MCP options exist for Claude to drive n8n directly?** n8n as an MCP server, or
  community MCP servers. Ask at the event, since these change fast. If promising, it goes
  to Unscheduled.
- **Does the event provide a lab sandbox?** The local instance is ready either way, so
  this only decides where to experiment on the day. Accepted as event research.

## 4. Standing operations
Recurring work: no IDs, no checkboxes, tracked by last-run date.

| Operation | Cadence / trigger | Last run | Notes |
|---|---|---|---|
| Pull workflows into git | After any edit in the n8n UI | Never | Needs T-WFC-02 |

## 5. Unscheduled
Ideas that came up but aren't committed work. No ID until promoted into a track.
- Wire the AI Agent node to the local LLM. It is a node, not a separate container.
- Let Claude drive n8n over MCP instead of the REST API, depending on what the event shows.
- Try n8n's self-hosted AI starter kit (extra containers).
- Custom n8n nodes in TypeScript.
- Ask podmanager to set up the code sandbox service, if the Assistant or Agents need to
  run code or handle files.

## 6. Archive
Closed items whose resolution no longer informs current work.
