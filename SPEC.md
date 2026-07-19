# Handoff — Sibling Care Circle

Part of the "Animated Ten" batch. Originally auto-named "Kinfolk"; renamed to Handoff after
finding a real, exact-name-collision app called "Kinfolk" plus two close family-connection
competitors ("Kinfolk - Connect with family", "Kinfolk - Connecting Relations") on the live App
Store.

## Concept

A lightweight shared space for adult siblings jointly caring for an aging parent: a rotating
whose-turn calendar, quick post-visit logs (a short note + optional photo after each visit or
call), and an AI-generated weekly digest condensing the week into one line for whichever
sibling lives far away.

## Problem / evidence

AgingCare.com forum posts show siblings coordinating a parent's care being pointed only toward
ill-fitting workarounds — a shared Google Doc, a group WhatsApp thread, a paper calendar taped
to the fridge. Nothing purpose-built exists for "whose turn is it, and did they actually get the
handoff."

## Quirky feature

A **handoff note** the outgoing sibling leaves for whoever is next in rotation. The recipient
must actually **open and read it** — tracked via a real `readAt` timestamp, never just
"delivered" — before their care turn is considered officially started. Until they do, the whole
circle sees a visible "still waiting for Sam to read the handoff" banner, closing the silent gap
where nobody's sure who currently has the baton.

## Animation hook

Each sibling is a small circular photo-node arranged in a radial layout (positions computed via
simple trigonometry — `RadialLayout.swift`) orbiting a center parent-avatar node. Logging a
visit fires a `PulseEvent`; `ConstellationView` animates a small glowing dot (Canvas +
`TimelineView(.animation)`, traveling along a `quadraticPoint`-interpolated curved path) from
that sibling's node to the center, then back out to every other node — a literal visualization
of the update reaching the whole circle.

## AI feature

`POST /text` to the shared no-key proxy (`https://apps-ai-proxy.s0533495227.workers.dev/text`).
Collects the current week's post-visit log text entries from every sibling, asks for a single
warm, specific one-line digest sentence for the distant sibling (e.g. "Mom had a good week —
Priya took her to PT twice and her appetite's back up, but the railing repair still needs
scheduling"). Pro-gated.

## Multi-user sync — CURRENTLY DISABLED (single-device only)

The design is real CloudKit sharing, not a custom backend: one custom `CKRecordZone`
("CareCircleZone") per family, owned in the creator's private database and shared zone-wide via
a single `CKShare` (`CKShare(recordZoneID:)`), with the owner inviting siblings through the
system `UICloudSharingController` share sheet (Messages/Mail).

That path is **not active in this submission**. The app's iCloud container
(`iCloud.com.shimondeitel.handoff`) isn't yet linked to this bundle ID in the Apple Developer
Portal — that link requires a manual portal step behind 2FA that wasn't available at submission
time. Rather than ship a half-wired sync path, the CloudKit code (CKContainer/CKShare/CKRecord
zone and subscription plumbing, the `UICloudSharingController` wrapper, and the
push-notification entitlement/registration in the app delegate) has been removed, and the
`aps-environment` and iCloud entitlements have been stripped from `Handoff.entitlements`.

Handoff currently runs **local-only, single device**: the care circle, siblings, visit logs,
and handoff notes persist only in the on-disk JSON cache (`CareCircleStore`'s `LocalCache`) that
previously served as the offline fallback. The "Invite Siblings" row in Settings is visible but
inert, labeled "Multi-device sync coming soon" instead of opening a (non-functional) share
sheet. Re-enabling sync later means: link the iCloud container in the portal, restore the
CloudKit round-trip in `CareCircleStore`/the removed `CloudKitSync.swift` (see git history),
restore the entitlements, and re-wire the invite button.

## Design direction

Dusty lavender + warm stone grey — a "constellation of family" feel: soft circular nodes
connected by thin animated arcs, calm and grounded rather than clinical or corporate. Warm
serif headlines (photo-album feel), plain system body text for easy-to-read visit notes. A
distinct warm amber-gold accent ("the handoff glow") marks the traveling pulse so it reads
clearly against the lavender arcs.

## Monetization

Free tier: up to 2 family members in the circle, most-recent 5 visit logs visible.
Pro — **$7.99/month, billed once per family/circle, not per person** (product id
`com.shimondeitel.handoff.pro.monthly`): unlimited siblings, the AI weekly digest, and full
visit-log history.
