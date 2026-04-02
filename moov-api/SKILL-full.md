
# Moov API Integration Skill

You are an expert at building payment integrations with the Moov platform. Use these patterns to write correct, production-ready code.

**Before generating code, determine the developer's context:**

1. **Detect language/SDK** — Check for marker files in the project to auto-detect:

| Marker file | Language | SDK package | Import |
|-------------|----------|-------------|--------|
| `package.json` or `tsconfig.json` | TypeScript | `@moovio/sdk` | `import { Moov } from "@moovio/sdk"` |
| `go.mod` | Go | `github.com/moovfinancial/moov-go` | `import moov "github.com/moovfinancial/moov-go"` |
| `pyproject.toml` or `requirements.txt` | Python | `moov` | `from moov import Moov` |
| `*.csproj` or `*.sln` | .NET | `Moov` | `using Moov` |

If no marker file found, ask the developer which language they are using — don't guess.

2. **Detect API version** — Check if the project already has a Moov SDK installed. Read the version from the package manager lockfile and map it using the version table below. If not found, default to the latest stable version.

3. **Hosted or embedded?** Moov offers hosted flows (payment links, payout links, hosted onboarding, Drops) that handle UI, identity verification, and payment method collection — no custom frontend needed. Some developers already have their own user-facing application and want to embed Moov directly into it using the API and Moov.js components. **Default to hosted unless the developer says they want to build into an existing UI.** If they mention having an existing app, portal, or dashboard where users already interact, recommend the embedded/API-direct approach for those flows.

| Approach | Best for | What you build |
|----------|----------|----------------|
| **Hosted** (default) | New platforms, fast launches, no existing UI | Send links — Moov handles the UI, identity verification, payment method collection, and fund movement |
| **Embedded** | Existing apps with their own UX | Use Moov.js Drops for PCI-compliant card/bank inputs in your UI, call APIs server-side for transfers, use webhooks for status updates |

## Mental Model

- **Facilitator account**: Your platform. Created when you sign up at dashboard.moov.io.
- **Connected accounts**: Your users (merchants, recipients, senders). You create these via API.
- **Capabilities**: Permissions you request on connected accounts (e.g. `send-funds.ach`, `collect-funds.card-payments`). Each has requirements (KYC, bank account, etc.) that must be fulfilled before the capability is active.
- **Payment methods**: Auto-generated from linked sources (bank accounts, cards, wallets). You reference `paymentMethodID` in transfers.
- **Transfers are immutable**: Once created, a transfer cannot be modified. You can only refund or create a new one.
- **Amounts are in cents**: `"value": 1000` means $10.00 USD.
- **Idempotency**: Always send `X-Idempotency-Key` header with a UUID on transfer creation. Duplicate keys return `409 Conflict`.

## API Reference & OpenAPI Spec

The **source of truth** for all Moov API endpoints, request/response schemas, and parameters is the OpenAPI specification.

- **API reference (rendered)**: https://docs.moov.io/api/
- **OpenAPI spec download**: https://spec.speakeasy.com/moov/moov/api-v2026.01.00
- **Current stable version**: `v2026.01.00`

When in doubt about request bodies, response shapes, or available fields, consult the OpenAPI spec directly. The rendered API reference at `/api/` includes per-endpoint documentation with request/response examples.

## API Version

Always include the version header. New integrations should use the latest version.

```
x-moov-version: v2026.01.00
```

If omitted, the API defaults to `v2024.01.00`.

### Version mapping

| API version | SDK version | Quarter |
|-------------|-------------|---------|
| `v2026.04.00` | `26.4.x` | Q2 2026 (in development) |
| `v2026.01.00` | `26.1.x` | Q1 2026 (latest stable) |
| `v2025.10.00` | `25.10.x` | Q4 2025 |
| `v2025.07.00` | `25.7.x` | Q3 2025 |
| `v2025.04.00` | `25.4.x` | Q2 2025 |

Pattern: API `vYYYY.MM.00` → SDK `YY.M.x`

SDKs automatically set the `X-Moov-Version` header based on the version installed. Never hardcode the API version in URLs — use the SDK client which handles versioning.

**Per-SDK:**
```go
// Go — set on client
mc, _ := moov.NewClient(moov.WithAPIVersion("v2026.01.00"))
```
```typescript
// TypeScript
const moov = new Moov({ apiVersion: "v2026.01.00", ...opts });
```
```python
# Python
client = Moov(api_version="v2026.01.00")
```

## Authentication

Moov uses two auth methods depending on context. The core design: **API keys stay on your server, short-lived OAuth tokens go to the client.**

### How it works

```
┌─────────────┐    API keys (Basic auth)    ┌──────────┐
│  Your Server │ ──────────────────────────► │ Moov API │
│              │ ◄────────────────────────── │          │
│              │    access_token (JWT)       │          │
│              │                             │          │
│  sends token │                             │          │
│  to client   │                             │          │
│      │       │                             │          │
│      ▼       │                             │          │
│ ┌──────────┐ │    token (Bearer auth)      │          │
│ │ Frontend │ │ ──────────────────────────► │          │
│ │ Moov.js  │ │    PII goes direct to Moov │          │
│ └──────────┘ │                             │          │
└─────────────┘                             └──────────┘
```

1. Your **server** authenticates with API keys (Basic auth) to generate a **scoped, short-lived token**
2. Your **server** sends that token to the **client**
3. The **client** uses the token with Moov.js or Drops — sensitive data (card numbers, bank accounts) goes directly to Moov, never through your server

### Step 1: Generate a scoped token (server-side)

Your server calls `POST /oauth2/token` with your API keys. The `scope` parameter controls what the token can do.

```bash
curl -X POST "https://api.moov.io/oauth2/token" \
  -u "public_key:private_key" \
  -d "grant_type=client_credentials&scope=/accounts.write"
```

Response:
```json
{
  "access_token": "eyJhbGciOiJFZERTQS...",
  "token_type": "Bearer",
  "expires_in": 259200
}
```

### Step 2: Use the token

**Server-side (direct API calls):**
```bash
curl -X POST "https://api.moov.io/accounts" \
  -H "Authorization: Bearer {access_token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{ "accountType": "business", ... }'
```

**Client-side (Moov.js / Drops):**
```javascript
// Your server endpoint generates and returns a token
const token = await fetch("/your-api/moov-token").then(r => r.json());

// Pass token to Moov.js — PII goes direct to Moov, not your server
import { loadMoov } from "@moovio/moov-js";
const moov = await loadMoov(token.access_token);
```

### Scopes

Scopes are granular permissions. Two kinds:

**Account-restricted** (no account ID needed):
- `/accounts.write` — create new accounts
- `/fed.read` — look up banking institutions
- `/ping.read` — test API availability

**Account-specific** (requires the account ID):
- `/accounts/{accountID}/transfers.write` — create transfers
- `/accounts/{accountID}/bank-accounts.write` — link bank accounts
- `/accounts/{accountID}/cards.write` — link cards
- `/accounts/{accountID}/capabilities.write` — request capabilities
- `/accounts/{accountID}/profile.read` — view account details
- `/accounts/{accountID}/wallets.read` — view wallet balance
- `/accounts/{accountID}/payment-methods.read` — view payment methods
- `/accounts/{accountID}/representatives.write` — add business reps

**Important:** Transfer scopes use the **platform** account ID. All other scopes use the **connected account's** ID.

### Multi-token pattern

Complex flows need multiple tokens as new account IDs become available:

```javascript
// 1. Generate initial token with account-creation scope
const token1 = await generateToken(["/accounts.write"]);

// 2. Create the account → get accountID back
const account = await createAccount(token1);

// 3. Generate new token with account-specific scopes
const token2 = await generateToken([
  `/accounts/${account.id}/capabilities.write`,
  `/accounts/${account.id}/bank-accounts.write`,
  `/accounts/${account.id}/profile.read`,
]);

// 4. Now you can request capabilities, link bank accounts, etc.
```

This pattern is especially common with the **Onboarding Drop**, which fires an `onResourceCreated` callback when the account is created — your server generates a new token with the account-specific scopes and updates the Drop.

### Server-side only (Basic auth)

For purely server-side integrations where you don't need client tokens, you can use Basic auth directly:

```bash
curl -X GET "https://api.moov.io/accounts/{accountID}" \
  -H "Authorization: Basic {base64(public_key:private_key)}" \
  -H "x-moov-version: v2026.01.00"
```

### Token revocation

```bash
curl -X POST "https://api.moov.io/oauth2/revoke" \
  -u "public_key:private_key" \
  --data '{ "token": "eyJhbGciOiJFZERTQS..." }'
```

## Troubleshooting

### Common HTTP errors

| HTTP | Meaning | Fix |
|------|---------|-----|
| 401 | Invalid or expired token | Re-authenticate. Check API key scope. Using test key against production or vice versa? |
| 403 | Missing capability or scope | Request the needed capability. Check OAuth scope. Account may not be fully verified. |
| 409 | Duplicate idempotency key | Use a new UUID or retrieve the original transfer. |
| 422 | Validation error | Read the error response body — it includes field-level details. Common: missing `businessType`, invalid capability key, unverified bank account, missing representatives for LLC/corporation. |
| 429 | Rate limited | Back off and retry with exponential backoff. Check `Retry-After` header. Production: 100 req/s. Sandbox: 50 req/s. |
| 202 | Accepted but pending | Transfer created but rail response timed out. Check status via GET or webhook. |

### Capability issues

- **Status "pending"**: Verification or underwriting in progress. Check `GET /accounts/{accountID}/capabilities` for `requirements.currentlyDue`.
- **Status "disabled"**: Verification failed or requirements not met. Update account profile with missing information.
- **Status "revoked"**: Removed after being enabled, typically compliance/risk. Contact Moov support.

### Transfer failures

- **"No transfer options available"**: Source or destination account missing required capability, payment method not available, or bank account not verified.
- **Transfer status "failed"**: Insufficient wallet balance, ACH return (NSF, account closed), or card declined. Check transfer details for failure reason.
- **Transfer stuck in "pending"**: ACH takes 1-4 business days depending on method. Use `X-Wait-For: rail-response` for instant rails.

### API version mismatch

If you see unexpected response shapes, missing fields, or deprecated field errors: check that `X-Moov-Version` is set (defaults to oldest version if omitted) and that SDK version matches the API version per the version mapping table above.

### Card-specific failure codes

| Code | Meaning | Action |
|------|---------|--------|
| `card-declined` | Issuer declined | Contact issuer or use different card |
| `insufficient-funds` | Not enough funds | Retry with lower amount or later |
| `expired-card` | Card expired | Update card details |
| `cvv-mismatch` | CVV wrong | Verify and retry |
| `lost-or-stolen` | Card reported lost/stolen | Do not retry |
| `velocity-limit-exceeded` | Too many transactions | Retry later |
| `suspected-fraud` | Flagged for fraud | Cardholder contacts issuer |
| `do-not-honor` | Issuer won't allow | Try different card or contact issuer |

## SDK Quick Reference

| Language | Package | Install |
|----------|---------|---------|
| Go | `github.com/moovfinancial/moov-go` | `go get github.com/moovfinancial/moov-go` |
| TypeScript | `@moovio/sdk` | `npm install @moovio/sdk` |
| Python | `moov` | `pip install moov` |
| .NET | `Moov` | `dotnet add package Moov` |
| Moov.js (browser) | `@moovio/moov-js` | `npm install @moovio/moov-js` |

## Webhooks

Webhooks send real-time HTTP POST notifications to your server when events occur. If Moov doesn't receive a 2xx response within 5 seconds, it retries for up to 24 hours.

### Event categories

| Category | Example events |
|----------|---------------|
| Transfers | `transfer.created`, `transfer.updated` |
| Refunds | `refund.created`, `refund.updated` |
| Cancellations | `cancellation.created`, `cancellation.updated` |
| Disputes | `dispute.created`, `dispute.updated` |
| Accounts | `account.created`, `account.updated` |
| Capabilities | `capability.requested`, `capability.updated` |
| Bank accounts | `bankAccount.created`, `bankAccount.updated` |
| Cards | `card.created`, `card.updated`, `card.autoUpdated` |
| Payment methods | `paymentMethod.created`, `paymentMethod.updated`, `paymentMethod.disabled` |
| Wallets | `wallet.transaction.created`, `wallet.transaction.updated` |
| Invoices | `invoice.created`, `invoice.updated` |
| Payment links | `payment-link.completed` |
| Sweeps | `sweep.updated` |
| Terminal | `terminalAppRegistration.updated` |

### Register a webhook

```bash
curl -X POST "https://api.moov.io/webhooks" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "url": "https://your-app.com/webhooks/moov",
    "eventTypes": [
      "transfer.updated",
      "refund.created",
      "refund.updated",
      "cancellation.updated",
      "dispute.created",
      "dispute.updated",
      "invoice.created",
      "invoice.updated",
      "payment-link.completed",
      "card.autoUpdated",
      "sweep.updated",
      "terminalAppRegistration.updated"
    ]
  }'
```

### Verify webhook signature

Moov sends these headers: `X-Timestamp`, `X-Nonce`, `X-Webhook-ID`, `X-Signature`.

```go
import (
    "crypto/hmac"
    "crypto/sha512"
    "encoding/hex"
)

func verifyWebhook(timestamp, nonce, webhookID, signature, secret string) bool {
    payload := timestamp + "|" + nonce + "|" + webhookID
    h := hmac.New(sha512.New, []byte(secret))
    h.Write([]byte(payload))
    expected := hex.EncodeToString(h.Sum(nil))
    return hmac.Equal([]byte(expected), []byte(signature))
}
```

```javascript
const { createHmac } = require("crypto");

function verifyWebhook(timestamp, nonce, webhookID, signature, secret) {
  const payload = `${timestamp}|${nonce}|${webhookID}`;
  const expected = createHmac("sha512", secret).update(payload).digest("hex");
  return expected === signature;
}
```

Reference implementation: https://github.com/moovfinancial/webhook-handler

### Webhook best practices

- Always verify signatures before processing events
- Respond with 2xx quickly — process the event asynchronously if needed
- Handle duplicate events idempotently (use `X-Webhook-ID` to deduplicate)
- Subscribe only to the event types you need
- Use a queue (SQS, Redis, etc.) for reliable processing if your handler is complex
- Log webhook payloads for debugging

## Docs MCP Server

For live documentation search from your AI coding tool:

```bash
claude mcp add --transport http moov-docs https://docs.moov.io/mcp
```

This gives your AI access to `search_moov_docs`, `get_moov_doc`, and `list_moov_sections` tools for searching the full Moov documentation.

## Test Mode

- Test mode is a separate environment with sample data pre-loaded
- Use test-mode API keys (created in Dashboard with test mode toggled on)
- Test bank routing number: `123456789`
- Test card numbers follow standard test patterns
- Tap to Pay test mode uses simulated card selection — no physical tap needed
- Always test in sandbox before going to production


# Moov Accounts

## Account Types

Two types: **individual** and **business**.

**Business subtypes:** `soleProprietorship`, `llc`, `partnership`, `privateCorporation`, `publicCorporation`, `unincorporatedAssociation`, `trust`, `unincorporatedNonProfit`, `incorporatedNonProfit`, `governmentEntity`.

- Sole proprietors must use **business** account type (not individual)
- Business accounts (LLC, partnership, corporation) require adding **representatives** after creation
- Representatives include beneficial owners (25%+ ownership) and controllers
- Up to 7 representatives per account

## Create Accounts

### Business account

```bash
curl -X POST "https://api.moov.io/accounts" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "accountType": "business",
    "profile": {
      "business": {
        "legalBusinessName": "Acme Payments LLC",
        "businessType": "llc",
        "website": "acme.com"
      }
    },
    "foreignId": "your-unique-id"
  }'
```

### Individual account

```bash
curl -X POST "https://api.moov.io/accounts" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "accountType": "individual",
    "profile": {
      "individual": {
        "name": {
          "firstName": "Jane",
          "lastName": "Doe"
        },
        "email": "jane@example.com"
      }
    }
  }'
```

### Request capabilities

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/capabilities" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "capabilities": [
      "transfers",
      "send-funds.ach",
      "collect-funds.ach",
      "wallet.balance"
    ]
  }'
```

**Capability reference:**

| Capability | What it enables |
|-----------|----------------|
| `transfers` | Participate in any transfer |
| `wallet.balance` | Hold funds in wallet |
| `collect-funds.ach` | Accept ACH debit |
| `collect-funds.card-payments` | Accept card payments |
| `send-funds.ach` | ACH credits (standard + same-day) |
| `send-funds.instant-bank` | Real-time payouts (RTP/FedNow) |
| `send-funds.push-to-card` | Instant card payouts |
| `card-issuing` | Virtual prepaid cards |

## Hosted Onboarding

Moov offers two approaches to merchant onboarding:

- **Hosted** (default): Generate a link, send it to the merchant, and they complete KYC/KYB in a co-branded form. No custom UI needed.
- **Embedded**: Use the `<moov-onboarding>` Drop to embed the full onboarding flow inside your existing app (see Moov.js / Drops section). Or build fully custom forms and call the accounts, capabilities, and representatives APIs directly.

### How hosted onboarding works

1. Your server calls `POST /onboarding-invites` with capabilities, fee plan, and optional pre-filled data
2. Moov returns a secure link with a unique code
3. Send the link to the merchant — they create a Moov account, verify identity, and accept terms
4. Merchant is redirected to your `returnURL` when done
5. You manage the merchant's account and move money on their behalf

### Create an onboarding invite

```bash
curl -X POST "https://api.moov.io/onboarding-invites" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "capabilities": ["transfers", "wallet.balance", "collect-funds.ach", "collect-funds.card-payments"],
    "feePlanCodes": ["your-fee-plan"],
    "scopes": ["accounts.read", "accounts.write"],
    "returnURL": "https://your-app.com/onboarding-complete",
    "termsOfServiceURL": "https://your-app.com/terms",
    "prefill": {
      "accountType": "business",
      "profile": {
        "business": {
          "legalBusinessName": "Merchant Corp",
          "businessType": "llc",
          "email": "contact@merchant.com"
        }
      },
      "foreignID": "your-internal-merchant-id"
    }
  }'
```

### Key details

- **Pre-fill**: Pass merchant data you already have (name, email, address) so they don't re-enter it
- **Capabilities & fee plan**: Specified in the invite — merchant sees pricing disclosure and agrees
- **Co-branded**: Customize with your logo, accent colors, and company name via `POST /accounts/{accountID}/branding`
- **Resumable**: Merchants can start, pause, and finish the form at their own pace
- **Business accounts**: Must provide owners, control officers, and supporting documents
- **Manage invites**: `GET /onboarding-invites` to list, `DELETE /onboarding-invites/{code}` to revoke

## Resolution Links

When a connected account has verification issues after initial onboarding (failed KYC, missing documents, incorrect data), **do not rebuild the verification flow.** Send a resolution link instead — a temporary, secure hosted page where the user corrects their information.

### Create a resolution link

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/resolution-links" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00"
```

Response includes a hosted URL (`https://moov.link/r/{code}`). The user receives an MFA code via email/phone to verify identity before accessing the form.

### Key details

- **Auto-expire**: Links expire after 30 days
- **One per account**: Only one active resolution link per account at a time
- **Check what's needed**: `GET /accounts/{accountID}/capabilities` — look at `requirements.currentlyDue` to see what verification items are outstanding
- **Manage links**: `GET /resolution-links` to list, `DELETE /resolution-links/{code}` to disable


# Moov Payment Sources

## Bank Accounts

### Link a bank account

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/bank-accounts" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "account": {
      "accountNumber": "0004321567000",
      "bankAccountType": "checking",
      "holderName": "Jane Doe",
      "holderType": "individual",
      "routingNumber": "123456789"
    }
  }'
```

### Verify with micro-deposits

1. **Initiate**: POST `/accounts/{accountID}/bank-accounts/{bankAccountID}/verify`
2. Moov sends $0.01 with a 4-digit code in the descriptor (`MV{code}`)
3. **Complete**: PUT `/accounts/{accountID}/bank-accounts/{bankAccountID}/verify` with the code
4. User has 14 days and 5 attempts

## Cards

**Never handle raw card numbers on your server.** Regardless of hosted or embedded approach, use Moov.js Drops to collect card data in a secure iframe — card numbers go directly to Moov and never touch your server. The direct API (`POST /accounts/{accountID}/cards`) requires PCI compliance attestation.

- **Hosted**: Use Payment Links — the customer enters card details in the hosted flow.
- **Embedded**: Use the `<moov-card-link>` Drop or Composable Drops in your own UI (see Moov.js / Drops section).

### Link a card (direct API — requires PCI compliance)

```bash
curl -X POST "https://api.moov.io/accounts/{accountID}/cards" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "cardNumber": "4111111111111111",
    "cardCvv": "123",
    "expiration": { "month": "01", "year": "28" },
    "holderName": "Jules Jackson",
    "billingAddress": {
      "addressLine1": "123 Main Street",
      "city": "Denver",
      "stateOrProvince": "CO",
      "postalCode": "80301",
      "country": "US"
    },
    "cardOnFile": true,
    "merchantAccountID": "merchant-account-uuid"
  }'
```

### Card verification

When a card is linked, Moov verifies with the card network automatically (CVV, billing address, cardholder name). The response includes a `cardVerification` object with match results (`match`, `noMatch`, `notChecked`). Always include `addressLine1` and `merchantAccountID` for better approval rates.

### Card-on-file and account updater

- **`cardOnFile: true`** — Saves card for future use and enrolls in automatic updates. Only set with explicit cardholder consent.
- **`merchantAccountID`** — The merchant authorized to store the card. Used for fraud context during verification. Merchant is billed for card updater fees.
- **Card Account Updater** — Automatically updates card details (new PAN, expiration) when the issuer reports changes. Requires Moov approval — contact support to enable. Subscribe to `card.autoUpdated` webhook for notifications.

### Card management

- **List**: `GET /accounts/{accountID}/cards`
- **Get**: `GET /accounts/{accountID}/cards/{cardID}`
- **Update**: `PATCH /accounts/{accountID}/cards/{cardID}` (expiration, CVV, billing address, holderName)
- **Disable**: `DELETE /accounts/{accountID}/cards/{cardID}`

### Push-to-card and pull-from-card eligibility

Before using a card for push-to-card (payouts) or pull-from-card (instant funding), check eligibility via `GET /accounts/{accountID}/cards/{cardID}`:

| Field | Values | Meaning |
|-------|--------|---------|
| `domesticPushtoCard` | `fast-funds`, `standard`, `not-supported`, `unknown` | Payout eligibility |
| `domesticPullfromCard` | `supported`, `not-supported`, `unknown` | Instant funding eligibility |

**Push-to-card limits**: $50,000/transaction. Per-card velocity: 150 txns/$100K per day, 250/$250K per 7 days, 750/$500K per 30 days.

**Pull-from-card**: Visa/Mastercard debit/prepaid only. $10,000/transaction. Card account name must match Moov account name. Requires Moov approval.

## Apple Pay

### Setup

1. **Register domain** in Moov Dashboard (per merchant account). Requires HTTPS with valid SSL, TLS 1.2+.
2. **Production only** — Apple Pay is not available in test mode.

### Integration flow

```javascript
// 1. Create Apple Pay session (server-side)
// POST /accounts/{accountID}/apple-pay/sessions
const session = await createApplePaySession(accountID);

// 2. Handle onmerchantvalidation in Payment Request API
paymentRequest.onmerchantvalidation = (event) => {
  event.complete(session.merchantSession);
};

// 3. Show payment sheet
const paymentResponse = await paymentRequest.show();

// 4. Link Apple Pay token to payer account (server-side)
// POST /accounts/{accountID}/apple-pay/tokens
// Returns paymentMethodID for use in transfers
const { paymentMethodID } = await linkApplePayToken(accountID, paymentResponse.details);

// 5. Create transfer using the apple-pay payment method
// Use X-Wait-For: rail-response for synchronous card network response

// 6. Complete payment sheet based on transfer result
if (transfer.source.cardDetails.status === 'confirmed') {
  paymentResponse.complete('success');
} else {
  paymentResponse.complete('fail');
}
```

### Key details

- Supported networks: Visa, Mastercard, Amex, Discover
- Set `requiredBillingContactFields` with `postalAddress` to avoid declines
- $100,000 per transaction limit

## Google Pay

Google Pay integration follows a similar pattern to Apple Pay:

1. Configure `PaymentsClient` with `gateway: 'moov'` and `gatewayMerchantId` set to the merchant's Moov account ID
2. Supported auth methods: `PAN_ONLY`, `CRYPTOGRAM_3DS`
3. Supported networks: Visa, Mastercard, Amex, Discover
4. Require `billingAddressRequired: true` with `format: 'FULL'`
5. Link Google Pay token via `POST /accounts/{accountID}/google-pay/tokens` — returns `paymentMethodID`
6. Create transfer using the `google-pay` payment method

## Wallets

Wallets are auto-created when `wallet.balance` capability is active. To get the wallet payment method ID:

```bash
# List payment methods, filter for moov-wallet type
curl -X GET "https://api.moov.io/accounts/{accountID}/payment-methods" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00"
```

## Moov.js / Drops

Moov provides pre-built, PCI-compliant UI components called **Drops** that handle sensitive data collection in secure iframes. Card numbers, bank accounts, and PII go directly to Moov — never through your server.

**Embedded integration developers**: Drops are your primary tool. Instead of building custom card input forms or bank linking flows, embed Drops directly in your existing app for PCI-compliant data collection with full control over the surrounding UX.

### Installation

```html
<!-- Script tag -->
<script type="text/javascript" src="https://js.moov.io/v1"></script>
```

```bash
# Or npm
npm install @moovio/moov-js
```

**Requires HTTPS.** Use ngrok, Netlify, or Vercel for local development.

### Available Drops

| Drop | What it does |
|------|-------------|
| `<moov-card-link>` | Card number, CVV, expiration input in a single secure component |
| `<moov-onboarding>` | Full account onboarding flow (KYC/KYB, representatives, payment methods) |
| `<moov-payment-methods>` | Register cards and/or bank accounts to an existing account |

### Card Link Drop

The recommended way to link cards. All card data is captured in an iframe and never touches your page.

```html
<moov-card-link></moov-card-link>

<script>
const cardInput = document.querySelector('moov-card-link');

// Required
cardInput.oauthToken = "token-with-accounts/{accountID}/cards.write-scope";
cardInput.accountID = "moov-account-id";

// Optional
cardInput.holderName = "Jules Jackson";
cardInput.billingAddress = { postalCode: "80301", country: "US" };
cardInput.cardOnFile = true;
cardInput.merchantAccountID = "merchant-account-uuid";
cardInput.allowedCardBrands = ["visa", "mastercard", "american-express"];

// Callbacks
cardInput.onSuccess = (result) => console.log(result.cardID);
cardInput.onError = (clientError, apiError) => {
  if (apiError.existingCardID) console.log("Duplicate card");
};

// Submit
cardInput.submit();
</script>
```

### Composable Drops (custom card layouts)

For more design control, use individual field components together:

```html
<moov-form name="card-form" method="POST" action="/accounts/{accountID}/cards">
</moov-form>

<moov-card-number-input formname="card-form" name="cardNumber" required>
</moov-card-number-input>

<moov-expiration-date-input formname="card-form" name="expiration" required>
</moov-expiration-date-input>

<moov-card-security-code-input formname="card-form" name="cvv" required>
</moov-card-security-code-input>

<moov-text-input formname="card-form" name="holderName" required>
</moov-text-input>

<moov-text-input formname="card-form" name="billingAddress.postalCode" required>
</moov-text-input>
```

Set `requestHeaders` on the form with `Authorization: Bearer {token}`. Handle `onSuccess` and `onError` callbacks on the form element.

### Onboarding Drop

Full account creation and verification flow. Handles business info, representatives, payment methods, and capability requirements.

```html
<moov-onboarding></moov-onboarding>

<script>
const onboarding = document.querySelector('moov-onboarding');
onboarding.token = initialToken;
onboarding.facilitatorAccountID = "your-platform-account-id";
onboarding.capabilities = ["transfers", "wallet.balance", "collect-funds.card-payments"];

// Pre-populate known data
onboarding.accountData = {
  profile: {
    business: {
      legalBusinessName: "Merchant Corp",
      email: "contact@merchant.com"
    }
  }
};

// CRITICAL: Update token when account is created mid-flow
onboarding.onResourceCreated = async (resourceType, resource) => {
  if (resourceType === "account") {
    const newToken = await generateToken([
      `/accounts/${resource.accountID}/profile.write`,
      `/accounts/${resource.accountID}/cards.write`,
      `/accounts/${resource.accountID}/bank-accounts.write`,
      `/accounts/${resource.accountID}/capabilities.write`,
      `/accounts/${resource.accountID}/representatives.write`,
      // ... include all needed scopes
    ]);
    onboarding.token = newToken;
  }
};

onboarding.onSuccess = () => console.log("Onboarding complete");
onboarding.open = true;
</script>
```

### Payment Methods Drop

Register cards and/or bank accounts on an existing account.

```html
<moov-payment-methods></moov-payment-methods>

<script>
const pm = document.querySelector('moov-payment-methods');
pm.token = token; // needs cards.write, bank-accounts.write, fed.read scopes
pm.accountID = "account-uuid";
pm.paymentMethodTypes = ["card", "bankAccount"]; // or just one
pm.onSuccess = (result) => console.log("Linked:", result);
pm.open = true;
</script>
```

Supports Plaid integration for bank account verification — pass a `plaid` configuration object.

### Theming

Customize all Drops with CSS variables:

```css
:root {
  --moov-color-background: #ffffff;
  --moov-color-primary: #0066cc;
  --moov-color-danger: #cc0000;
  --moov-color-high-contrast: #111111;
  --moov-radius-small: .375rem;
  --moov-radius-large: .5rem;
}
```


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


# Moov Issuing

## Card Issuing

### Create a virtual card

```bash
curl -X POST "https://api.moov.io/issuing/{accountID}/issued-cards" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00" \
  --data-raw '{
    "authorizedUser": {
      "firstName": "Jane",
      "lastName": "Doe"
    },
    "fundingWalletID": "{walletID}",
    "formFactor": "virtual",
    "controls": {
      "singleUse": false,
      "velocityLimits": [{
        "amount": 10000,
        "interval": "per-transaction"
      }]
    }
  }'
```

- `fundingWalletID`: Wallet that funds the card. Must have `card-issuing` capability.
- `singleUse: true`: Card closes after first successful authorization.
- `velocityLimits.amount`: In cents. `10000` = $100.00 per transaction.

### Get full card details (PCI)

```bash
curl -X GET "https://api.moov.io/issuing/{accountID}/issued-cards/{cardID}/full-card-number" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.01.00"
```

Returns PAN, CVV, expiration. Handle with PCI compliance.

## Tap to Pay

Accept contactless card payments using a phone — no extra hardware needed. Available for **iPhone** (XS or newer, iOS 16+) and **Android** (10+, NFC required).

### Setup flow

1. **Register terminal application**: `POST /terminal-applications` with your app's platform and bundle ID
2. **Wait for approval**: Subscribe to `terminalAppRegistration.updated` webhook — status moves `pending` → `enabled`
3. **Link to merchant**: `POST /accounts/{accountID}/terminal-applications` to associate the app with a merchant account

### Integration

- **iOS**: Add `MoovKit` via Swift Package Manager (`https://github.com/moovfinancial/moov-ios`). Requires Apple proximity reader entitlement.
- **Android**: Use `MoovSDK`. Call `MoovSDK.onApplicationCreated(this)` in `Application.onCreate()`. Requires Google Play Store strong integrity checks.

### Creating a transfer

Both platforms offer two paths:

1. **Direct transfer** — SDK handles tap + transfer in one call (`createTapTransfer`)
2. **Authorization + transfer** — SDK handles tap (`createTapAuthorization`), your backend creates the transfer. Authorization expires — create the transfer promptly.

### Key details

- Test mode uses simulated card selection (no physical tap needed)
- Prevent screen/app from sleeping during transactions
- Turn off developer mode on production devices

