# About Templates

Blank schemas that `/about-setup` fills in when building a new operator profile under `.opencode/about/`.

They mirror the structure and headings of a populated profile exactly, but carry `<...>` placeholder tokens and guidance hints instead of anything personal. Once instantiated they become the operator profile the crew actually reads.

## The Files

| File | What it holds |
|------|---------------|
| `profile/PROFILE.md` | Identity, background, expertise, current work, goals, values, and notes for the crew |
| `preferences/PREFERENCES.md` | Communication style, planning and approval gates, permissions, hard gates, environment defaults |
| `preferences/AVAILABILITY.md` | Working hours, timezone coordination, update cadence, out-of-hours handling, who covers urgent work |
| `channels/CHANNELS.md` | Channels in use, tone for each, approval model, access levels, platform-specific notes |
| `tools/README.md` | Personal tools, scripts, and utilities, with a suggested layout |
| `config/README.md` | Personal config files and dotfiles, with a suggested layout |

## How They Get Used

`/about-setup` copies these into `.opencode/about/`, swapping the placeholders for the operator's answers. What comes out is the source of truth for how the crew communicates, what it asks permission for, and when it expects the operator to be around.

This README is metadata about the templates. It is never copied into the operator's folder — only the six files above are.
