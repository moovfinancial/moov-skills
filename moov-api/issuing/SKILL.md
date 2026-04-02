---
name: Moov Issuing
description: Card issuing and tap to pay on the Moov platform.
---

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
