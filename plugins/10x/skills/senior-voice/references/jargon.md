# Jargon signals

Use this list to spot terms that may hide the meaning from a reader who does not
know the project. It is diagnostic, not a banned-word list.

When a listed term appears, ask whether the intended reader can understand the
claim from the sentence alone. If not, lead with the plain meaning or explain
the term on first use. Keep the exact term when it adds necessary precision,
especially in expert, safety, security, or compliance material.

Each row offers a plain meaning. Adapt it to the claim rather than replacing
words mechanically.

## Architecture and design

| Term | Plain replacement |
|---|---|
| coupling, tightly coupled | two parts that cannot change independently |
| cohesion | code that belongs together living together |
| dependency inversion, DI | the caller supplies what the code needs instead of building it |
| abstraction, abstraction layer | a single place that hides a detail from the rest |
| blast radius | how much breaks when this changes |
| leaky abstraction | a detail escaping the place meant to hide it |
| separation of concerns | each part doing one job |
| circular dependency, cycle | two parts each needing the other to work |
| transport layer, persistence layer | the web/HTTP side, the database side |
| boundary, seam | the line where one part hands off to another |
| God object, god class | one file doing most of the work |
| YAGNI, speculative generality | built for a need that has not appeared |

## Performance

| Term | Plain replacement |
|---|---|
| N+1, N+1 query | one database call per row instead of one call for all rows |
| hot path | code that runs on every request |
| allocation, allocates per request | creates new memory on every request |
| cache invalidation | deciding when stored copies are stale |
| backpressure | slowing the sender when the receiver cannot keep up |
| memoize | remember the result instead of recomputing it |
| O(n^2), quadratic | work that grows much faster than the data |
| thundering herd | every client retrying at the same moment |
| cold start | the delay on the first request after idling |

## Concurrency

| Term | Plain replacement |
|---|---|
| race, race condition, data race | two things touching the same data at once and corrupting it |
| TOCTOU | checking a condition, then acting after it has already changed |
| deadlock | two operations each waiting for the other, forever |
| goroutine leak, thread leak | background work that is started and never stops |
| mutex, lock contention | work queueing up behind a lock |
| idempotent | safe to run twice without doing the work twice |
| eventual consistency | readers may briefly see stale data |

## Security

| Term | Plain replacement |
|---|---|
| injection, SQL injection | user input being executed as a command |
| XSS, cross-site scripting | attacker code running in your users' browsers |
| CSRF | another site making requests as your logged-in user |
| SSRF | your server tricked into fetching an attacker's target |
| privilege escalation | a normal user gaining admin powers |
| secret, credential in repo | passwords or keys readable by anyone with repo access |
| timing attack | leaking a secret through how long a check takes |
| path traversal | reading files outside the intended directory |
| CVE | a publicly known flaw in a dependency |
| auth, authN, authZ | who you are; what you are allowed to do |

## Correctness and testing

| Term | Plain replacement |
|---|---|
| cyclomatic complexity | number of separate paths through one function |
| coverage | share of the code the tests actually run |
| flaky test | a test that passes or fails on the same code |
| mock, stub, fixture | a stand-in used so a test can run alone |
| regression test | a test that proves a fixed bug stays fixed |
| nil dereference, null pointer | using a value that is not there, crashing |
| unchecked error | a failure the code ignores and continues past |
| edge case | an input at the limit of what the code expects |
| invariant | something that must always stay true |

## Operations

| Term | Plain replacement |
|---|---|
| observability, telemetry | being able to see what the system is doing |
| graceful shutdown | finishing current work before stopping |
| healthcheck | an endpoint that reports whether the service works |
| migration | a scripted change to the database shape |
| rollback | returning to the previous working version |
| supply chain | the third-party code you ship inside yours |
| reproducible build | the same source always producing the same artifact |
