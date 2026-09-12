# KinSync — Requirements & Acceptance Criteria (`spec.md`)

**Project:** KinSync — Passive Daily Pattern Monitor for Elderly Living Alone
**Version:** 0.1 (Phase-1 draft)
**Last updated:** 12 Sep 2026
**Status:** Draft for Review 2

---

## 1. Problem Statement

Elderly individuals living alone are at risk of medical emergencies or falls going unnoticed for hours. Existing safety apps rely either on **active check-ins** (which lapse when the person forgets, is unwell, or resists the extra chore) or on **continuous location tracking** (which many elderly users experience as invasive and refuse to enable, undermining the very safety net it's meant to provide).

## 2. Proposed Solution (Summary)

KinSync passively learns an individual's normal daily digital-activity signature — phone-unlock times, typical app-usage windows, and coarse movement state — over an initial baseline period, then flags deviations from that pattern (e.g., no activity by the person's usual check-in time) to designated family contacts. Only derived signals ever leave the device; raw activity logs, content, and continuous location are never transmitted.

## 3. Goals

- **G1:** Reduce time-to-notice for a possible medical emergency or fall, without requiring the elder to actively "check in."
- **G2:** Preserve the elder's dignity and privacy — no raw location, content, or continuous surveillance leaves the device.
- **G3:** Give family/caregivers timely, low-noise alerts they can trust (low false-positive rate).
- **G4:** Remain robust even if the elder's phone is offline, powered off, or unresponsive — the scenario the app most needs to catch.
- **G5:** Ship as a native Android solution with a self-hosted backend, giving the student team full ownership of both the mobile and server layers for learning purposes.

## 4. Non-Goals (v1)

- No medical diagnosis or clinical claims of any kind.
- No fall detection via accelerometer/gyroscope (candidate for future work, not v1).
- No wearable device integration.
- No iOS support (Android-only by design; see NFR-5).
- No continuous raw GPS tracking at any point.
- No multi-language UI in v1 (English only).

## 5. Stakeholders / User Roles

| Role | Description |
|---|---|
| **Elder** | The person being passively monitored. Primary user of the "Elder" mode of the app. |
| **Caregiver / Family member** | One or more people who receive alerts and monitor status. Primary user of the "Caregiver" mode of the app. |
| **Project guide / review panel** | Evaluates the project against this spec and the review timeline. |

## 6. Representative User Stories

- As an **elder**, I want the app to quietly notice if something's wrong without me having to remember to check in, so that help can be found even if I can't ask for it myself.
- As an **elder**, I want to see exactly what the app is tracking about me, so I can trust it isn't spying on me.
- As an **elder**, I want to pause monitoring when I'm traveling, so I don't get flagged for a change in routine I already know about.
- As a **caregiver**, I want to be notified quickly if my parent's normal routine is disrupted, so I can check on them without having to call every day.
- As a **caregiver**, I want alerts to be rare and meaningful, so I don't start ignoring them.

## 7. Functional Requirements

### FR-1 — Onboarding & Pairing
- **FR-1.1** The app shall support two roles selectable at first launch: *Elder* and *Caregiver*.
- **FR-1.2** An Elder profile shall be able to generate a unique, time-limited pairing code.
- **FR-1.3** A Caregiver shall be able to redeem a pairing code to link their app to an elder's profile.
- **FR-1.4** The system shall support one elder linked to up to three caregivers in v1.
- **FR-1.5** An elder shall be able to view and revoke linked caregivers at any time.

### FR-2 — Passive Data Collection (on-device)
- **FR-2.1** The app shall capture screen-unlock events via a `BroadcastReceiver` (`ACTION_USER_PRESENT`, screen on/off).
- **FR-2.2** The app shall query app-usage windows via `UsageStatsManager`, requesting the special `PACKAGE_USAGE_STATS` permission with a clear, plain-language rationale screen before requesting it.
- **FR-2.3** The app shall capture coarse movement state (still / walking / in-vehicle) via the Activity Recognition API, without ever accessing raw GPS coordinates.
- **FR-2.4** All raw collected events shall be stored only in a local on-device database; raw events must never be transmitted off-device.
- **FR-2.5** The elder shall be able to view a plain-language log of what has been collected (transparency screen).
- **FR-2.6** The elder shall be able to pause/snooze collection for a defined period (e.g., a "traveling" mode).

### FR-3 — Baseline Learning
- **FR-3.1** The app shall compute a rolling baseline (default 14-day window, configurable) of typical first-unlock time, active windows, and unlock frequency.
- **FR-3.2** The baseline shall use descriptive statistics (mean/median, standard deviation) in v1. A baseline is not considered "ready" until a minimum of 7 days of data exist.
- **FR-3.3** The app shall recompute the baseline periodically (e.g., nightly) as new days roll into the window.

### FR-4 — Deviation Detection & Escalation
- **FR-4.1** The app shall run a periodic local check comparing the current day's activity against the baseline.
- **FR-4.2** If no activity is detected within the elder's expected check-in window, the app shall show an in-app nudge ("Everything OK? Tap to confirm") before escalating.
- **FR-4.3** If the nudge is unacknowledged within a configurable grace period (default 30 minutes), the day's heartbeat shall be marked "missed."
- **FR-4.4** The backend scheduler shall independently track each elder's expected check-in window (from a derived summary only) and shall trigger escalation if no heartbeat/acknowledgement is received within that window — **even if the device is offline, powered off, or unresponsive.**
- **FR-4.5** Escalation shall notify all linked caregivers via push notification (SMS fallback optional, later phase).
- **FR-4.6** An escalated alert shall remain visible to caregivers until explicitly marked resolved.

### FR-5 — Notifications
- **FR-5.1** The caregiver app shall register a push-notification device token with the backend.
- **FR-5.2** The backend shall send a push notification containing minimal alert context (elder name, alert type, time) to all linked caregivers on escalation.
- **FR-5.3** *(Later phase)* The backend may send an SMS fallback via a configured provider for caregivers without the app installed.

### FR-6 — Caregiver Dashboard
- **FR-6.1** The caregiver app shall display current status (normal / nudged / escalated) for each linked elder.
- **FR-6.2** The caregiver app shall display an aggregated activity trend without exposing raw timestamps or app names.
- **FR-6.3** A caregiver shall be able to acknowledge/resolve an active alert.

### FR-7 — Privacy & Consent Controls
- **FR-7.1** An elder must explicitly grant onboarding consent describing what is collected before the app begins collection.
- **FR-7.2** Only derived signals (a heartbeat and an expected check-in window) leave the elder's device; raw activity logs never leave the device.
- **FR-7.3** An elder can revoke consent at any time, which stops collection and unpairs all caregivers.

## 8. Non-Functional Requirements

| ID | Requirement |
|---|---|
| **NFR-1 Privacy** | No raw location, app-name-level detail, or content ever leaves the elder's device. Only derived heartbeat/window summaries are transmitted. |
| **NFR-2 Reliability** | The escalation mechanism must function as a "dead-man's switch" — it must trigger correctly even if the elder's phone is offline, powered off, or the app has been killed by OEM battery management, within the defined heartbeat cadence. |
| **NFR-3 Battery** | Background collection should not perceptibly reduce the elder's phone's battery life beyond an agreed threshold (target: <5% additional daily drain, to be measured in testing). |
| **NFR-4 Security** | All client-server traffic over TLS. Device-bound bearer tokens for authentication. VM hardened with a firewall, key-only SSH, and automated security updates. |
| **NFR-5 Compatibility** | Android only. Minimum SDK to be finalized by the team in Phase-1 based on `UsageStatsManager`/Activity Recognition availability; Google Play Services required. |
| **NFR-6 Usability** | Elder-facing UI must use large text, minimal steps per screen, and avoid technical jargon. |
| **NFR-7 Maintainability** | Code organized into the modules defined in `plan.md`, each independently testable. |

## 9. Acceptance Criteria (key flows)

**Pairing**
- *Given* an elder has generated a pairing code, *when* a caregiver enters that code within its validity window, *then* the caregiver's app is linked to the elder's profile and both apps reflect the new pairing.

**Baseline readiness**
- *Given* fewer than 7 days of collected data, *when* the deviation detector runs, *then* it shall take no action (baseline not yet ready).
- *Given* 7 or more days of collected data, *when* the deviation detector runs, *then* it shall compare today's activity against the computed baseline.

**Nudge before escalation**
- *Given* the elder's expected check-in window has passed with no detected activity, *when* the deviation detector runs, *then* the elder shall receive an in-app nudge before any family notification is sent.

**Dead-man's-switch escalation**
- *Given* no heartbeat has been received by the backend within an elder's expected window, *when* the scheduler runs its periodic check, *then* an alert shall be created and all linked caregivers notified — regardless of whether the elder's device is reachable at that moment.

**Consent revocation**
- *Given* an elder revokes consent, *when* the revocation is confirmed, *then* all local collection shall stop immediately and all caregiver pairings shall be removed.

## 10. Assumptions & Constraints

- One elder may be linked to at most three caregivers in v1.
- The elder's device has Google Play Services (required for Activity Recognition and push notifications).
- The elder's device has internet connectivity at least once within each expected check-in window for a normal (non-escalated) day; the offline/unresponsive case is exactly what FR-4.4 is designed to catch.
- Backend infrastructure is a self-hosted Ubuntu 26.04 VM on Hetzner, chosen deliberately over a managed BaaS so the team gains backend engineering experience (see `plan.md`).

## 11. Out of Scope for v1

- Fall detection via accelerometer/gyroscope.
- Wearable device integration.
- Multi-language support.
- iOS support.
- More than three caregivers per elder.
- Audio or video monitoring of any kind.

## 12. Glossary

| Term | Meaning |
|---|---|
| **Baseline** | A statistical model of an elder's typical daily activity pattern, computed on-device. |
| **Heartbeat** | A minimal, periodic signal sent from the elder's device to the backend, confirming activity is within the expected pattern. |
| **Deviation** | A detected departure from the elder's baseline pattern (e.g., no unlock by the usual time). |
| **Escalation** | The process of notifying caregivers after a deviation has gone unacknowledged past the grace period. |
| **Pairing code** | A short-lived code used to link a caregiver's app to an elder's profile. |
| **Dead-man's switch** | A safety pattern where the *absence* of an expected signal (not the presence of an explicit alarm) triggers a response. |
| **Grace period** | The window given to the elder to acknowledge a nudge before escalation proceeds. |
