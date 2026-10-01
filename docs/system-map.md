# System map

<!--
  TEMPLATE: replace the example rows (they describe a fictional company) and delete
  these comments.

  Only contracts between services go here: what one service expects from another.
  Anything the agent can read inside a single repo (folders, stack, internals) does not.

  Keep it true: a PR that adds, changes or removes a contract updates this file in the
  same change. An outdated map is worse than none, because the agent trusts it.
-->

Last reviewed: <YYYY-MM-DD>

## Services

| Service | What it does | Owner |
| --- | --- | --- |
| api | Public REST API and business logic | <team or person> |
| auth | Login and token issuing for every service | <team or person> |
| worker | Background jobs: emails, exports, billing runs | <team or person> |

## Synchronous calls (HTTP, gRPC)

| From | To | Endpoint | Notes |
| --- | --- | --- | --- |
| api | auth | `POST /internal/tokens/verify` | Called on every authenticated request |
| worker | api | `GET /internal/users/{id}` | Read-only |

## Queues and events

| Producer | Queue / topic | Consumer | Payload | Notes |
| --- | --- | --- | --- | --- |
| api | `orders.created` | worker | `{orderId, userId, total}` | At-least-once: consumers must be idempotent |

## Pub/sub channels

| Publisher | Channel | Subscriber | Notes |
| --- | --- | --- | --- |
| worker | `user:<id>:notifications` | notifications | Fire-and-forget, no replay |

## Shared tables

Tables read or written by a service other than the one that owns their schema.
These break silently: list who depends on which columns.

| Table | Owner (schema) | Used by | Columns relied on |
| --- | --- | --- | --- |
| `users` | api | worker | `id`, `email`, `locale` |

## Shared infrastructure

| Component | Used by | Notes |
| --- | --- | --- |
| Redis `sessions` | api, auth | Single point of failure for logins |
