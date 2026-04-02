# Logistics Disbursements

## Context

A logistics platform that connects shipping companies with owner-operator truckers. When a trucker completes a load delivery, the platform confirms the load and needs to pay the trucker. Truckers prefer instant payouts to their debit card, with ACH as a fallback for truckers without eligible cards.

## Prompt

I'm building a logistics platform that connects shipping companies with owner-operator truckers. When a trucker completes a load delivery, the platform needs to pay them out.

**Users:** Shipping companies (business accounts/merchants) who post loads. Owner-operator truckers (individuals) who deliver loads and receive payouts.

**Flows I need:**
1. **Shipping company onboarding** — Shipping companies sign up on my platform. I already have their business name and email. I need them to complete KYC/KYB verification and agree to pricing. I want a hosted flow, not custom identity verification forms.
2. **Trucker payouts** — When a trucker completes a delivery, my platform confirms the load and needs to send payment. Truckers should receive a link where they verify their identity, add their debit card or bank account, and get paid. I want a hosted disbursement flow, not a custom UI for collecting trucker payment methods. Instant payouts to debit cards are preferred, with ACH as a fallback.
3. **Track disbursement status** — I need to know when a payout link is completed and funds are sent so I can update the load status in my system.

Build me a step-by-step integration plan using the Moov API. For each step, show me the API call or tell me which Moov feature to use. Don't build custom solutions for things Moov handles natively.

## What the AI should generate

- Hosted onboarding invite for shipping companies (`POST /onboarding-invites`)
- Payout links for trucker disbursements (`POST /accounts/{accountID}/payment-links` in payout mode)
- Payout link configuration with `push-to-card` and `ach-credit-same-day` as allowed methods
- Line items showing the load details (route, load number, amount)
- Webhook subscriptions for `payment-link.completed` and `transfer.updated`
- Sweep configuration for the shipping company's wallet
