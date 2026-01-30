# BODA CONNECT - Security Policy

**Version:** 1.0.0
**Last Updated:** January 2026
**Classification:** Internal / Confidential

---

## Table of Contents
1. [Overview](#overview)
2. [Security Architecture](#security-architecture)
3. [Authentication & Access Control](#authentication--access-control)
4. [Data Protection](#data-protection)
5. [Network Security](#network-security)
6. [Monitoring & Alerting](#monitoring--alerting)
7. [Incident Response](#incident-response)
8. [Compliance](#compliance)
9. [Security Contacts](#security-contacts)

---

## Overview

Boda Connect is committed to protecting user data and maintaining the highest security standards. This document outlines our security policies, procedures, and controls aligned with SOC 2 Trust Service Criteria.

### Scope
- Mobile applications (iOS, Android)
- Web application
- Backend services (Firebase, Cloud Functions)
- Administrative interfaces

### Security Principles
1. **Defense in Depth** - Multiple layers of security controls
2. **Least Privilege** - Minimum access necessary
3. **Zero Trust** - Verify explicitly, assume breach
4. **Encryption by Default** - Data encrypted at rest and in transit

---

## Security Architecture

### Technology Stack Security

| Component | Security Measures |
|-----------|-------------------|
| **Firebase Auth** | Phone OTP, Email/Password, Google OAuth, Session management |
| **Cloud Firestore** | Security rules, Field-level access control, Encryption |
| **Cloud Storage** | Access control rules, File type validation, Size limits |
| **Cloud Functions** | Admin SDK, Role-based access, Rate limiting |
| **Client Apps** | Secure storage, Certificate pinning, Input validation |

### Security Services

```
┌─────────────────────────────────────────────────────────────┐
│                    BODA CONNECT SECURITY                      │
├─────────────────────────────────────────────────────────────┤
│  audit_service.dart          - SOC 2 compliant audit logging │
│  security_service.dart       - Session & account management  │
│  rate_limiter_service.dart   - Brute force protection        │
│  encryption_service.dart     - AES-256 encryption            │
│  device_fingerprint_service  - Trusted device tracking       │
│  geolocation_security_service - Impossible travel detection  │
│  transaction_verification    - High-value transaction auth   │
│  app_check_service.dart      - Abuse protection              │
└─────────────────────────────────────────────────────────────┘
```

---

## Authentication & Access Control

### Authentication Methods

| Method | Use Case | Security Level |
|--------|----------|----------------|
| **Phone OTP (SMS)** | Primary for Angola/Portugal | High |
| **Phone OTP (WhatsApp)** | Primary alternative | High |
| **Email + Password** | Secondary option | Medium-High |
| **Google OAuth** | Quick sign-up | High |
| **Step-up SMS** | High-value transactions | Critical |

### Password Policy
- Minimum 8 characters
- Must include: uppercase, lowercase, number
- Special characters recommended
- Password strength indicator (weak/medium/strong)
- No common patterns (123, abc, qwerty)

### Session Management
- **Idle timeout:** 30 minutes
- **Max concurrent sessions:** 3 per user
- **Token refresh:** Every 15 minutes
- **Session termination:** On logout, password change, or suspicious activity

### Account Locking
- **Trigger:** 5 failed login attempts in 5 minutes
- **Duration:** 15 minutes automatic, manual unlock by admin
- **Notification:** User notified via email/SMS

### Multi-Factor Authentication
- SMS OTP for high-value transactions (>100,000 AOA)
- Required for: withdrawals, account changes, data export, deletion
- Code validity: 5 minutes

---

## Data Protection

### Encryption Standards

| Data Type | At Rest | In Transit |
|-----------|---------|------------|
| User credentials | Firebase Auth (bcrypt) | TLS 1.3 |
| Personal data | Firestore encryption | TLS 1.3 |
| Payment data | AES-256-CBC | TLS 1.3 |
| Documents | Firebase Storage encryption | TLS 1.3 |
| Audit logs | Firestore encryption | TLS 1.3 |

### Data Classification

| Classification | Description | Examples |
|----------------|-------------|----------|
| **Critical** | Financial, authentication | Payment methods, passwords |
| **Confidential** | PII, business data | Names, emails, phone numbers |
| **Internal** | Operational data | Bookings, reviews, logs |
| **Public** | Publicly accessible | Supplier profiles, packages |

### Data Masking
- Card numbers: `**** **** **** 1234`
- Phone numbers: `+244 923 *** ***`
- Bank accounts: `****.1234`

### Data Retention
- **Active accounts:** Indefinite
- **Deleted accounts:** 30 days grace period
- **Audit logs:** 7 years (compliance)
- **Session data:** 90 days

### GDPR Compliance
- **Right to Access:** `exportUserData` Cloud Function
- **Right to Erasure:** `deleteUserData` Cloud Function
- **Data Portability:** JSON export of all user data
- **Consent:** Explicit consent at registration

---

## Network Security

### TLS Configuration
- Minimum TLS 1.2, recommended TLS 1.3
- Strong cipher suites only
- Certificate validation enforced

### API Security
- Firebase App Check for abuse protection
- Rate limiting on all endpoints
- Input validation and sanitization
- CORS configured for web

### Rate Limits

| Endpoint | Limit | Window | Lockout |
|----------|-------|--------|---------|
| Login | 5 attempts | 5 min | 15 min |
| OTP Request | 3 attempts | 1 min | 5 min |
| OTP Verify | 5 attempts | 5 min | 30 min |
| API Calls | 100 requests | 1 min | 1 min |
| Messages | 20 messages | 1 min | 5 min |
| Bookings | 10 bookings | 1 hour | 1 hour |

### Firewall Rules (Firestore)
- All paths require authentication except public supplier data
- Admin functions require `role: 'admin'` in user document
- Audit logs are append-only (immutable)
- Owner-only access for sensitive collections

---

## Monitoring & Alerting

### Audit Logging
All security-relevant events are logged to `audit_logs` collection:

| Category | Events |
|----------|--------|
| **Authentication** | Login, logout, failed attempts, password changes |
| **Data Access** | Read, list, search, export operations |
| **Admin Actions** | Suspensions, approvals, role changes |
| **Security** | Suspicious logins, rate limits, unauthorized access |
| **Payments** | Transactions, refunds, payment method changes |

### Real-time Alerts

| Event | Severity | Action |
|-------|----------|--------|
| Brute force attempt | Critical | Lock account, notify admins |
| Impossible travel | Critical | Flag for review, notify user |
| Multiple failed OTPs | Warning | Rate limit, log event |
| New device login | Info | Notify user via push |
| High-value transaction | Info | Require SMS verification |

### Security Reports
- **Daily:** Automated security metrics report at 8 AM WAT
- **Weekly:** Admin dashboard review
- **Monthly:** Compliance audit summary
- **On-demand:** Incident investigation reports

### Metrics Tracked
- Failed login attempts
- Security events by severity
- Locked accounts
- Rate limit violations
- Suspicious activities
- New user registrations

---

## Incident Response

### Incident Severity Levels

| Level | Description | Response Time | Examples |
|-------|-------------|---------------|----------|
| **P1 - Critical** | Active breach, data exposure | 15 minutes | Account takeover, data leak |
| **P2 - High** | Potential breach, system degradation | 1 hour | Brute force attack, suspicious admin |
| **P3 - Medium** | Security policy violation | 4 hours | Unauthorized access attempt |
| **P4 - Low** | Minor security issue | 24 hours | Failed rate limit, invalid tokens |

### Response Procedures

#### 1. Detection
- Automated alerts via Cloud Functions
- User reports via support channels
- Manual log review

#### 2. Containment
- Lock affected accounts
- Revoke compromised sessions
- Isolate affected systems

#### 3. Eradication
- Identify root cause
- Patch vulnerabilities
- Remove malicious access

#### 4. Recovery
- Restore from clean backups if needed
- Reset affected credentials
- Validate system integrity

#### 5. Post-Incident
- Document incident timeline
- Update security controls
- Notify affected users if required
- Report to authorities if legally required

### Incident Communication
- **Internal:** Slack #security channel, email to security team
- **Users:** In-app notification, email for critical incidents
- **Authorities:** CNPD (Portuguese DPA) within 72 hours for breaches

---

## Compliance

### SOC 2 Trust Service Criteria

| Criteria | Status | Evidence |
|----------|--------|----------|
| **CC1 - Control Environment** | ✅ | Security policies documented |
| **CC2 - Communication** | ✅ | User terms, privacy policy |
| **CC3 - Risk Assessment** | ✅ | Threat modeling, penetration tests |
| **CC4 - Monitoring** | ✅ | Audit logs, security reports |
| **CC5 - Control Activities** | ✅ | Access controls, encryption |
| **CC6 - Logical Access** | ✅ | RBAC, MFA, session management |
| **CC7 - System Operations** | ✅ | Incident response, monitoring |
| **CC8 - Change Management** | ✅ | Code review, deployment controls |
| **CC9 - Risk Mitigation** | ✅ | Rate limiting, fraud detection |

### GDPR Compliance

| Article | Requirement | Implementation |
|---------|-------------|----------------|
| Art. 5 | Data minimization | Only essential data collected |
| Art. 7 | Consent | Explicit consent at signup |
| Art. 15 | Right of access | Data export function |
| Art. 17 | Right to erasure | Account deletion function |
| Art. 20 | Data portability | JSON export |
| Art. 32 | Security | Encryption, access controls |
| Art. 33 | Breach notification | 72-hour notification process |

### Angolan Data Protection Law (Lei nº 22/11)
- Data processed lawfully with consent
- Purpose limitation enforced
- Data security measures implemented
- Cross-border transfer safeguards (EU)

---

## Security Contacts

### Internal Team
- **Security Lead:** security@bodaconnect.ao
- **Incident Response:** incident@bodaconnect.ao
- **Privacy Officer:** privacy@bodaconnect.ao

### Vulnerability Reporting
If you discover a security vulnerability, please report it responsibly:
- Email: security@bodaconnect.ao
- Subject: [SECURITY] Brief description
- Include: Steps to reproduce, impact assessment

### Emergency Contacts
- **Critical Incidents (24/7):** +244 XXX XXX XXX
- **Firebase Support:** Firebase Console support

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | Jan 2026 | Security Team | Initial release |

**Review Cycle:** Quarterly
**Next Review:** April 2026

---

*This document is confidential and intended for internal use only. Unauthorized distribution is prohibited.*
