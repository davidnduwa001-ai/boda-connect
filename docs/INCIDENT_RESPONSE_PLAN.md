# BODA CONNECT - Incident Response Plan

**Version:** 1.0.0
**Last Updated:** January 2026
**Classification:** Confidential - Internal Only

---

## Table of Contents
1. [Purpose](#purpose)
2. [Scope](#scope)
3. [Incident Response Team](#incident-response-team)
4. [Incident Classification](#incident-classification)
5. [Response Procedures](#response-procedures)
6. [Communication Plan](#communication-plan)
7. [Recovery Procedures](#recovery-procedures)
8. [Post-Incident Activities](#post-incident-activities)
9. [Tools and Resources](#tools-and-resources)
10. [Training and Testing](#training-and-testing)

---

## 1. Purpose

This Incident Response Plan (IRP) establishes procedures for detecting, responding to, and recovering from security incidents affecting Boda Connect. The goals are to:

- Minimize damage and business impact
- Preserve evidence for investigation
- Restore normal operations quickly
- Prevent future incidents
- Comply with legal notification requirements

---

## 2. Scope

This plan covers:
- **Systems:** Mobile apps, web app, Firebase services, Cloud Functions
- **Data:** User data, payment information, business data, audit logs
- **Incidents:** Security breaches, data leaks, system compromises, DDoS attacks
- **Personnel:** All employees with system access

---

## 3. Incident Response Team

### 3.1 Core Team

| Role | Responsibilities | Primary Contact | Backup |
|------|------------------|-----------------|--------|
| **Incident Commander** | Overall coordination, decisions | CTO | CEO |
| **Security Lead** | Technical investigation, containment | Security Engineer | DevOps Lead |
| **Communications Lead** | User/media communications | Marketing Manager | CEO |
| **Legal Counsel** | Legal advice, regulatory compliance | Legal Advisor | External Counsel |
| **Operations Lead** | System recovery, business continuity | DevOps Lead | Backend Lead |

### 3.2 Extended Team (as needed)

| Role | When Involved |
|------|---------------|
| Customer Support | User-facing incidents |
| Finance | Financial fraud incidents |
| HR | Insider threat incidents |
| External Forensics | Major breaches requiring investigation |

### 3.3 Contact Information

**24/7 Security Hotline:** +244 XXX XXX XXX
**Email:** incident@bodaconnect.ao
**Slack:** #incident-response (Priority alerts enabled)

---

## 4. Incident Classification

### 4.1 Severity Levels

| Level | Name | Description | Response Time | Examples |
|-------|------|-------------|---------------|----------|
| **P1** | Critical | Active breach, widespread impact | 15 min | Data exfiltration, ransomware, production down |
| **P2** | High | Potential breach, significant risk | 1 hour | Brute force attack, suspicious admin access |
| **P3** | Medium | Security policy violation, limited impact | 4 hours | Unauthorized access attempt, malware detected |
| **P4** | Low | Minor issue, no immediate risk | 24 hours | Failed rate limits, policy violations |

### 4.2 Incident Categories

| Category | Description | Typical Severity |
|----------|-------------|------------------|
| **Data Breach** | Unauthorized access to personal data | P1-P2 |
| **Account Compromise** | User/admin account takeover | P1-P2 |
| **Malware** | Malicious code detected | P2-P3 |
| **DDoS Attack** | Service availability impact | P2-P3 |
| **Insider Threat** | Employee misuse of access | P1-P3 |
| **Fraud** | Financial fraud attempt | P2-P3 |
| **Physical** | Device theft, office breach | P2-P4 |
| **Compliance** | Regulatory violation | P2-P3 |

### 4.3 Automatic Escalation Triggers

The following events trigger automatic P1/P2 classification:
- Multiple accounts compromised (>10)
- Payment data exposed
- Admin account compromised
- Production database accessed by unauthorized party
- Regulatory notification required
- Media coverage likely

---

## 5. Response Procedures

### 5.1 Phase 1: Detection & Identification (0-15 min)

**Objective:** Confirm incident and assess initial scope

**Steps:**
1. [ ] Receive alert (automated or manual report)
2. [ ] Log incident in tracking system
3. [ ] Assign incident ID: `INC-YYYY-MM-DD-XXX`
4. [ ] Perform initial triage:
   - What systems are affected?
   - What data may be compromised?
   - Is the incident ongoing?
5. [ ] Classify severity level
6. [ ] Notify Incident Commander
7. [ ] Activate response team (if P1/P2)

**Checklist - Initial Assessment:**
```
□ Time incident detected: __________
□ How detected (alert/report/other): __________
□ Systems affected: __________
□ Users potentially affected: __________
□ Data types at risk: __________
□ Incident still active: Yes / No
□ Initial severity: P1 / P2 / P3 / P4
```

### 5.2 Phase 2: Containment (15 min - 4 hours)

**Objective:** Stop the incident from spreading

**Immediate Containment (P1/P2):**
1. [ ] Isolate affected systems
2. [ ] Block suspicious IP addresses
3. [ ] Disable compromised accounts
4. [ ] Revoke compromised credentials
5. [ ] Enable enhanced logging

**Short-term Containment:**
1. [ ] Apply emergency patches if available
2. [ ] Implement additional access controls
3. [ ] Redirect traffic if DDoS
4. [ ] Preserve evidence (snapshots, logs)

**Containment Actions by Incident Type:**

| Incident Type | Primary Actions |
|---------------|-----------------|
| Account Compromise | Lock account, terminate sessions, reset credentials |
| Data Breach | Isolate database, revoke access tokens, enable audit |
| Malware | Quarantine system, block C2 domains, scan other systems |
| DDoS | Enable rate limiting, activate CDN protections |
| Insider Threat | Revoke access immediately, preserve evidence |

**Firebase/Cloud Containment Commands:**
```bash
# Disable user account
firebase auth:disable USER_UID

# Revoke all sessions
firebase auth:revoke-refresh-tokens USER_UID

# Disable Cloud Function
gcloud functions delete FUNCTION_NAME

# Update Firestore security rules (emergency)
firebase deploy --only firestore:rules
```

### 5.3 Phase 3: Eradication (1-24 hours)

**Objective:** Remove the threat completely

**Steps:**
1. [ ] Identify root cause
2. [ ] Remove malicious code/access
3. [ ] Patch vulnerabilities
4. [ ] Reset all potentially compromised credentials
5. [ ] Verify threat is eliminated
6. [ ] Document all changes made

**Root Cause Analysis Questions:**
- How did the attacker gain access?
- What vulnerabilities were exploited?
- How long was access maintained?
- What actions were taken by the attacker?
- What data was accessed/exfiltrated?

### 5.4 Phase 4: Recovery (1-48 hours)

**Objective:** Restore normal operations safely

**Steps:**
1. [ ] Restore systems from clean backups (if needed)
2. [ ] Verify system integrity
3. [ ] Re-enable services gradually
4. [ ] Monitor for signs of re-compromise
5. [ ] Update security controls
6. [ ] Confirm business operations normal

**Recovery Verification Checklist:**
```
□ All systems operational
□ Security logs showing normal activity
□ No unauthorized access detected
□ All credentials rotated
□ Patches applied
□ Enhanced monitoring active
```

---

## 6. Communication Plan

### 6.1 Internal Communication

| Audience | Channel | Timing | Content |
|----------|---------|--------|---------|
| Response Team | Slack #incident-response | Immediate | Technical details |
| Leadership | Email + Call | Within 1 hour | Status summary |
| All Staff | Email | After containment | General awareness |

**Internal Status Update Template:**
```
INCIDENT UPDATE - [INC-ID]
Status: [Active/Contained/Resolved]
Severity: [P1/P2/P3/P4]
Time: [Current time]

Summary:
[Brief description of current situation]

Actions Taken:
- [Action 1]
- [Action 2]

Next Steps:
- [Next step 1]
- [Next step 2]

ETA for Resolution: [Time estimate]
```

### 6.2 External Communication

#### User Notification (Required for Data Breaches)

**Timing:** Within 72 hours of confirmation
**Method:** Email + In-app notification
**Content Must Include:**
- Nature of the breach
- Data types affected
- Actions being taken
- Steps users should take
- Contact information

**User Notification Template:**
```
Subject: Important Security Notice from Boda Connect

Dear [User Name],

We are writing to inform you of a security incident that may have affected your account.

WHAT HAPPENED:
[Clear description of incident]

WHAT INFORMATION WAS INVOLVED:
[List data types: name, email, phone, etc.]

WHAT WE ARE DOING:
[Actions taken to protect users]

WHAT YOU CAN DO:
- Change your password immediately
- Review your account activity
- Be cautious of suspicious emails

CONTACT US:
If you have questions, please contact us at security@bodaconnect.ao

We sincerely apologize for any inconvenience.

Boda Connect Security Team
```

#### Regulatory Notification

| Authority | When Required | Deadline | Contact |
|-----------|---------------|----------|---------|
| CNPD (Angola) | Personal data breach | 72 hours | [Contact] |
| CNPD (Portugal) | EU user data breach | 72 hours | cnpd@cnpd.pt |
| Law Enforcement | Criminal activity | As advised by Legal | Police |

### 6.3 Media Response

- All media inquiries directed to Communications Lead
- No unauthorized statements
- Use approved messaging only
- Coordinate with Legal before any public statement

---

## 7. Recovery Procedures

### 7.1 Firebase Recovery

**Firestore Recovery:**
```bash
# Export current state
gcloud firestore export gs://backup-bucket/incident-backup

# Restore from backup
gcloud firestore import gs://backup-bucket/clean-backup
```

**Auth Recovery:**
```bash
# Export user list
firebase auth:export users.json

# Disable all sessions (nuclear option)
# Via Admin SDK - see recovery scripts
```

### 7.2 Application Recovery

1. Deploy last known good version
2. Roll back database changes if needed
3. Clear CDN caches
4. Force app update if client compromised

### 7.3 Credential Rotation

After any P1/P2 incident:
- [ ] Firebase service account keys
- [ ] API keys (Algolia, Twilio, etc.)
- [ ] Admin passwords
- [ ] Encryption keys (if compromised)

---

## 8. Post-Incident Activities

### 8.1 Post-Incident Review (Within 5 days)

**Attendees:** All response team members
**Duration:** 1-2 hours

**Agenda:**
1. Incident timeline review
2. What went well
3. What could be improved
4. Action items for prevention
5. Documentation updates needed

### 8.2 Incident Report

**Required Sections:**
1. Executive Summary
2. Timeline of Events
3. Root Cause Analysis
4. Impact Assessment
5. Response Actions Taken
6. Lessons Learned
7. Recommendations
8. Appendices (logs, evidence)

### 8.3 Remediation Tracking

| Item | Owner | Deadline | Status |
|------|-------|----------|--------|
| [Vulnerability patched] | [Name] | [Date] | [Status] |
| [Control implemented] | [Name] | [Date] | [Status] |
| [Policy updated] | [Name] | [Date] | [Status] |

---

## 9. Tools and Resources

### 9.1 Monitoring & Detection

| Tool | Purpose | Access |
|------|---------|--------|
| Firebase Console | Auth, Firestore monitoring | console.firebase.google.com |
| Cloud Logging | System logs | console.cloud.google.com |
| Sentry | Error tracking | sentry.io |
| Custom Dashboards | Security metrics | [Internal URL] |

### 9.2 Response Tools

| Tool | Purpose | Location |
|------|---------|----------|
| Incident Tracker | Tracking, documentation | [Internal system] |
| Evidence Storage | Secure log storage | [Secure bucket] |
| Communication | Team coordination | Slack, Email |
| Runbooks | Response procedures | This document |

### 9.3 Emergency Contacts

| Service | Contact | Support Portal |
|---------|---------|----------------|
| Firebase Support | Firebase Console | firebase.google.com/support |
| GCP Support | Cloud Console | cloud.google.com/support |
| Twilio | Twilio Console | twilio.com/console |
| Legal Counsel | [Phone] | [Email] |

---

## 10. Training and Testing

### 10.1 Training Requirements

| Role | Training | Frequency |
|------|----------|-----------|
| Response Team | Full IRP training | Quarterly |
| Developers | Security awareness | Annually |
| All Staff | Incident reporting | Annually |

### 10.2 Testing Schedule

| Test Type | Frequency | Last Test | Next Test |
|-----------|-----------|-----------|-----------|
| Tabletop Exercise | Quarterly | [Date] | [Date] |
| Technical Drill | Semi-annually | [Date] | [Date] |
| Full Simulation | Annually | [Date] | [Date] |

### 10.3 Plan Review

This plan is reviewed and updated:
- After every P1/P2 incident
- Quarterly (minimum)
- When significant system changes occur

---

## Appendices

### A. Incident Report Template

[Link to template]

### B. Evidence Collection Procedures

[Link to procedures]

### C. Regulatory Contact Details

[Full contact information]

### D. Recovery Scripts

[Link to secure repository]

---

## Document Control

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0.0 | Jan 2026 | Security Team | Initial release |

**Approval:**
- CTO: [Signature] [Date]
- Security Lead: [Signature] [Date]
- Legal: [Signature] [Date]

---

*This document is confidential. Unauthorized distribution is prohibited.*
