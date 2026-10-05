---
description: Create and interactively populate the operator about/ profile
agent: bishop
---

> **An interview, not a form.** This command walks the operator through building out the `about/` directory — who they are, how they like to work, when they're around, and how they want to be reached. The crew reads it to adapt how it behaves.

> **Templates**: `.opencode/templates/about/` holds the blank schema files this instantiates. `.opencode/templates/about/README.md` is metadata about the templates — it never gets copied into the operator's folder. Only the 6 operator files do.

---

## The Short Version

`/about-setup` builds and fills the operator profile at `.opencode/about/`, or wherever you point it. It works one section at a time: ask the questions for that area, then write the file from the template with the answers in place.

**Nothing is destroyed.** Where a file already exists, you ask what to do with it before touching anything. Overwrite is flagged as destructive and needs an explicit yes.

---

## Running It

### Step 1 — Work Out Where It's Going

1. Default target is `.opencode/about/`.
2. `$ARGUMENTS` overrides it — `/about-setup /custom/path`.
3. Create the target and its subdirectories (`profile/`, `preferences/`, `channels/`, `tools/`, `config/`) if they aren't there.
4. Check whether anything is already populated:
   - For each existing file, ask: **(K)eep what's there, (U)pdate through the interview, or (O)verwrite [destructive]?**
   - Overwrite is marked destructive and needs explicit confirmation first.
   - Note the answer per file.
   - "Keep" files skip the interview. Only "update" and "overwrite" go through it.
5. Empty directory? Straight to Step 2.

### Step 2 — Profile

Cover identity, background, expertise, current work, goals, values, and how they want agents to behave.

**Ask about:**

1. **Identity** — name, role or title, where they are (city/region, country), timezone (e.g. UTC+2).
   - Offer a sensible default when they're unsure.
   - Something like: *"What's your full name, title, where are you based, and what timezone?"*

2. **Background** — a paragraph or two: career so far, years in, the technologies and domains they know.
   - *"Tell me about your background — how long you've been doing this, the moves that mattered, the areas you've worked in."*

3. **Expertise** — main technical strengths. Frontend, APIs, AI integration, DevOps, full-stack.
   - *"What are your main technical strengths?"*
   - *"How do you approach frontend — a framework, or vanilla?"*
   - *"Any AI or ML integration experience, or is that not your area?"*

4. **Current Work** — a paragraph on active projects and what they're responsible for.
   - *"What are you working on right now, and what's your role in it?"*

5. **Goals** — near term (3–6 months) and longer (1–2 years).
   - *"What are you aiming at over the next few months? And further out?"*

6. **Values** — up to four that matter, each with a line of explanation.
   - *"What matters most to you in how work gets done?"*

7. **Notes For The Crew** — communication preferences, technical level, how much explanation they want, risk and transparency expectations, how they like decisions made.
   - *"Anything you want the crew to know about how to talk to you? Skip the beginner explanations, lead with risks, that sort of thing."*

**Then write it.** Fill `profile/PROFILE.md` from the template and show:

```
✓ Profile written to [target]/profile/PROFILE.md
  - Name: <name>
  - Role: <role>
  - Timezone: <timezone>
```

On to Step 3.

### Step 3 — Preferences

Communication style, planning and approval gates, permissions, hard gates, environment defaults.

**Ask about:**

1. **Communication Style** — how responses should be shaped. Tight or thorough? How should options be laid out?
   - *"How do you want the crew to communicate — straight to the point, or with the trade-offs spelled out?"*
   - *"When you're being given options, how should they be presented?"*

2. **Planning And Approval** — does every mission need a plan? Does the plan need signing off? Does the code? What about questions mid-mission?
   - *"Should every mission open with a plan? Does the code need approval too, or just the plan?"*

3. **Permissions** — how should the crew ask? Once a session, or as it goes?
   - *"How should file and folder permissions be requested — all up front, or as they come up?"*

4. **Hard Gates** — what never happens without an explicit yes. Pushing code, destructive changes, production edits.
   - *"What absolutely requires your say-so first?"*

5. **Environment** — what's the default: dev, staging, or production?
   - *"What's your default environment?"*

**Then write it.** Fill `preferences/PREFERENCES.md` and show:

```
✓ Preferences written to [target]/preferences/PREFERENCES.md
  - Communication: <brief summary>
  - Approval model: <plan/code requirement>
  - Hard gates: <list of 2–3 gates>
```

On to Step 4.

### Step 4 — Availability

Working hours, timezone coordination, how often they want updates, out-of-hours, and who covers urgent work.

**Ask about:**

1. **Working Hours** — days, hours, timezone. Whether their personal timezone differs from the one the company coordinates on. Where the team sits.
   - *"What days and hours do you work, and in what timezone?"*
   - *"Does the company coordinate on a different timezone from yours?"*

2. **Talking About Time** — how should times be expressed back to them?
   - *"Should the crew always use your local time, the company standard, or read the context?"*

3. **Updates** — how often, for short missions and long ones. And whether a blocker interrupts.
   - *"On a short mission, do you want a summary at the end or updates as it goes?"*
   - *"On a long one, how often — per milestone, daily, at the end?"*
   - *"If something blocks, interrupt you straight away or hold it?"*

4. **Out Of Hours** — work arriving outside their hours: acknowledge and hold, or escalate?
   - *"If something lands outside your hours, should it be acknowledged and held, or passed to someone else?"*

5. **Urgent Cover** — who picks up urgent work when they're not there, and how context gets handed over.
   - *"Is there someone who takes urgent work when you're away? Name, role, how to reach them."*

**Then write it.** Fill `preferences/AVAILABILITY.md` and show:

```
✓ Availability written to [target]/preferences/AVAILABILITY.md
  - Working hours: <days/times/timezone>
  - Notification cadence: <short/long mission summary>
  - Out-of-hours: <deferred/escalated>
```

On to Step 5.

### Step 5 — Channels

Which channels they use, the tone for each, the approval model, access levels, and anything channel-specific.

**Ask about:**

1. **Which Channels** — team chat, email, issue or task tracker, video calls, shared calendar, anything else. For each: what it's for, whether it's client-facing, and what access the crew needs.
   - *"Which channels do you actually use?"*
   - *"For each one — what's it for, and do agents need access?"*

2. **Tone Per Channel** — how the register should shift between them.
   - *"How should tone differ between team chat, formal email, and your issue tracker?"*

3. **Approval Model** — does everything drafted need signing off, or is some of it fine to send?
   - *"Does everything need your approval before it goes, or can some of it go automatically — internal chat, say, but not client email?"*

4. **Tool Access** — for any channel or tool where agents need access, whether read-only or read-write, and what specifically is off limits.
   - *"For any tools where agents need access, what should be read-only versus read-write? What should they never touch?"*

5. **Anything Else** — client-facing considerations, platform quirks, where context ends and action begins.
   - *"Any other channel-specific things worth knowing?"*

**Then write it.** Fill `channels/CHANNELS.md` and show:

```
✓ Channels written to [target]/channels/CHANNELS.md
  - Channels: <count and list>
  - Default approval: <all require approval / auto-approval per channel>
  - Tool access: <read-only / read-write per tool>
```

On to Step 6.

### Step 6 — Tools (Optional)

Personal tools, scripts, utilities. Offer to skip it.

*"Any personal tools or scripts you use regularly that the crew should know about — shell scripts, snippets, prompts? Happy to skip this and leave it as a stub."*

- **Skip** — leave `tools/README.md` as the stub. Output: `⊘ tools/README.md left as template stub — add entries later as needed.`
- **Fill it** — collect name, location, and purpose for each, and write them into the table.

On to Step 7.

### Step 7 — Config (Optional)

Personal config files and dotfiles. Offer to skip it.

*"Any config files, dotfiles, or editor settings you'd want referenced — .gitconfig, VS Code: settings, shell aliases? We can skip this too."*

- **Skip** — leave `config/README.md` as the stub. Output: `⊘ config/README.md left as template stub — add entries later as needed.`
- **Fill it** — collect name, location, and purpose for each, and write them into the table.

On to Step 8.

### Step 8 — Wrap Up

Summarise what actually happened, based on the choices made during the run. `✓` for populated, `⊘` for left as a stub:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OPERATOR PROFILE COMPLETE

Target directory: [target path]

Created/Updated:
  ✓ profile/PROFILE.md
  ✓ preferences/PREFERENCES.md
  ✓ preferences/AVAILABILITY.md
  ✓ channels/CHANNELS.md
  [✓ or ⊘] tools/README.md [populated / template stub]
  [✓ or ⊘] config/README.md [populated / template stub]

Next steps:
  - The about/ directory is now wired into agent context.
  - The crew will use these settings to shape how it works with you.
  - Refresh any section anytime with /about-setup — it offers to update.
  - View your profile: cat .opencode/about/profile/PROFILE.md

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Placeholders

- Every `<...>` token in the template gets replaced with a real answer.
- Where the operator skips a field or isn't sure, leave the placeholder and its guidance text in place so it's obvious the field is still open.
- Never invent an answer. An empty field is honest; a guessed one isn't.

---

## Not Destroying Things

- Before overwriting any existing file, mark it **[DESTRUCTIVE]** and ask.
- *"[DESTRUCTIVE] Overwriting preferences/PREFERENCES.md. Are you sure? (yes/no)"*
- Proceed only on an explicit confirmation.

---

## Keep It Human

Ask in natural language, grouped by topic. Offer defaults where someone is uncertain. Confirm each section before moving on. This should feel like a conversation, not a form someone has to fill in.
