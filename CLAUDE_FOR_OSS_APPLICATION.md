# Claude for Open Source — Application Draft (Robber)

Prepared to submit at <https://claude.com/contact-sales/claude-for-oss>.

The program grants qualifying open-source maintainers **6 months of Claude Max
20x** ($200/mo tier) at no cost, capped at 10,000 recipients on a rolling basis.

---

## Eligibility, stated honestly

| Criterion | Program bar | Robber | Meets? |
|---|---|---|---|
| GitHub stars | 5,000+ | **797** | ✗ (below) |
| npm monthly downloads | 1,000,000+ | n/a (Delphi desktop tool) | ✗ (n/a) |
| Active in last 3 months | required | last push 2026-06-26 | ✓ |
| Primary maintainer, natural person, 18+ | required | Mojtaba Tajik | ✓ |

Robber does **not** clear the automatic 5,000-star / 1M-download threshold. It
qualifies — if at all — under the program's explicit exception:

> "We also accept maintainers for projects that don't quite fit the criteria but
> still make a big impact... maintainers of critical-infrastructure projects that
> may not hit the headline metrics should apply anyway and tell us about it."

The pitch below leans on that exception. Approval is not guaranteed; the case is
made on longevity, real-world security impact, and active maintenance.

---

## Suggested form answers

**Maintainer name:** Mojtaba Tajik
**Email:** onyfel@gmail.com
**GitHub profile:** https://github.com/MojtabaTajik
**Are you the primary maintainer?** Yes

**Project name:** Robber — DLL Hijack Scanner
**Repository:** https://github.com/MojtabaTajik/Robber
**Homepage:** https://mojtabatajik.github.io/Robber/
**License:** GPL-3.0
**Primary language:** Delphi / Object Pascal (no third-party dependencies)
**Created:** November 2015 · **Last release activity:** 2026

**Project metrics:**
- 797 GitHub stars, 153 forks
- ~10 years of continuous maintenance (2015–present)
- Topics: security, dll-hijacking, vulnerability-scanners

---

## Short project description (for the form)

> Robber is a free, open-source Windows security tool that scans executables for
> DLL-hijacking vulnerabilities. It walks a directory tree, compares each binary's
> import table (standard and delayed imports) against what's on disk, resolves the
> Windows DLL search order, and flags cases where an attacker with write access to
> an earlier directory in the chain could load a malicious DLL — highlighting
> privilege-escalation cases where the target runs elevated. It has been a staple
> in the pentester / red-team toolkit for nearly a decade, ships as a single
> dependency-free binary with both GUI and pipe-friendly CLI (JSON/CSV output),
> and excludes system DLLs automatically to avoid false positives.

## Why this project deserves support (the "tell us about it" case)

- **Longevity and trust.** Maintained continuously since 2015. In security
  tooling, a decade of a stable, auditable, GPL-licensed tool is itself the value —
  practitioners trust tools they can read and that have survived scrutiny.
- **Real-world security impact.** DLL hijacking remains a live class of Windows
  privilege-escalation and persistence techniques (MITRE ATT&CK T1574.001). Robber
  is one of the few dedicated, open scanners for it, with 153 forks feeding derived
  tooling and research.
- **Underserved ecosystem.** Delphi / Object Pascal is poorly served by modern AI
  and analysis tooling. Support here disproportionately unblocks a niche the
  ecosystem otherwise ignores.
- **Actively maintained, not abandoned.** Recent work includes a non-elevated
  directory-enumeration crash fix, CLI/GUI polish, and export tooling.

## How I would use Claude Max

- Modernize a long-lived Delphi codebase: refactoring, readability passes, and
  filling the near-total gap in automated tests for a language with weak tooling.
- Extend analysis coverage (additional import edge cases, search-order nuances,
  signing/architecture heuristics) with a reviewer-in-the-loop.
- Improve documentation, issue triage, and contributor onboarding to grow the
  maintainer base beyond one person.
- Explore a portable core so the detection logic isn't locked to the Delphi GUI.

---

## Submission checklist

- [ ] Open https://claude.com/contact-sales/claude-for-oss (must be done by a human;
      the form is gated and rejects automated submission).
- [ ] Paste the answers above; confirm email `onyfel@gmail.com`.
- [ ] Be candid in the free-text field that Robber is below the 5,000-star bar and
      you're applying under the impact/critical-infrastructure exception.
- [ ] Applications are open on a rolling basis — submit sooner rather than later
      given the 10,000-recipient cap.

_This is a helper document, not an official Anthropic form. Verify current program
terms on the application page before submitting._
