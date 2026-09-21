# QA Methodology

## Manual Testing Types

| Type | Required record/checks | Reference time/target |
|---|---|---|
| Exploratory, new features | Charter (feature/focus), mission, boundary/error/recovery/workflow/integration ideas; severity findings with impact; areas explored and risks | charter 60-90min; planning range 60-120min |
| Usability, UI changes | Task, completion time, errors, satisfaction 1-5; navigation/expectation mismatches and positive observations | 2-4h; 80% unaided completion in <5min |
| Accessibility, every release | WCAG 2.1 AA: keyboard focus/navigation, ARIA labels, contrast; axe-core violations absent | 1-2h |
| Localization, multi-region | No truncation; correct date/time/currency; RTL Arabic/Hebrew; UTF-8; locale sorting | 1 day/locale |

Compatibility output: `Browser | Version | OS | Status`. Cover latest Chrome/Firefox on Windows/Mac, Safari on macOS/iOS, Edge on Windows; report measured statuses only.

## Defect Management

Use 5 Whys to establish root cause and prevention. Defect format: `[SEVERITY] Title`, reproduction steps, expected, actual, business/user impact, root cause, recommended fix. Severity definitions and full report belong to [test reports](test-reports.md#severity-definitions).

## Quality Metrics

| Metric | Calculation | Target |
|---|---|---|
| Defect Removal Efficiency | testing defects / (testing + production defects) * 100 | >95% |
| Leakage | production defects / total defects * 100 | <5% |
| Test effectiveness | test-found defects / total defects * 100 | >90% |
| Automation ROI | (time saved - maintenance cost - development cost) / development cost | report result |

Dashboard columns: `Metric | Target | Actual | Trend | Status`. Reference targets: coverage >80%, leakage <5%, automation >70%, critical defects 0, MTTR <48h. Keep these reference targets distinct from the project's `COVER_MIN` sign-off floor.

| Metric | Excellent | Good | Needs work |
|---|---|---|---|
| Coverage | >90% | 70-90% | <70% |
| Leakage | <2% | 2-5% | >5% |
| Automation | >80% | 60-80% | <60% |
| MTTR | <24h | 24-48h | >48h |

## Continuous Testing & Shift-Left

Review requirements for testability, design test cases during design, use test-first unit development, automate CI tests, static analysis on commit and security scans pre-merge.

Feedback targets: unit on save <5min; integration on commit <15min; E2E on PR <30min; nightly regression <2h.

## Quality Advocacy

Production release gate blockers: zero critical defects, coverage >80%, all P0/P1 tests passing, performance SLA met, clean security scan, WCAG AA. Record decision exactly as `GO | NO-GO | GO with exceptions`; identify exceptions rather than claiming an unmet gate passed.

## Test Planning

Plan format: feature title; scope; types (unit/integration/E2E/performance/security); resources/team; dependencies; schedule; entry/exit criteria; risks and mitigation. Include case expectations/coverage/findings per [testing output](../SKILL.md#output-templates).

Environment strategy columns: `Env | Purpose | Data | Refresh | Access`:
- Dev: development, synthetic, on-demand, all.
- Test: QA, test data, daily, QA.
- Stage: pre-prod, prod-like, weekly, limited.
- Prod: live, real, no refresh schedule, Ops; not a source of test data/credentials.
