# Rental Property Management

## Context

A rental property management platform that connects property management companies with tenants. Property managers sign up, complete KYC/KYB, and receive rent payments. Tenants pay monthly rent via ACH and receive invoices for variable charges like cleaning fees and maintenance.

## Prompt

I'm building a rental property management platform. I need to collect rent from tenants and send payouts to property managers.

**Users:** Property management companies (merchants) who receive rent. Tenants (individuals) who pay rent and occasional fees.

**Flows I need:**
1. **Merchant onboarding** — Property management companies sign up on my platform. I already have their business name and email. I need them to complete KYC/KYB verification and agree to pricing. I want a hosted flow, not custom identity verification forms.
2. **Tenant accounts** — When a tenant signs a lease, create an account for them and collect their payment method (bank account for ACH, or card).
3. **Monthly rent** — Fixed amount, collected on the 1st of every month via ACH debit from the tenant's bank account to the property manager's Moov wallet. This should be automated, not a custom scheduler.
4. **Variable charges** — Cleaning fees, maintenance charges, early check-in fees. One-off, variable amounts. Send the tenant an itemized bill they can pay online with card or bank transfer.
5. **Webhooks** — Track payment status and invoice status to update my database.

Build me a step-by-step integration plan using the Moov API. For each step, show me the API call or tell me which Moov feature to use. Don't build custom solutions for things Moov handles natively.

## What the AI should generate

- Hosted onboarding invite for property management companies (`POST /onboarding-invites`)
- Account creation for tenants with bank account linking
- Scheduled recurring transfers using RRULE (`POST /accounts/{accountID}/schedules` with `FREQ=MONTHLY`)
- Invoices for variable charges (`POST /accounts/{accountID}/invoices`)
- Webhook subscriptions for `transfer.updated`, `invoice.updated`, and related events
- Sweep configuration for property manager payouts to their bank account
