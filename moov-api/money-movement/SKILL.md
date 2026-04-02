---
name: Moov Money Movement
description: Transfers, refunds, reversals, disputes, transfer groups, scheduled transfers, and wallet sweeps on the Moov platform.
---

# Moov Money Movement

## Payment Methods & Capabilities

Payment methods are auto-generated from linked funding sources (bank accounts, cards, wallets).

### Source methods (where money comes from)

| Method | Funding source | Description |
|--------|---------------|-------------|
| `moov-wallet` | Moov wallet | Transfer from wallet balance |
| `ach-debit-fund` | Verified bank account | Debit bank to fund wallet/payouts |
| `ach-debit-collect` | Verified bank account | Debit bank for consumer/B2B payment |
| `card-payment` | Card | Charge a credit or debit card |
| `apple-pay` | Apple Pay | Accept Apple Pay |
| `pull-from-card` | Debit/prepaid card | Pull funds from card |

### Destination methods (where money goes to)

| Method | Funding source | Description |
|--------|---------------|-------------|
| `moov-wallet` | Moov wallet | Credit wallet balance |
| `ach-credit-standard` | Bank account | Credit bank (1-2 business days) |
| `ach-credit-same-day` | Bank account | Credit bank (same day) |
| `instant-bank-credit` | Bank account | Real-time credit via RTP/FedNow |
| `push-to-card` | Debit/prepaid card | Instant credit to debit card |

### Who needs which capability

When **collecting** funds, the **destination** (merchant) account needs the capability:
- `card-payment`, `apple-pay` → destination needs `collect-funds.card-payments`
- `ach-debit-collect` → destination needs `collect-funds.ach`

When **sending** funds, the **source** (sender) account needs the capability:
- `ach-credit-standard`, `ach-credit-same-day` → source needs `send-funds.ach`
- `instant-bank-credit` → source needs `send-funds.instant-bank`
- `push-to-card` → source needs `send-funds.push-to-card`

The other party only needs the `transfers` capability (auto-enabled).

## Common Use Cases

### Accept card payments
- Merchant needs: `collect-funds.card-payments` capability
- Customer links card → `card-payment` source method
- Transfer to merchant's `moov-wallet`

### ACH collections (recurring billing, invoices)
- Merchant needs: `collect-funds.ach` capability
- Customer links verified bank account → `ach-debit-collect` source method
- Transfer to merchant's `moov-wallet`

### ACH payouts (vendor payments, disbursements)
- Sender needs: `send-funds.ach` capability
- Recipient links bank account → `ach-credit-standard` or `ach-credit-same-day` destination
- Transfer from sender's `moov-wallet`

### Instant card payouts (gig economy, withdrawals)
- Sender needs: `send-funds.push-to-card` capability
- Recipient links debit card → `push-to-card` destination method
- Transfer from sender's `moov-wallet`

### Instant bank payouts (RTP/FedNow)
- Sender needs: `send-funds.instant-bank` capability
- Recipient links bank account → `instant-bank-credit` destination method
- Transfer from sender's `moov-wallet`

## Transfers

### Step 1: Get transfer options

Always check available payment rails before creating a transfer.

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/transfer-options" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "amount": { "value": 5000, "currency": "USD" },
    "source": { "accountID": "source-account-id" },
    "destination": { "accountID": "destination-account-id" }
  }'
```

### Step 2: Create transfer

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/transfers" \
  -H "Authorization: Bearer {token}" \
  -H "X-Idempotency-Key: {uuid}" \
  -H "X-Wait-For: rail-response" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "amount": { "value": 5000, "currency": "USD" },
    "source": { "paymentMethodID": "source-pm-id" },
    "destination": { "paymentMethodID": "dest-pm-id" },
    "description": "Payment for order #123"
  }'
```

```go
// Go SDK
transfer, err := mc.CreateTransfer(ctx, moov.CreateTransfer{
    Amount:      moov.Amount{Value: 5000, Currency: "USD"},
    Source:      moov.CreateTransfer_Source{PaymentMethodID: sourcePmID},
    Destination: moov.CreateTransfer_Destination{PaymentMethodID: destPmID},
    Description: moov.String("Payment for order #123"),
}, moov.WithIdempotencyKey(uuid.New().String()),
   moov.WithWaitForRailResponse())
```

```typescript
// TypeScript SDK
const transfer = await moov.transfers.create({
  accountID,
  amount: { value: 5000, currency: "USD" },
  source: { paymentMethodID: sourcePmID },
  destination: { paymentMethodID: destPmID },
  description: "Payment for order #123",
}, {
  idempotencyKey: crypto.randomUUID(),
  waitFor: "rail-response",
});
```

```python
# Python SDK
transfer = client.transfers.create(
    account_id=account_id,
    amount={"value": 5000, "currency": "USD"},
    source={"payment_method_id": source_pm_id},
    destination={"payment_method_id": dest_pm_id},
    description="Payment for order #123",
    idempotency_key=str(uuid4()),
)
```

### Payment rail comparison

| Rail | Speed | Direction | Use case |
|------|-------|-----------|----------|
| `ach-debit-fund` | 1-3 days | Pull from bank | Collect from merchants |
| `ach-debit-collect` | 1-3 days | Pull from bank | Consumer/B2B collection |
| `ach-credit-standard` | 1-2 days | Push to bank | Standard payouts |
| `ach-credit-same-day` | Same day | Push to bank | Faster payouts |
| `instant-bank-credit` | Seconds | Push to bank | Real-time (RTP/FedNow) |
| `push-to-card` | Minutes | Push to card | Instant card payout |
| `moov-wallet` | Instant | Wallet ↔ wallet | Internal transfers |
| `card-payment` | Instant auth | Pull from card | Card acceptance |

### Transfer status lifecycle

`created` → `pending` → `completed` | `failed` | `reversed`

For transfer groups: `created` → `queued` → `pending` → `completed` | `canceled`

### Key headers

- `X-Idempotency-Key: {uuid}` — **Always include**. Prevents duplicates.
- `X-Wait-For: rail-response` — Synchronous response. Without it, you get `202 Accepted`.

## Refunds & Reversals

**Use the reversals endpoint** (`POST /accounts/{accountID}/transfers/{transferID}/reversals`) instead of the legacy refunds endpoint. Reversals are smarter — they automatically choose between canceling (if not yet settled) or refunding (if already settled), reducing processing costs.

### Full reversal

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/transfers/{transferID}/reversals" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00"
```

No request body needed. If the transfer hasn't settled, it's canceled instantly. If it has settled, a full refund is initiated.

### Partial refund

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/transfers/{transferID}/reversals" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "amount": { "value": 500, "currency": "USD" }
  }'
```

Partial amounts always initiate a refund (partial cancellations are not supported).

### Key details

- **Don't refund disputed transfers** — if a cardholder has already filed a dispute, refunding risks a double charge
- **One at a time** — only one refund can be in progress per transfer
- **Cannot exceed original** — refund amount cannot exceed the original transfer amount
- **Cannot cancel after issued** — refunds are final once initiated
- **Refund status lifecycle**: `initiated` → `confirmed` → `settled` → `completed` (or `failed`)
- **Customer timing**: Pending credit appears immediately, posts in 5-7 business days

### Webhook events

- `refund.created`, `refund.updated` — refund status changes
- `cancellation.created`, `cancellation.updated` — cancellation status changes

## Disputes

Disputes (chargebacks) occur when a cardholder questions a payment with their card issuer. **Moov handles the card network interaction** — you respond through the API.

### Dispute lifecycle

1. **Chargeback received** — Moov debits the merchant's wallet immediately. Transfer status stays `completed`.
2. **Merchant decides** — Accept the dispute or contest it with evidence.
3. **Resolution** — Card network rules in favor of merchant (won) or cardholder (lost).

### Dispute phases

| Phase | Description |
|-------|-------------|
| `pre-dispute` | Visa only (RDR) — can be auto-resolved before chargeback |
| `inquiry` | Amex only — preliminary stage before formal chargeback |
| `chargeback` | Active dispute, wallet already debited |

### Response deadlines (by card brand)

| Brand | Deadline |
|-------|----------|
| Visa | 6 calendar days |
| Mastercard | 14 calendar days |
| Discover | 14 calendar days |
| Amex | 10 calendar days |

If no response by deadline, Moov accepts the dispute on the merchant's behalf.

### Accept a dispute

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/disputes/{disputeID}/accept" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00"
```

This is final — cannot be undone.

### Contest a dispute (upload evidence)

```bash
# 1. Upload evidence file (PDF, JPG, TIFF — max 4 MB each)
curl -X POST "https://api.moov.io/accounts/{accountID}/disputes/{disputeID}/evidence-file" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  -F "file=@receipt.pdf" \
  -F "evidenceType=receipt"

# 2. Or upload text evidence
curl -X POST "https://api.moov.io/accounts/{accountID}/disputes/{disputeID}/evidence-text" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "evidenceType": "cover-letter",
    "text": "Customer received goods on March 15..."
  }'

# 3. Submit all evidence (can only submit once per dispute)
curl -X POST "https://api.moov.io/accounts/{accountID}/disputes/{disputeID}/evidence/submit" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00"
```

**Evidence types**: `receipt`, `proof-of-delivery`, `cancelation-policy`, `terms-of-service`, `customer-communication`, `cover-letter`, `generic-evidence`

### Dispute statuses

| Status | Meaning |
|--------|---------|
| `response-needed` | Default — merchant must accept or contest |
| `under-review` | Evidence submitted, card network reviewing |
| `accepted` | Merchant accepted liability |
| `won` | Evidence compelling, funds credited back |
| `lost` | Evidence insufficient |
| `expired` | Response deadline passed |
| `closed` | Issuer reversed chargeback |
| `resolved` | No more action required |

### Managing disputes

- **List**: `GET /accounts/{accountID}/disputes`
- **Get**: `GET /accounts/{accountID}/disputes/{disputeID}`
- **List evidence**: `GET /accounts/{accountID}/disputes/{disputeID}/evidence`

### Webhook events

- `dispute.created` — new dispute received
- `dispute.updated` — dispute status changed

## Transfer Groups

**Do not loop individual transfer creation to chain payments.** Transfer groups let you associate multiple transfers and run them sequentially — e.g., Customer → Platform wallet → Service provider.

### How it works

A child transfer references a parent transfer's ID as its source. Moov waits for the parent to complete before moving funds to the child's destination.

```bash
# Child transfer — references parent transferID as source
curl -X POST "https://api.moov.io/accounts/{accountID}/transfers" \
  -H "Authorization: Bearer {token}" \
  -H "X-Idempotency-Key: {uuid}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "amount": { "value": 4500, "currency": "USD" },
    "source": { "transferID": "parent-transfer-id" },
    "destination": { "paymentMethodID": "provider-pm-id" },
    "description": "Provider payout for order #123"
  }'
```

### Key details

- **Sum of children ≤ parent** — child transfer amounts cannot exceed the parent transfer amount. The difference is your platform fee.
- **Sequential execution** — child transfers go to `queued` status, then `pending` when the parent completes.
- **Failure cascading** — if a parent fails, child transfers are `canceled`. Funds stay at the last completed destination.
- **Group ID** — automatically assigned, equals the most senior parent's `transferID`. Use as a filter on `GET /accounts/{accountID}/transfers`.
- **Bank account destinations** — if a child transfer's destination is a bank account, it cannot become the source of further child transfers.

## Scheduled & Recurring Transfers

**Do not build your own scheduler.** Moov has a native scheduling API that handles recurring transfers, future-dated payments, automatic card-on-file updates, and auto-receipts. This applies to both hosted and embedded integrations — scheduling is a server-side feature.

### RRULE-based recurring schedule

Use an [RRULE](https://datatracker.ietf.org/doc/html/rfc5545#section-3.3.10) string to define the recurrence pattern. Moov generates each future occurrence automatically.

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/schedules" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "description": "Monthly subscription",
    "recur": {
      "recurrenceRule": "FREQ=MONTHLY;COUNT=36",
      "runTransfer": {
        "amount": { "currency": "USD", "amount": 1000 },
        "accountID": "your-account-ID",
        "source": { "paymentMethodID": "source-pm-id" },
        "destination": { "paymentMethodID": "dest-pm-id" }
      }
    }
  }'
```

Common RRULE patterns:
- `FREQ=MONTHLY;COUNT=12` — 12 monthly payments
- `FREQ=WEEKLY;INTERVAL=2` — every 2 weeks, indefinitely
- `FREQ=MONTHLY;UNTIL=20271231T000000Z` — monthly until end of 2027

### Custom future-dated occurrences

For irregular schedules or varying amounts, provide explicit dates:

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/schedules" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "description": "Loan repayment",
    "occurrences": [
      {
        "runOn": "2026-05-01T00:00:00Z",
        "runTransfer": {
          "amount": { "currency": "USD", "amount": 5000 },
          "source": { "paymentMethodID": "source-pm-id" },
          "destination": { "paymentMethodID": "dest-pm-id" }
        }
      },
      {
        "runOn": "2026-06-01T00:00:00Z",
        "runTransfer": {
          "amount": { "currency": "USD", "amount": 3000 },
          "source": { "paymentMethodID": "source-pm-id" },
          "destination": { "paymentMethodID": "dest-pm-id" }
        }
      }
    ]
  }'
```

You can combine `recur` and `occurrences` in one schedule (e.g. a one-time setup fee plus monthly payments).

### What Moov handles automatically

- **Card-on-file updates**: If a card issuer updates the card number, future scheduled transfers process without interruption.
- **Bank account notice of change**: If the receiving bank sends a correction, Moov updates the bank account automatically.
- **Recurring transaction codes**: Card transfers in a schedule are automatically flagged as `first-recurring` or `recurring`.
- **Auto-receipts**: Link a receipt to a schedule with `forScheduleID` and Moov sends receipts for every future occurrence.

### Managing schedules

- Update or cancel individual future occurrences
- Change the recurrence rule (future occurrences shift automatically)
- Add one-off occurrences (e.g. a late fee or retry of a failed payment)
- List schedules: `GET /accounts/{accountID}/schedules`

Only the account that created the schedule can modify it. Transfers already created from a schedule won't be canceled by updating the schedule.

## Sweeps

**Do not build your own wallet-to-bank payout cron job.** Moov sweeps automatically transfer wallet funds to a bank account on a daily schedule. This applies to both hosted and embedded integrations — sweeps are a server-side feature, not a UI choice.

### How it works

1. Add and verify a bank account on the merchant's account
2. Configure a sweep via Dashboard or `POST /accounts/{accountID}/sweep-configs`
3. Moov accrues wallet funds daily (closes at 4:00 PM ET) and initiates the transfer

### Sweep configuration

- **Payment methods**: `ach-credit-same-day`, `ach-credit-standard`, or `rtp-credit`
- **Auto-fallback**: If a transfer exceeds rail limits ($500K for same-day ACH, $1M for RTP), Moov falls back to standard ACH
- **Minimum balance**: Optionally keep a minimum daily wallet balance (default: $0)
- **Separate accounts**: Different bank accounts can be used for push (payouts) and pull (fee debits)

### Payout timing

| Method | When it arrives |
|--------|----------------|
| `ach-credit-same-day` | 6 PM ET same day |
| `ach-credit-standard` | 10 AM ET next business day |
| `rtp-credit` | Instant |

Sweeps are not processed on weekends or banking holidays — they accrue and pay out on the next business day.

### Negative balances

If a wallet goes negative (from chargebacks, fees, etc.), Moov waits 1 day then initiates a debit from the linked bank account. No debit for amounts under $1.

### Key details

- **Reconciliation**: Each sweep gets a `sweepID`. Query wallet transactions with `sweepID` to see subtotals grouped by `transactionType` (moov-fee, account-funding, etc.)
- **Failure handling**: Subscribe to `sweep.updated` webhook. Failed sweeps are not auto-retried. Sweep continues accruing with `action-required` status until a valid payment method is configured.
- **Management**: `GET /accounts/{accountID}/sweep-configs`, `PATCH /accounts/{accountID}/sweep-configs/{sweepConfigID}`
