---
name: Moov Payment Sources
description: Bank accounts, cards, Apple Pay, Google Pay, wallets, and Moov.js/Drops UI components on the Moov platform.
---

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
