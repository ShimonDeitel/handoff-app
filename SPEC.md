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

## Multi-user sync

Real CloudKit sharing, not a custom backend: one custom `CKRecordZone` ("CareCircleZone") per
family, owned in the creator's private database and shared zone-wide via a single `CKShare`
(`CKShare(recordZoneID:)`). The owner invites siblings through the system `UICloudSharingController`
share sheet (Messages/Mail); every sibling who accepts reads and writes the exact same records
through their own CloudKit shared database. Local JSON cache on disk keeps the app usable
offline and gives an instant first paint, mirroring the degrade-to-local-only pattern used
elsewhere in this portfolio for family-sharing apps.

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
