---
name: Moov Agent Security
description: Cryptographic agent identity verification, message signing, and sanctions screening for AI agents interacting with Moov payment APIs. Uses MCPS (MCP Secure) and AgentPass -- already integrated in moov-io/watchman.
---

# Moov Agent Security Skill

You are an expert at securing AI agent interactions with Moov payment infrastructure. Use these patterns to add cryptographic identity verification, message signing, and sanctions screening to any Moov integration where autonomous agents initiate payments, transfers, or account operations.

**This skill complements the core Moov API skills.** Apply it whenever an AI agent (not a human) is calling Moov APIs.

## When to Apply This Skill

Apply these patterns when:
- An AI agent is initiating transfers, issuing cards, or managing accounts
- You need to prove WHICH agent performed an action (audit/compliance)
- You need tamper-evident records of payment operations
- You need sanctions screening before money movement
- You need to satisfy SOC 2, PSD2, or FCA audit requirements for agent-initiated transactions

## Architecture

```
AI Agent
  |-- AgentPass identity (X.509 cert, trust level L0-L4)
  |
  v
Agent Security Layer (this skill)
  |-- Verify agent identity
  |-- Check trust level >= required minimum
  |-- Screen sanctions (via Watchman)
  |-- Sign request (MCPS)
  |
  v
Moov API (transfers, issuing, accounts)
  |
  v
Agent Security Layer
  |-- Sign response (MCPS)
  |-- Append to hash-chained audit trail
  |
  v
AI Agent receives signed, tamper-evident response
```

## Agent Identity Verification

Every agent interacting with Moov APIs must present an identity. AgentPass uses X.509 certificates with embedded trust levels and capability scopes.

### Trust Levels

| Level | Name | Allowed Operations |
|-------|------|--------------------|
| L0 | Untrusted | None -- blocked from all Moov APIs |
| L1 | Basic | Read-only (account info, balance checks) |
| L2 | Verified | Standard operations (transfers, card issuance) |
| L3 | Trusted | High-value operations (bulk transfers, large amounts) |
| L4 | Audited | Full access (compliance reports, account management) |

### Verify Agent Before Moov API Call

```javascript
const crypto = require('crypto');

function verifyAgent(req) {
  const certPem = req.headers['x-agentpass-certificate'];
  if (!certPem) return { verified: false, reason: 'No agent certificate' };

  const cert = new crypto.X509Certificate(Buffer.from(certPem, 'base64'));

  // Check cert is valid and chains to trusted CA
  if (cert.validTo < new Date()) return { verified: false, reason: 'Certificate expired' };

  // Extract trust level from cert subject
  const trustLevel = parseInt(cert.subject.match(/L(\d)/)?.[1] || '0');
  const agentId = cert.subject.match(/CN=([^,]+)/)?.[1] || 'unknown';

  return { verified: true, agentId, trustLevel, cert };
}

// Usage in Moov integration
app.post('/api/moov/transfer', async (req, res) => {
  const agent = verifyAgent(req);
  if (!agent.verified) return res.status(401).json({ error: agent.reason });
  if (agent.trustLevel < 2) return res.status(403).json({ error: 'Minimum L2 required for transfers' });

  // Agent verified -- proceed with Moov API call
  const transfer = await moov.transfers.create({
    source: { paymentMethodID: req.body.sourcePaymentMethodID },
    destination: { paymentMethodID: req.body.destPaymentMethodID },
    amount: { value: req.body.amount, currency: 'USD' }
  });

  // Sign response with MCPS
  const signed = mcpsSign({ event: 'transfer', agentId: agent.agentId, transferId: transfer.transferID });
  res.json({ transfer, mcps: signed });
});
```

### Go (for moov-go SDK users)

```go
import (
    agentpass "github.com/razashariff/agentpass-go"
)

func verifyAgentMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        certHeader := r.Header.Get("X-AgentPass-Certificate")
        if certHeader == "" {
            http.Error(w, "Agent certificate required", 401)
            return
        }

        result, err := agentpass.VerifyCertificate(certHeader, trustAnchorPath)
        if err != nil || result.TrustLevel < 2 {
            http.Error(w, "Insufficient trust level", 403)
            return
        }

        // Agent verified -- attach to context
        ctx := context.WithValue(r.Context(), "agent", result)
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}
```

**Note:** `agentpass-go` is already a dependency in moov-io/watchman (PR #733, merged).

## MCPS Message Signing

Every Moov API response that carries financial data must be signed. MCPS creates a tamper-evident envelope around the response.

### Sign a Moov API Response

```javascript
const crypto = require('crypto');

function mcpsSign(payload) {
  const canonical = JSON.stringify(payload);
  const nonce = crypto.randomBytes(8).toString('hex');
  const timestamp = new Date().toISOString();

  const signData = canonical + nonce + timestamp;
  const signature = crypto.createHmac('sha256', process.env.MCPS_SIGNING_KEY)
    .update(signData)
    .digest('hex');

  return {
    payload,
    mcps: {
      signature,
      nonce,
      timestamp,
      algorithm: 'HMAC-SHA256'
    }
  };
}
```

### ECDSA Signing (Production)

```javascript
const { sign } = require('crypto');

function mcpsSignECDSA(payload, privateKeyPem) {
  const canonical = JSON.stringify(payload);
  const nonce = crypto.randomBytes(8).toString('hex');
  const timestamp = new Date().toISOString();

  const signer = crypto.createSign('SHA256');
  signer.update(canonical + nonce + timestamp);
  const signature = signer.sign(privateKeyPem, 'hex');

  return {
    payload,
    mcps: { signature, nonce, timestamp, algorithm: 'ECDSA-P256-SHA256' }
  };
}
```

### Verify a Signed Response (Agent Side)

```javascript
function mcpsVerify(envelope, publicKeyPem) {
  const { payload, mcps } = envelope;
  const canonical = JSON.stringify(payload);
  const verifier = crypto.createVerify('SHA256');
  verifier.update(canonical + mcps.nonce + mcps.timestamp);
  return verifier.verify(publicKeyPem, mcps.signature, 'hex');
}
```

## Sanctions Screening

Before any money movement, screen the counterparty against sanctions lists. Use the customer's own moov-io/watchman instance.

### Screen Before Transfer

```javascript
const http = require('http');

async function screenSanctions(name, watchmanUrl) {
  const url = `${watchmanUrl}/search?q=${encodeURIComponent(name)}&limit=5`;
  const res = await fetch(url);
  const data = await res.json();

  const matches = (data.SDNs || []).filter(m => m.match > 0.8);
  return { clear: matches.length === 0, matches };
}

// Usage
app.post('/api/moov/transfer', async (req, res) => {
  const agent = verifyAgent(req);
  if (!agent.verified) return res.status(401).json({ error: agent.reason });

  // Screen recipient before moving money
  const screen = await screenSanctions(req.body.recipientName, process.env.WATCHMAN_URL);
  if (!screen.clear) {
    return res.status(403).json({ error: 'Sanctions match', matches: screen.matches });
  }

  // Proceed with transfer...
});
```

### Watchman Configuration

```bash
# Customer runs their own Watchman instance
WATCHMAN_URL=http://localhost:8084

# Or use moov-io/watchman with MCPS + AgentPass enabled (v0.62.0+)
# See: https://github.com/moov-io/watchman/pull/730 (MCPS signing)
# See: https://github.com/moov-io/watchman/pull/733 (AgentPass identity)
```

## Audit Trail

Every agent-initiated Moov operation must be logged to a hash-chained audit trail.

### Append to Audit Log

```javascript
let lastHash = '0';

function auditLog(event) {
  const entry = {
    ...event,
    timestamp: new Date().toISOString(),
    previousHash: lastHash
  };

  const hash = crypto.createHash('sha256')
    .update(JSON.stringify(entry))
    .digest('hex');

  entry.hash = hash;
  lastHash = hash;

  // Append to audit store
  fs.appendFileSync('audit.jsonl', JSON.stringify(entry) + '\n');

  return entry;
}

// Usage after every Moov API call
auditLog({
  event: 'transfer_created',
  agentId: agent.agentId,
  trustLevel: agent.trustLevel,
  transferId: transfer.transferID,
  amount: transfer.amount,
  sanctionsCleared: true,
  mcpsSignature: signed.mcps.signature
});
```

### Export for Compliance

```javascript
// JSON export
app.get('/api/audit/export', (req, res) => {
  const log = fs.readFileSync('audit.jsonl', 'utf8')
    .split('\n').filter(Boolean).map(JSON.parse);
  res.json({ count: log.length, entries: log });
});

// Syslog RFC 5424 export
app.get('/api/audit/syslog', (req, res) => {
  const log = fs.readFileSync('audit.jsonl', 'utf8')
    .split('\n').filter(Boolean).map(JSON.parse);
  const syslog = log.map(e =>
    `<14>1 ${e.timestamp} agentpass ${e.event} - - - agent=${e.agentId} amount=${e.amount || '-'} sig=${e.mcpsSignature || '-'}`
  ).join('\n');
  res.type('text/plain').send(syslog);
});
```

## Moov Issuing with Agent Security

When issuing cards to agents via Moov's issuing API, apply identity verification and spend controls.

### Issue Card to Verified Agent

```javascript
app.post('/api/moov/issue-card', async (req, res) => {
  const agent = verifyAgent(req);
  if (!agent.verified) return res.status(401).json({ error: agent.reason });
  if (agent.trustLevel < 2) return res.status(403).json({ error: 'L2+ required for card issuance' });

  // Screen agent name against sanctions
  const screen = await screenSanctions(agent.agentId, process.env.WATCHMAN_URL);
  if (!screen.clear) return res.status(403).json({ error: 'Sanctions match' });

  // Issue via Moov API
  const card = await moov.issuing.createCard(req.body.accountID, {
    authorizedUser: { firstName: 'Agent', lastName: agent.agentId },
    fundingWalletID: req.body.walletID,
    formFactor: 'virtual',
    controls: {
      velocityLimits: [{
        amount: agent.trustLevel >= 3 ? 100000 : 10000,
        interval: 'per-transaction'
      }]
    }
  });

  // Sign and log
  const signed = mcpsSign({ event: 'card_issued', agentId: agent.agentId, cardId: card.issuedCardID });
  auditLog({ event: 'card_issued', agentId: agent.agentId, cardId: card.issuedCardID, trustLevel: agent.trustLevel });

  res.json({ card, mcps: signed.mcps });
});
```

## Integration with Existing Moov Skills

This security skill wraps the patterns from the core Moov skills:

| Moov Skill | + Agent Security |
|------------|-----------------|
| `money-movement` | Verify agent identity + screen sanctions before transfer |
| `issuing` | Verify agent + set trust-based spend limits |
| `accounts` | Verify agent before account creation/modification |
| `commerce` | Sign all checkout/payment responses |
| `payment-sources` | Audit trail for all payment source operations |

## References

- [MCPS signing in Watchman (PR #730)](https://github.com/moov-io/watchman/pull/730)
- [AgentPass identity in Watchman (PR #733)](https://github.com/moov-io/watchman/pull/733)
- [OWASP MCP Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/MCP_Security_Cheat_Sheet.html)
- [OpenAPI x-agent-trust Extension](https://spec.openapis.org/registry/extension/x-agent-trust.html)
- [agentpass-go SDK](https://github.com/razashariff/agentpass-go) (Apache 2.0, zero deps)
- [AgentPass Platform](https://agentpass.co.uk)

---
Raza Sharif, CyberSecAI Ltd -- raza.sharif@outlook.com | contact@agentsign.dev
