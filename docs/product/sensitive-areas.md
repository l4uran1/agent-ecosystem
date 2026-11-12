# Sensitive areas

<!--
  TEMPLATE: one section per area, following the example. Delete the example and these
  comments. Keep the list short: if everything is sensitive, nothing is.
  This is the only list of sensitive areas: AGENTS.md and the prompts point here.
-->

A mistake in these areas directly hurts customers or their trust in the product.
**Any change in them needs its spec reviewed by someone else on the team before it is
built**, however small it looks, and the spec must explain the risk for users.

## <Area name>

- **What it is:** <one line, in product terms>.
- **Where it lives:** <services and, if useful, modules>.
- **Why it is sensitive:** <what happens to the customer if it breaks>.

<!--
  Example:

  ## Payments

  - **What it is:** subscription billing and invoices.
  - **Where it lives:** api (billing module), worker (monthly billing run).
  - **Why it is sensitive:** a mistake charges customers the wrong amount and cannot be
    silently undone; refunds are manual.
-->

## Known risks

Fragile spots found in the system that are not covered by tests. If a change touches
them, the spec must say how it deals with them.

- **<Short name>.** <What is fragile, what would break it, and the proposed fix if any>.
