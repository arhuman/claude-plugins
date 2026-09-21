# Performance Testing

Select load for expected traffic, stress for breaking point, spike for sudden surge, soak for long-duration stability. Use k6 where applicable; bind gates to the project's SLA, distinguishing example targets from measured results.

## k6 Load Test

Reference stages (`duration: target users`): `30s:20`, `1m:20`, `30s:0`. Check HTTP 200 and individual response time <200ms, with 1s iteration sleep.

## Stress Test

Reference stages: `2m:100`, `5m:100`, `2m:200`, `5m:200`, `2m:0`.

## Spike Test

Reference stages: `10s:10`, `1m:10`, `10s:200`, `3m:200`, `10s:10`, `3m:10`, `10s:0`.

## API Testing with Auth

Authenticate in setup using test credentials; return token to iterations and send `Authorization: Bearer <token>` on protected requests.

## Thresholds Reference

| k6 metric | Reference gate |
|---|---|
| `http_req_duration` | `p(95)<500`, `p(99)<1000` (milliseconds) |
| `http_req_failed` | `rate<0.01` (under 1% failures) |
| `http_reqs` | `rate>100` (requests/second) |
| `http_req_duration{name:login}` | `p(95)<200` |

Report endpoint p50/p95/p99 per [report format](test-reports.md#test-report-template).
