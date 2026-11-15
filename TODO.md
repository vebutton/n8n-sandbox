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
- [x] T-PROJ-01 Create the GitHub remote and push the first commit (visibility undecided) (resolved 2026-11-15: public repo, `origin` on GitHub; the first commit was pushed 2026-11-14, the register was just not updated)

### WFC — Track 1: Workflows as code
- [x] T-WFC-01 Create an n8n API key, store it in `.env.local` with a tracked `.env.local.example`, and verify an authenticated `GET /api/v1/workflows` (resolved 2026-11-13: GET returns 200 with the key passed to curl on stdin; template lists only `N8N_API_KEY`)
- [x] T-WFC-02 Pull script: export every workflow from n8n into `workflows/<slug>.json`, normalised for clean diffs (resolved 2026-11-15: `scripts/pull.sh`; two consecutive pulls diff clean)
- [x] T-WFC-03 Commit the existing manual-trigger → HTTP-request workflow as the first example (resolved 2026-11-15: `workflows/my-workflow.json`, committed with the chat-test and transcript-summary workflows)
- [x] T-WFC-04 Push script: create or update an n8n workflow from a repo JSON file (resolved 2026-11-15: `scripts/push.sh`; create, update, conflict guard and unknown-id cases tested live; the published-workflow draft path is untested)
- [x] T-WFC-05 Round-trip check: author a small workflow in git, push it, run it in the UI, pull it back, and confirm a clean diff (resolved 2026-11-15: `workflows/round-trip-check.json` created by push, run in the UI (execution 11, success), pulled back with a clean diff)

### XSUM — Track 2: Transcript summary
- [x] T-XSUM-01 Script the container recreate with Mac inbox/outbox bind mounts, keeping `n8n_data`, the image tag and the `127.0.0.1:5678` binding (resolved 2026-11-13: done by podmanager, which owns the instance; inbox read-only and outbox read-write under `/home/node/.n8n-files`; see `docs/n8n-instance.md`)
- [x] T-XSUM-02 Make the local MLX model available as a credential for in-workflow model nodes (resolved 2026-11-13: the existing `n8n Assistant model` credential, oMLX at `host.containers.internal:8000/v1`, serves both the builder and workflow nodes; corrected 2026-11-15: no credential by that name exists, and workflow nodes use `oMLX local`, created in the UI)
- [ ] T-XSUM-03 Build the transcript summary workflow (inbox → local LLM → outbox), authored and pushed via WFC

### PRICE — Track 3: Price watch
- [ ] T-PRICE-01 Choose the price source and the alert channel for the price watch
- [ ] T-PRICE-02 Build the price-watch workflow (schedule → price lookup → threshold → alert and log), authored and pushed via WFC

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
  exists in the outbox. Start from `workflows/transcript-summary-inbox-to-outbox.json`
  (manual trigger, works end to end) and push changes with `scripts/push.sh`.
  **On hold (2026-11-15):** waits on the operator's real summary prompt, which they use
  in their macalla project. Get it from them before starting.

### PRICE
- **Deadline:** Black Friday is 2026-11-27. Priority is above T-XSUM-03 until then.
- **T-PRICE-01:** decide three things with the operator:
  - **Price source.** Keepa API (paid, reliable; price from memory around €20/month),
    Amazon Product Advertising API (needs an Associates account with sales), or scraping
    product pages (against Amazon's terms and blocked by CAPTCHAs, so expect it to break).
  - **Alert channel.** Gmail, Slack or Telegram via their APIs (outbound works; only SMTP
    is unavailable), or a file in the outbox.
  - **Uptime.** Alerts only fire while the `n8n` Podman machine runs, so it has to stay
    up through the sale week.
- **T-PRICE-02:** waits on T-PRICE-01. Inputs are a product list (ASIN and target price).
  Log each check so price history is visible.

## 3. Open questions
- **Where should summaries go?** The outbox is the default and now exists. Email isn't
  available (no SMTP). A note app would mean an API reached over the internet.
  → T-XSUM-03
- **Can a small local model drive n8n's AI workflow builder at all?** The event didn't
  cover it (presentation only). Partly answered 2026-11-15: the Assistant
  accepts oMLX but warns that small models often build workflows that don't run, and it
  also needs a code sandbox (see Unscheduled).
- **What MCP options exist for Claude to drive n8n directly?** n8n as an MCP server, or
  community MCP servers. The event didn't cover it, so research it directly; these change
  fast. If promising, it goes to Unscheduled.

## 4. Standing operations
Recurring work: no IDs, no checkboxes, tracked by last-run date.

| Operation | Cadence / trigger | Last run | Notes |
|---|---|---|---|
| Pull workflows into git | After any edit in the n8n UI | 2026-11-15 | `scripts/pull.sh`, then commit and push; review its WARN and stale lines first. This is the workflow backup of record (handoff 2026-11-15). Archived workflows are skipped |

## 5. Unscheduled
Ideas that came up but aren't committed work. No ID until promoted into a track.
- Let Claude drive n8n over MCP instead of the REST API, depending on what the event shows.
- Try n8n's self-hosted AI starter kit (extra containers).
- Custom n8n nodes in TypeScript.
- Ask podmanager to set up the code sandbox service, if the Assistant or Agents need to
  run code or handle files. The n8n Assistant requires it (it runs the Assistant's code,
  not the model). The options are K8s + Sysbox, Daytona (third-party hosted, data leaves
  the host), or the bundled Compose stack (privileged Docker-in-Docker, dev/test only,
  untested on Podman). Source: n8n docs, "Set up n8n Assistant". Low value while the
  model is small, since n8n warns that small models often build workflows that don't run.
- **Demo environment setup before a scheduled demo.** Google Calendar trigger (polls) →
  find demo events → SSH or HTTP calls that run the setup (Ansible, cluster APIs). Needs a
  calendar credential and access from the container to the lab. The Execute Command node
  may be disabled by default in 2.x (from memory), like the Local File Trigger.
- **CRM brief before a customer call.** Calendar trigger → Salesforce node (account,
  opportunities, recent activity) → local LLM writes a brief → outbox or Slack. Needs a
  Salesforce connected app (admin approval). The local model keeps CRM data on the host.
- **Conference "bump" to a contact list.** n8n can't be reached from a phone, so send the
  contact by email: IMAP trigger polls the inbox → LLM pulls out name, company and role →
  Google Sheet or file. Card or badge photos would need a vision model (oMLX support
  unknown).

## 6. Archive
Closed items whose resolution no longer informs current work.
