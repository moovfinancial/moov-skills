---
name: Moov Issuing
description: Card issuing and tap to pay on the Moov platform.
---

# Moov Issuing

## Card Issuing

Card issuing is in closed beta. Moov issues virtual Visa spending cards that spend from the business account's card-issuing wallet. That wallet is created automatically when the account has the `card-issuing` capability; fund it with a wallet-to-wallet transfer. Guide: https://docs.moov.io/guides/issue-cards/

### Endpoints

| Method | Path | Use |
|--------|------|-----|
| POST | `/issuing/{accountID}/cards` | Issue a virtual card |
| GET | `/issuing/{accountID}/cards` | List cards (filter with `?states=active,frozen`) |
| GET / PATCH | `/issuing/{accountID}/cards/{issuedCardID}` | Get, or change state / controls / nickname |
| GET | `/issuing/{accountID}/cards/{issuedCardID}/details` | PAN, CVV, expiration (PCI; needs `issued-cards.read-private` scope) |
| GET | `/issuing/{accountID}/authorizations[/{authorizationID}[/events]]` | Authorizations and their event history |
| GET | `/issuing/{accountID}/card-transactions[/{cardTransactionID}]` | Card transactions |
| GET | `/issuing/merchant-categories` | Merchant category groups for controls |

There are no `/issued-cards` or `/full-card-number` paths.

### Issue a virtual card

```bash
curl -X POST "https://api.moov.io/issuing/{accountID}/cards" \
  -H "Authorization: Bearer {token}" \
  -H "x-moov-version: v2026.07.00" \
  --data-raw '{
    "authorizedUserAccountID": "{authorizedUserAccountID}",
    "nickname": "Marketing card",
    "controls": {
      "singleUse": false,
      "velocityLimits": [{
        "amount": 10000,
        "interval": "per-transaction"
      }]
    }
  }'
```

- No funding wallet or form factor field: cards are virtual and always spend from the card-issuing wallet
- `singleUse: true`: card closes after its first authorization
- `velocityLimits[].amount` is in cents (`10000` = $100.00); intervals are `per-transaction`, `daily`, `weekly`, `monthly`, one limit per interval
- Other controls: `merchantCategoryRestrictions`, `merchantRestrictions`, `allowedSchedule`, `expiresOn` (see the spec for shapes)

### Card states

`active` → `frozen` → `active` as often as needed; `closed` is terminal (by request or expiry). Freeze or close with PATCH:

```json
{ "state": "frozen" }
```

PATCH `controls` replaces each control you send in full; send `null` to remove one (e.g. `"merchantRestrictions": null`), `[]` to clear `velocityLimits`.

### Authorizations and declines

- Authorization `status`: `pending`, `declined`, `canceled`, `cleared`, `expired`
- A `declined` authorization carries a `declineReason`. Handle at least: `insufficient-funds`, `card-not-active`, `spend-limit-exceeded`, `merchant-category-restricted`, `merchant-restricted`, `outside-allowed-schedule`, `spend-cutoff-reached`
- There are no issuing webhooks for cards or authorizations yet. Poll the authorizations and card-transactions endpoints for changes

### Test mode simulations

Simulation endpoints need `X-Moov-Version: v2026.10.00` (they don't exist in v2026.07.00) and test-mode keys. Docs: https://docs.moov.io/guides/get-started/test-mode/#spending-card-simulations

| Simulate | Endpoint | Body |
|----------|----------|------|
| Authorization | POST `/issuing/simulations/{accountID}/authorizations` | `issuedCardID`, `amount` (decimal string, e.g. `"50.00"`), optional `merchantData` |
| Clearing | POST `/issuing/simulations/{accountID}/authorizations/{authorizationID}/clearings` | optional `amount`; omit to clear the remaining hold |
| Reversal | POST `/issuing/simulations/{accountID}/authorizations/{authorizationID}/reversals` | none |

- Simulation `amount` is a dollar string (`"50.00"`), not cents, unlike card controls
- `200` returns the result; `202` returns only `authorizationID` — the result isn't ready yet, so GET the authorization until it appears. Don't treat 202 as an error or retry the POST
- Reversals only work on `pending` authorizations; clearings fail on `declined` ones; a clearing without `amount` needs a `pending` authorization. Breaking these rules returns an error, not a bug
- There is no magic amount for declines. To test one, simulate against a card that should decline: `frozen` (expect `card-not-active`) or with a velocity limit below the amount (expect `spend-limit-exceeded`)

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
