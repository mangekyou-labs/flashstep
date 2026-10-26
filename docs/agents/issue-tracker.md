# Issue tracker: local Markdown in `.scratch/`

There is no GitHub issue tracker. Maps and tickets are files.

## Layout

```
.scratch/<effort>/
  map.md            # Destination, Notes, Decisions so far (one line per resolved ticket), Fog
  issues/NN-slug.md # one child ticket, numbered from 01
  research/         # findings a research ticket points to
  spec.md           # output of /to-spec, when the map has been converted
```

`.scratch/run-the-outreach/` is a plain task (`task.md`, `outreach-log.md`), not a map.

## Ticket header

```
# Title

Label: wayfinder:research | wayfinder:grilling | wayfinder:prototype | wayfinder:map
Type: research | grilling | prototype | task
Status: open | resolved | closed
Blocked by: NN, NN   (or `none`)
Assignee: MrSufferer (or `none`)

## Question
...
## Resolution
...
```

Existing tickets use both `resolved` and `closed` for finished work; write `resolved` in new ones.

## Operations

- **Frontier**: tickets in `issues/` with `Status: open`, `Assignee: none`, and every `Blocked by` ticket finished. Lowest number first. Read the map's Decisions so far before opening any ticket; open a ticket file only when you work it.
- **Claim**: set `Assignee: MrSufferer` and save before any work.
- **Resolve**: write the answer under `## Resolution`, set `Status: resolved`, then add a one-line gist plus link to the map's Decisions so far.
- **Edit headers with the Edit tool.** macOS `sed -i` needs `-i ''` and does not expand `\n`; a one-line header change is an Edit call.
- Quote shell separators (`echo '-----'`); zsh treats a bare `=====` as a command.
