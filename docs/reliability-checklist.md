# Reliability checklist

Failures we have already had that can be seen in a diff. `make review` applies only the items
whose trigger matches the change, not all of them on every review.

Each item has:

- **Trigger:** what has to appear in the diff for the item to apply. It must be readable in
  the diff, without running anything.
- **Check:** what to look at when it applies.
- **Origin:** the issue, PR or incident it comes from. An item without an origin does not go in.

New items are proposed by `make archive` when it closes a bug, and go in through a PR like any
other change to the ecosystem repo. When an item stops making sense (the code it watched no
longer exists), delete it.

Group the items by repo, or under "Across services" when they involve more than one.

<!--
  Example of an item; copy its shape and delete this comment.

## api

### Polling another service with a fixed delay

- **Trigger:** a job that reschedules itself, a poll or a retry towards another service with a
  constant delay.
- **Check:** how many polls per minute there are with many pending jobs at once. With a fixed
  delay it grows with the pending jobs and can flood the queue. It needs backoff, and the
  longest wait must stay below the threshold that gives the job up as lost.
- **Origin:** #123: polling the exporter every 5 s flooded the `jobs` queue.
-->
