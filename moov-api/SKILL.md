---
name: Moov API Core
description: Mental model, authentication, API versioning, hosted vs embedded approach, common errors, card failure codes, SDKs, webhooks, MCP server, and test mode for the Moov platform.
---

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
