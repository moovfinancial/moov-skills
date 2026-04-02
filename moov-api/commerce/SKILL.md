---
name: Moov Commerce
description: Payment links, invoices, receipts, and enrichment on the Moov platform.
---

# Moov Commerce

## Payment Links

Moov offers two approaches for collecting and disbursing payments:

- **Hosted** (default): Payment Links are a hosted experience — a single link handles account creation, identity verification, payment method collection, and fund movement. No custom UI needed.
- **Embedded**: If you have an existing app where users already interact (e.g., a driver app, contractor portal, customer dashboard), use Moov.js Drops to collect payment methods in your UI and the Transfers API to move money. You control the UX; Moov handles the money movement and PCI-compliant data collection.

### Two modes

| Mode | Direction | Use case |
|------|-----------|----------|
| **Payment** (collect) | Pull funds from customer | Invoices, one-time charges, e-commerce |
| **Payout** (disburse) | Push funds to recipient | Contractor pay, insurance claims, refunds, trucker settlements |

### Create a payout link

Use payout mode when you need to send money to someone who doesn't have a Moov account yet. The recipient clicks the link, verifies their identity, adds a debit card or bank account, and receives funds — all in the hosted flow.

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/payment-links" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "maxUses": 1,
    "payout": {
      "allowedMethods": ["push-to-card", "ach-credit-same-day"],
      "amount": { "currency": "USD", "value": 250000 },
      "description": "Load #4821 settlement"
    },
    "customer": {
      "email": "driver@example.com"
    },
    "lineItems": {
      "items": [
        {
          "name": "Freight: Dallas → Houston",
          "basePrice": { "currency": "USD", "valueDecimal": "2500.00" },
          "quantity": 1
        }
      ]
    }
  }'
```

Response includes a hosted URL and QR code:

```json
{
  "paymentLinkID": "...",
  "code": "abc123",
  "link": "https://moov.link/p/abc123",
  "qrCode": "data:image/png;base64,..."
}
```

### Create a payment link

Use payment mode when you need to collect money from a customer.

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/payment-links" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "payment": {
      "allowedMethods": ["card-payment", "ach-debit-collect", "apple-pay"],
      "amount": { "currency": "USD", "value": 5000 },
      "description": "Invoice #1234"
    },
    "customer": {
      "email": "customer@example.com"
    }
  }'
```

### Allowed methods by mode

| Mode | Allowed methods |
|------|----------------|
| **Payment** (collect) | `card-payment`, `ach-debit-collect`, `apple-pay` |
| **Payout** (disburse) | `push-to-card`, `rtp-credit`, `ach-credit-same-day`, `ach-credit-standard` |

### How the hosted flow works

1. **Platform creates link** via `POST /accounts/{accountID}/payment-links`
2. **Send link to recipient** — via email, SMS, or embed the QR code
3. **Recipient opens link** (`https://moov.link/p/{code}`) and verifies identity via email/phone code
4. **Recipient adds payment method** — debit card or bank account (payout) or card/bank/Apple Pay (payment)
5. **Funds move** — instantly (push-to-card, RTP) or via ACH
6. **Receipt auto-sent** to recipient via email

### Key details

- **`maxUses: 1`** — Enforced for payout links. Each recipient gets a unique link.
- **Recipient authentication** — Email or phone verification code. No password needed.
- **Account auto-creation** — If the recipient doesn't have a Moov account, one is created automatically during the flow.
- **Line items** — Optional itemized breakdown displayed on the payment page.
- **QR code** — Auto-generated with every link. Embed in emails, invoices, or print.
- **Branding** — Customize logo, accent colors, and company name via `POST /accounts/{accountID}/branding`.

### Managing payment links

- **List**: `GET /accounts/{accountID}/payment-links`
- **Get**: `GET /accounts/{accountID}/payment-links/{paymentLinkID}`
- **Update**: `PATCH /accounts/{accountID}/payment-links/{paymentLinkID}`
- **Disable**: `DELETE /accounts/{accountID}/payment-links/{paymentLinkID}`

## Invoices

Moov has two approaches for billing:

- **Hosted** (default): Moov's native Invoicing API handles line items, auto-generated payment links, email notifications, and status tracking. The payment link accepts card and ACH — no custom checkout needed. Funds land in the merchant's Moov wallet.
- **Embedded**: If you already have billing/invoicing in your app, use the Transfers API directly. Create transfers when your system determines payment is due, and use Drops for payment method collection in your UI.

**Important:** Invoices require API version `v2026.04.00` or later.

```
x-moov-version: v2026.04.00
```

### Create an invoice

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/invoices" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.04.00" \
  --data-raw '{
    "customerAccountID": "tenant-account-id",
    "invoiceDate": "2026-04-01T00:00:00Z",
    "dueDate": "2026-04-15T00:00:00Z",
    "description": "April rent + cleaning fee",
    "lineItems": {
      "items": [
        {
          "name": "Monthly rent",
          "basePrice": { "currency": "USD", "valueDecimal": "1500.00" },
          "quantity": 1
        },
        {
          "name": "Cleaning fee",
          "basePrice": { "currency": "USD", "valueDecimal": "150.00" },
          "quantity": 1
        }
      ]
    }
  }'
```

### Send the invoice

PATCH the status to `unpaid`. This finalizes the invoice, generates a secure payment link, and emails the customer.

```bash
curl -X PATCH "https://api.moov.io/accounts/{accountID}/invoices/{invoiceID}" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.04.00" \
  --data-raw '{
    "status": "unpaid"
  }'
```

### Invoice status lifecycle

`draft` → `unpaid` → `payment-pending` → `paid`

Also: `overdue` (past due date), `canceled` (voided)

| Status | Payment link | What happened |
|--------|-------------|---------------|
| `draft` | N/A | Created, editable |
| `unpaid` | Active | Sent to customer with payment link |
| `payment-pending` | Disabled | Customer payment in progress |
| `paid` | Disabled | Payment completed, funds in wallet |
| `overdue` | Active | Past due date, still payable |
| `canceled` | Disabled | Voided, link shows error |

### What Moov handles automatically

- **Payment link**: Auto-generated, single-use, scoped to the invoice and customer. Accepts card and ACH.
- **Email notifications**: Sent on invoice send, payment, overdue, and cancellation — to both merchant and customer.
- **Invoice numbers**: Auto-generated sequentially (e.g., INV-1001).
- **PDF attachment**: Invoice PDF included in email.
- **Receipts**: Customer receives a receipt on successful payment.
- **Failed payments**: Invoice returns to `unpaid`, payment link stays active for retry.

### Managing invoices

- **Update**: PATCH fields on `draft`, `unpaid`, or `overdue` invoices (`dueDate` only editable in `draft`)
- **Delete**: DELETE on `draft` invoices only
- **Cancel**: PATCH status to `canceled` — disables payment link
- **Mark paid externally**: `POST /accounts/{accountID}/invoices/{invoiceID}/payments` for off-platform payments
- **List**: `GET /accounts/{accountID}/invoices`

### Webhook events

- `invoice.created` — invoice created
- `invoice.updated` — status changed (sent, paid, overdue, canceled)

## Receipts

Moov can send branded receipt emails for transfers — with your logo, company name, and links to your customer service portal. If you already have your own transactional email system, you can skip Moov receipts and use `transfer.updated` webhooks to trigger your own notifications instead.

### Send a receipt

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/transfers/create-receipts" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "forTransferID": "transfer-id",
    "emailAccountID": "recipient-account-id"
  }'
```

### Receipt options

- **Single transfer**: `forTransferID` — sends confirmation, refund notification, or failure notice
- **Recurring series**: `forScheduleID` — sends a receipt for every future occurrence
- **Specific occurrence**: `forOccurrenceID` — receipt for one occurrence in a series
- **Custom email**: Use `email` field instead of `emailAccountID` to send to a different address
- **Multiple recipients**: Create multiple receipts per transfer with different email addresses

### What receipts include

- Amount, date, receipt ID, description, source payment method
- Sales tax breakdown (if provided in the transfer)
- Issuer confirmation number (for card payments)
- Refund details (for refund receipts)

### Management

- **List**: `GET /accounts/{accountID}/transfers/list-receipts`

## Enrichment

### Institution lookup

Look up a bank by routing number to validate it exists and check which payment rails are available.

```bash
curl -X GET "https://api.moov.io/institutions?routingNumber=021000021" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00"
```

Requires `/fed.read` scope. Returns institution name, address, and supported capabilities.

### Address autocomplete

```bash
curl -X GET "https://api.moov.io/enrichment/address?search=123+Main" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00"
```

Reduces user input errors by auto-completing addresses.

### Profile enrichment

```bash
curl -X GET "https://api.moov.io/enrichment/profile?email=user@example.com" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00"
```

Returns publicly available information about an individual or business based on email — use to pre-fill form fields and reduce onboarding friction.
