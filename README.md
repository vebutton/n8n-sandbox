# n8n Sandbox

A disposable sandbox for learning [n8n](https://n8n.io) on a self-hosted local instance.
Claude Code manages the workflows from outside the container through n8n's REST API, and
the workflow JSON is version-controlled here. The first goal is a workflows-as-code loop:
pull workflows from n8n into git and push them back. After that comes a small real
workflow, where a transcript dropped into an inbox folder is summarised by a local LLM.

This is a personal learning project, not a maintained tool.

## Pointers
- [docs/requirements.md](docs/requirements.md): what each track has to do
- [docs/n8n-instance.md](docs/n8n-instance.md): the n8n instance this project uses, and
  its rules
- [TODO.md](TODO.md): the task register and open questions
- [CLAUDE.md](CLAUDE.md): project context for Claude Code sessions
