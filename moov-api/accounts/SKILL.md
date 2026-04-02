---
name: Moov Accounts
description: Account creation, capabilities, hosted onboarding, and resolution links on the Moov platform.
---

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
