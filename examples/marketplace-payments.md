# Marketplace Payments

## Context

A two-sided marketplace (e.g., a freelance platform) that connects buyers with sellers. Buyers pay for services with a credit card, the platform takes a fee, and sellers receive payouts to their bank account on a weekly basis. Sellers complete onboarding through a hosted flow and manage their own payout preferences.

## Prompt

I'm building a freelance services marketplace. Buyers hire sellers for projects, pay with a credit card, and the platform takes a 10% fee. Sellers receive weekly ACH payouts to their bank account.

**Users:** Sellers (business or individual accounts) who provide services. Buyers (individuals) who pay for services with a card.

**Flows I need:**
1. **Seller onboarding** — When a seller signs up, I already have their name and email. Send them a hosted onboarding flow where they complete identity verification, agree to pricing, and add a bank account for payouts. I don't want to build custom KYC forms.
2. **Buyer card payments** — When a buyer hires a seller and the project is complete, charge the buyer's card. The buyer links their card using a secure, PCI-compliant component in my existing app (I have a React frontend). Card data should never touch my server.
3. **Split payments** — When the buyer pays, 90% goes to the seller's Moov wallet and 10% stays in the platform's wallet as a fee. Don't create separate transfers — use a single transfer with a platform fee.
4. **Weekly seller payouts** — Sellers accumulate funds in their Moov wallet throughout the week. Every week, automatically sweep their wallet balance to their linked bank account via same-day ACH. I don't want to build a custom payout scheduler.
5. **Webhooks** — Track card payment status, seller onboarding completion, and sweep status.

Build me a step-by-step integration plan using the Moov API. For each step, show me the API call or tell me which Moov feature to use. Don't build custom solutions for things Moov handles natively.

## What the AI should generate

- Hosted onboarding invite for sellers with capabilities: `transfers`, `wallet.balance`, `collect-funds.card-payments`, `send-funds.ach`
- Buyer account creation and card linking using the `<moov-card-link>` Drop (PCI-compliant iframe)
- Transfer from buyer's card to seller's wallet using transfer groups: parent transfer for full amount, child transfer for the seller's 90% (platform keeps 10%)
- Sweep configuration on seller accounts for weekly ACH payouts (`ach-credit-same-day`)
- Webhook subscriptions for `transfer.updated`, `capability.updated`, `sweep.updated`
- Token generation pattern: server-side token for buyer's card scope, separate token for transfer creation
