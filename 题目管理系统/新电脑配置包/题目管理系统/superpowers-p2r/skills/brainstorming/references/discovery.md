# Phase 1: Discovery - Detailed Guidance

## Goal

Understand what's being built by exploring the current project state and clarifying requirements.

## Primary Agent Actions

### 1. Explore Codebase First

**Before asking any questions**, build context from existing code:

- Find relevant files matching patterns (e.g., `**/*.ts`, `src/**/*.py`)
- Search for patterns and similar implementations
- Read files to understand existing code structure and conventions
- Check for architectural patterns, naming conventions, error handling styles

### 2. Review Project Context

Understand the project's established patterns:

- Check `docs/` directory for existing documentation
- Read `README.md` for project overview and setup
- Review `CLAUDE.md` for development guidelines and constraints
- Run `git log --oneline -20` to see recent commits and development focus
- Look for similar features or components already implemented

### 3. Identify Gaps

Based on your exploration, identify what's unclear:

- Which requirements are ambiguous or missing?
- What constraints are not documented in the codebase?
- What success criteria need clarification?
- What non-functional requirements (performance, security, scalability) need discussion?

### 4. Resolve Gaps Autonomously

Default behavior is autonomous decision-making based on prompt + codebase context:

**CRITICAL: Auto First**:

- Infer defaults using existing architecture, project constraints, and least-surprise principles
- Record assumptions in design docs and/or `questions.md` for traceability
- Continue execution without pausing for manual selection

**When asking is allowed (rare)**:

- Legal/compliance/contractual choices with no safe default
- Irreversible business policy decisions not specified in prompt
- Hard external dependency constraints unknown to codebase and docs

### 5. Build Mental Model

Synthesize exploration and user answers:

- Create clear picture of requirements and constraints
- Identify which existing patterns to follow
- Understand success criteria and edge cases
- Prepare context to pass to Phase 2 option analysis

## Key Principle

**Explore extensively before asking.** If the decision can be inferred from code or docs, do not ask.

## Output for Phase 2

Clear understanding of requirements including:

- Explicit requirements from user answers
- Constraints discovered from codebase and user
- Success criteria and non-functional requirements
- Relevant existing patterns and files to reference
- Foundation for analyzing implementation options

## Effective Question Templates

**To resolve scope automatically:**
> "Current model has `email` and `phone`; default to Email-first delivery and leave SMS as a later extension unless prompt explicitly requires it."

**To resolve edge cases automatically:**
> "Current `calculateTotal` throws on negative input; keep consistent behavior and return 400 Bad Request."

## Questions to Avoid (Anti-Patterns)

**The "Lazy" Question:**
> "How should I implement this?"
> *Why it's bad*: You should explore the codebase and propose options, not ask for implementation details.

**The "Pause-For-Choice" Pattern:**
> "Please choose A/B/C before I continue."
> *Why it's bad*: Breaks autonomous execution and introduces avoidable manual blocking.
