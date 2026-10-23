---
name: grok-bot-coordination
description: Coordinate Luke's CLI coding agents (Codex, Claude Code, Cursor CLI, OpenCode, including sessions inside T3 Code) with Grok Bot. Use when handing work off, reaching Luke, sharing a repo or SSH access with other agents, or deciding whether Grok Bot should own accounts, messages, other bots, or routines.
author: Luke
---

# Working with Grok Bot

Grok Bot is Luke Williams's primary personal assistant and the coordinator of his bots. It is a Cursor-hosted agent on its own Linux machine (the box). It routes work to teammate bots, including Labby (home lab), Content, Workout Coach, Truffles (Alanah), Update Captain, and Audition Scout.

You are a CLI coding agent on one of Luke's computers. The two of you do not share a filesystem, a terminal, a T3 Code thread, or memory. Send anything the other side needs: files, command output, and decisions.

## What you own

Do the local coding task. Leave cross-system coordination to Grok Bot: accounts, other bots, routines and schedules, and outbound messages.

Match the norms Grok Bot already follows:

- Sign in through Proton Pass. Use `proton-pass-cli`. Keep secrets out of the repo, the transcript, and this skill.
- External mail and messages go out only after Luke approves them. Grok Bot waits for Luke to press send. Wait for the same approval.
- Luke deletes accounts himself.
- `direct-action-preferences` covers local technical work. It does not extend to outbound messages, account changes, or driving other bots.

## Git

Grok Bot starts Cursor cloud agents for repository work and opens pull requests on GitHub under `luckycold`. Pull before you treat the local checkout as current. Write on a branch no cloud agent or other local thread is already using. When the task includes publishing, push and open or update the pull request, then include the link in the handoff.

## Reaching Luke or Grok Bot

1. Tell Luke in this session when he is here.
2. For a phone push, use `ntfy-ops`. Take the topic and credentials from private context through that skill. Leave them out of this skill and out of chat.
3. Leave email to Luke. Grok Bot's inbox accepts mail only from Luke's own address, so a CLI session must not depend on emailing it. The address stays in private context.

## SSH

You may use Luke's main key. The first time you access a system, also install this agent's own key. Tell Grok Bot which host changed and which public key you added. Keep private key material out of chat and out of the repo.

## T3 Code

[T3 Code](https://t3.codes) ([pingdotgg/t3code](https://github.com/pingdotgg/t3code)) is a control surface. Its server on this machine (an environment) drives the provider CLIs installed here: Codex, Claude Code, Cursor (`agent` / `cursor-agent`), Grok Build, and OpenCode, plus any other provider enabled on this machine. Antigravity is signed in from T3's provider settings and does not use a CLI. Desktop, web, and phone clients talk to that server. They do not move the session onto Grok Bot's machine.

Checked against `main` docs on 2026-10-23:

- The `$` skill menu lists skills enabled for the selected provider ([composer](https://github.com/pingdotgg/t3code/blob/main/docs/user/composer.md)). Claude reads that config directory's `skills` folder and the project's `.claude/skills`; the config-directory copy wins ([Claude provider](https://github.com/pingdotgg/t3code/blob/main/docs/user/providers-claude.md)). A worktree is a different directory, so confirm this skill is actually in context. After adding or changing skills, run **Restart agent session** from the command palette. The conversation continues.
- A thread is durable history on that T3 server. Settling it keeps the conversation. Grok Bot still cannot read it. Put facts that must outlive this machine in a repo file or in the handoff below. A thread with no project writes under the T3 data directory's `scratch` folder; deleting the thread leaves that folder ([threads](https://github.com/pingdotgg/t3code/blob/main/docs/user/thread-sidebar.md)).
- **New worktree** gives the thread its own branch and directory. **New thread in this worktree** shares the checkout. T3 refuses a worktree file-restore while another thread uses that directory. Prefer a new worktree when two threads will edit. New worktrees go in the T3 home `worktrees` folder unless Storage settings move them. Automatic branch names default to a `t3/` prefix ([project settings](https://github.com/pingdotgg/t3code/blob/main/docs/user/project-settings.md)).

Always-on TrueNAS hosting for T3 Connect stays in `infrastructure-hygiene`. This skill is the coordination layer.

## Handoff

Send Grok Bot a short note:

- What changed, in a few sentences.
- Pull request links and branch names.
- Open questions for Luke or another bot.
- Anything that should happen again. Grok Bot can turn a repeat into a routine.

## Self-maintenance

This is a Luke-authored personal skill. After using it, update this package when a verified reusable correction or repeatable workflow would improve future runs. Follow `personal-skill-maintenance` for review, the public-safety check, and publishing.
