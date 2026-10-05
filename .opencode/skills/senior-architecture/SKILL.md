---
name: senior-architecture
description: "Advanced development skill for complex missions. Covers architecture, system design, refactoring strategy, dependency management, technical debt assessment, edge-case thinking, trade-off analysis, and guidance when a mission requires deeper judgment."
---

# Architecture And Judgement

## What This Is For

Complex or high-impact work. It's about seeing past the immediate change to the system around it — the trade-offs, the risks, and what the codebase will be like to live in afterwards.

## What To Assess

Looking at a mission or a design, work through:

1. Separation of concerns.
2. Coupling and cohesion.
3. Room to extend without piling on complexity.
4. Whether it can be tested in isolation.
5. Operational risk, and what a rollback would cost.
6. Fit with the architecture and conventions already there.

## Thinking Architecturally

- Favour designs that are easy to follow, easy to test, and easy to change.
- Don't overengineer — but don't underdesign something genuinely complex either.
- Notice when a small implementation change carries a large architectural consequence.
- Think in boundaries, interfaces, data flow, lifecycle, and ownership.
- Push back on assumptions that mortgage the future for today's convenience.
- Be willing to change the shape of the solution when the problem turns out bigger than the brief.

## What You Own

- Get clear on the real problem before picking a solution.
- Know whether you're building a quick fix or something durable, and say which.
- Decide when to refactor, when to extend, and when to leave well alone.
- Balance simplicity, flexibility, performance, safety, and getting it shipped.
- Recognise when a new abstraction earns its keep — and when it doesn't.
- Notice when the right answer is a smaller scope, not a bigger one.

## Refactoring With Intent

Refactor deliberately, not out of habit.

- Extract Method when functions run long.
- Extract Class to gather cohesive behaviour.
- Replace Conditional with Polymorphism once branching turns structural.
- Introduce Parameter Object when the same inputs keep travelling together.
- Split read and write paths when the model gets hard to hold in your head.
- Move logic toward whichever boundary actually owns it.

## Dependencies And Boundaries

- Keep coupling between modules low.
- Prefer a stable interface to one module reaching into another.
- Keep side effects visible.
- Be deliberate about where dependencies get built and how they're handed around.
- Don't let one component accumulate everyone else's concerns.
- Weigh a third-party dependency before you take on the cost of it.
- Ask what it brings with it — maintenance, security exposure, upgrade pain.

## Recording Technical Debt

For each item, write down:

- Impact.
- Risk.
- Effort.
- Priority.
- What to do: fix now, schedule it, or accept it deliberately.

## When It's Architect-Level

Treat the mission as yours when it touches:

- Public API changes.
- Data model changes.
- Major refactors.
- Multi-step migrations.
- Meaningful performance trade-offs.
- Security-sensitive flows.
- Concerns cutting across several modules.
- Requirements ambiguous enough to change how the system behaves.
- A solution that's technically fine but strategically wrong for this codebase.

## Questions Worth Asking

- What breaks if this changes?
- What gets easier later? What gets harder?
- Does this sit naturally in the existing architecture?
- Is the abstraction paying for itself?
- Can this safely be changed again in six months?
- Are we fixing the root cause or covering it?
- Is this the simplest thing that will still hold up as the system grows?

## Done Means

- The approach is justified, not just chosen.
- The trade-offs are on the table.
- The risks are named.
- The design is maintainable.
- The change fits the wider system.
- Whoever picks it up next has enough context to support it.
- The next change won't immediately knock it over.
