# ADR-001 — Multi-tenant platform foundation

- **Status:** Accepted
- **Date:** 2026-08-28
- **Scope:** M0 — Fondazioni multi-tenant
- **Pilot tenant:** Sound Implosion, Bracciano
- **Platform brand:** To be chosen at the naming gate defined below

## 1. Context

SoundImplosion is currently a single-studio Flutter application backed by Firebase Authentication, Realtime Database, Cloud Functions, Analytics, Crashlytics and Messaging.

The existing product already contains valuable flows that must be preserved: user authentication, groups/bands, booking requests, admin approval/cancellation/update proposals, slot management, notifications, jams, profiles, discovery and support.

The current architecture is not multi-tenant:

- `Booking` has no `studioId` or `roomId`;
- booking and slot repositories operate against one global studio schedule;
- `AppUser.role` is effectively `user` / global `admin`;
- admin booking and slot repositories operate globally;
- RTDB rules grant many privileged operations through the global admin role;
- the application navigation is not yet based on stable declarative routes suitable for studio links, invite links and backoffice URLs.

The goal is to transform the application into a B2B2C platform where multiple rehearsal studios can independently manage rooms, availability and bookings while musicians use one account/app across all studios.

Sound Implosion remains the rehearsal studio brand in Bracciano and becomes tenant #1 / the production pilot. The national platform will use a separate neutral brand.

## 2. Decision summary

We will evolve the existing codebase incrementally instead of rewriting it.

For the pilot:

1. Keep Firebase Realtime Database as the operational datastore.
2. Introduce tenant-aware domain entities and repositories.
3. Make all studio-private operational data tenant-scoped.
4. Separate global platform administration from per-studio roles.
5. Move booking reservation/release logic to trusted server-side transactional code.
6. Keep one Flutter codebase initially, with separate musician, studio backoffice and platform-admin shells/routes.
7. Preserve groups, jams and community features while freezing new community scope until the multi-tenant booking core is stable.
8. Delay marketplace search, booking payments and SaaS billing until after the pilot gates.
9. Do not perform a big-bang RTDB → Firestore migration during M0/M1.
10. Do not rename technical package/repository/Firebase identifiers during M0 solely for branding.

## 3. Core domain model

### 3.1 Studio

A `Studio` is the tenant boundary.

Minimum fields:

```text
Studio
- id
- slug
- name
- status: active | suspended | archived
- timezone
- address
- latitude?
- longitude?
- phone?
- email?
- website?
- description?
- logoUrl?
- createdAt
- updatedAt
```

Private operational settings are not exposed through the public studio profile.

### 3.2 Room

A studio can expose one or more independently bookable rooms.

```text
Room
- id
- studioId
- name
- status: active | inactive
- capacity?
- slotDurationMinutes
- minimumBookingSlots
- basePrice?
- currency
- equipment[]
- description?
- createdAt
- updatedAt
```

The current global slot model becomes room-scoped.

### 3.3 StudioMembership

Studio privileges belong to the relationship between a user and a studio, not to the global user object.

```text
StudioMembership
- studioId
- userId
- role: owner | manager | staff
- status: active | invited | disabled
- createdAt
- updatedAt
```

A single user can therefore be:

- owner of Studio A;
- manager of Studio B;
- a normal musician across the whole platform.

### 3.4 Platform administration

Global platform administration must not be represented as a studio role.

Target design:

- Firebase Auth custom claim: `platform_admin: true`;
- custom claims can only be assigned by trusted Admin SDK code;
- existing legacy `users/{uid}/role == admin` is migration compatibility only and must not remain the long-term source of global privilege.

### 3.5 Booking v2

```text
Booking
- id
- studioId
- roomId
- userId
- groupId?
- groupNameSnapshot?
- startAt
- endAt
- peopleCount
- equipmentRequest?
- status: pending | confirmed | rejected | cancelled | completed | no_show
- source: direct | invite | marketplace | manual
- baseAmount?
- totalAmount?
- currency?
- paymentStatus?: not_required | unpaid | pending | paid | refunded | failed
- createdAt
- updatedAt
- confirmedAt?
- cancelledAt?
```

Rules:

- `studioId`, `roomId`, `userId` and `source` are immutable after creation;
- monetary/payment fields exist in the model only to avoid a later incompatible redesign; payment processing is not an M0/M1 requirement;
- booking change proposals should become a separate change-request concept instead of overloading booking status;
- bookings crossing midnight are out of scope for the first multi-tenant pilot unless explicitly re-approved.

## 4. RTDB target structure

Canonical studio-private operational data is tenant-first.

```text
studios/
  {studioId}/
    profile/
    settings/
    members/
      {uid}/
        role
        status
        created_at
        updated_at
    rooms/
      {roomId}/
    bookings/
      {bookingId}/
    room_days/
      {roomId}/
        {yyyy-MM-dd}/
          slots/
            {HHmm}/
              state
              booking_id?
          reservations/
            {bookingId}/
              user_id
              start_slot
              end_slot
              status

studio_public_profiles/
  {studioId}/

studio_slugs/
  {slug}: {studioId}

user_studios/
  {uid}/
    {studioId}/
      role
      status

user_bookings/
  {uid}/
    {bookingId}/
      studio_id
      room_id
      start_at
      status

user_saved_studios/
  {uid}/
    {studioId}/
      saved_at
      source

studio_invites/
  {inviteCode}/
    studio_id
    active
    expires_at?
    campaign?
```

Notes:

- `studios/{studioId}/...` is the canonical private tenant subtree.
- `user_studios` is an inverse index required because RTDB cannot efficiently query every tenant to discover the studios accessible by one user.
- `user_bookings` is a read-optimized projection/index; the canonical booking remains under the studio.
- `studio_public_profiles` contains only fields intentionally safe for unauthenticated/public discovery.
- invite codes must not be enumerable through public RTDB reads; resolution/consumption should go through trusted callable/HTTP logic.
- denormalized indexes must be written atomically with canonical data where possible and repaired idempotently when needed.

## 5. Authorization model

### 5.1 Musician

A signed-in musician may:

- read public studio profiles;
- save/unsave studios for their own account;
- read their own booking projections and booking details;
- create a booking request for an active public studio/room;
- cancel their own booking when policy allows;
- access group/jam/community functionality according to existing rules.

A musician may not read another studio's private bookings, customers, availability administration or settings.

### 5.2 Studio staff

| Capability | Owner | Manager | Staff |
|---|---:|---:|---:|
| View studio bookings | Yes | Yes | Yes |
| Approve/reject/cancel bookings | Yes | Yes | Yes |
| Create manual booking | Yes | Yes | Yes |
| Block/unblock availability | Yes | Yes | Yes |
| Edit rooms/equipment/pricing | Yes | Yes | No |
| View operational analytics | Yes | Yes | Limited/No initially |
| Manage staff memberships | Yes | No initially | No |
| Manage billing/subscription | Yes | No | No |
| Transfer ownership | Yes via trusted flow | No | No |
| Delete/archive studio | Yes via trusted flow | No | No |

The matrix can be extended later with granular permissions, but M0 should not introduce a generic ACL engine prematurely.

### 5.3 Platform admin

`platform_admin` is the only global privileged role.

It may access platform administration functions, moderation/support and tenant-level diagnostics required by operations. Normal studio owners must never inherit platform-wide read/write access.

## 6. Booking concurrency and double-booking protection

Double booking is a P0 correctness requirement.

Client-side checks are not authoritative.

### 6.1 Create booking

The client calls trusted server-side logic with:

```text
studioId
roomId
date
requested slots
peopleCount
groupId?
equipmentRequest?
source
```

The server must:

1. authenticate the user;
2. validate studio and room state;
3. validate booking policy, slot duration and minimum booking length;
4. validate the requested slots are contiguous and inside one supported calendar day;
5. generate a booking ID;
6. run an RTDB transaction on the room/day reservation node;
7. reject if any requested slot is blocked/reserved;
8. atomically mark every requested slot with the generated booking ID and add the reservation record;
9. after the reservation transaction commits, fan out the canonical booking and read indexes using an idempotent multi-path write;
10. emit notifications/analytics after persistence.

The room/day reservation transaction is the availability source of truth. A projection failure must never reopen the slots; an idempotent reconciliation path can repair booking/index projections.

### 6.2 Approve/reject

For the initial pilot the default flow is:

```text
pending -> confirmed
pending -> rejected
```

The slots are reserved while the request is `pending`, otherwise two pending requests could be accepted for the same time.

Automatic approval can be added later as a room/studio policy after pilot metrics justify it.

### 6.3 Cancel

Cancellation must be trusted/server-side.

The room/day transaction releases only slots whose `booking_id` exactly matches the booking being cancelled. It then updates the booking status/projections idempotently.

### 6.4 Concurrency acceptance criterion

When two users concurrently request the same room/day/slots, exactly one reservation can commit.

**Target: zero double booking.**

## 7. Repository boundaries in Flutter

Existing feature repositories/controllers should be evolved rather than bypassed.

Introduce a tenant context object:

```text
StudioContext
- studioId
- membershipRole?
```

Target repository shapes:

```text
StudioRepository
RoomRepository
StudioMembershipRepository
BookingRepository
StudioBookingAdminRepository
AvailabilityRepository
SavedStudiosRepository
StudioInviteRepository
```

Booking/availability methods must always require or derive an explicit `studioId`, and room-level methods must require `roomId`.

No new code may silently fall back to a global booking/slot path.

`DatabaseService` should progressively lose high-level business rules. It may remain a low-level Firebase adapter while domain-specific repositories and trusted functions own business semantics.

## 8. Application shells and routing

Keep one Flutter codebase during the pilot.

Logical surfaces:

```text
Musician app
Studio owner/manager/staff backoffice
Platform admin backoffice
```

Introduce declarative routing before production invite links are generated.

Stable route families:

```text
/studio/{studioId-or-slug}
/invite/{inviteCode}
/booking/{bookingId}
/backoffice
/backoffice/studios/{studioId}
/platform
```

Canonical authorization always uses IDs, not slugs.

A routing library such as `go_router` is the preferred implementation candidate, but the ADR requires declarative, URL-addressable navigation rather than mandating one package.

Invite routes must preserve the intended destination across login/registration.

## 9. QR / invite semantics

QR and invite links are core distribution functionality.

Expected flow:

```text
scan/open invite link
-> resolve studio
-> unauthenticated user can view safe public studio information
-> login/signup if required
-> return to invite destination
-> save studio under "Le mie sale"
-> allow booking
```

The invite/source attribution must be recorded so later marketplace economics can distinguish studio-acquired demand from marketplace-acquired demand.

## 10. Compatibility with groups, jams and community

Groups/bands, jams and community features are preserved.

M0 does not tenant-scope groups or user identities.

A booking may reference an existing global `groupId`; the booking stores a small immutable snapshot such as `groupNameSnapshot` for display/audit resilience.

Community work is frozen except for changes strictly required by the multi-tenant booking migration.

## 11. Migration of Sound Implosion (Bracciano)

Sound Implosion is migrated as tenant #1.

Migration sequence:

1. create the Studio record for Sound Implosion;
2. create one `Room` per actual bookable room; if the legacy application exposes only one global schedule, map it to a temporary default room until the real room configuration is confirmed;
3. map existing operational admins to the appropriate Sound Implosion membership role;
4. migrate legacy slots into the selected room/day structure;
5. migrate bookings into `studios/{soundImplosionStudioId}/bookings` with room/studio IDs and legacy source metadata;
6. generate `user_bookings` projections;
7. add studio/room IDs to relevant notification payloads and deep links;
8. compare source/destination booking counts and representative dates;
9. run tenant/security/concurrency regression tests;
10. switch reads/writes to v2 repositories;
11. retain legacy data read-only for a defined rollback window;
12. remove legacy compatibility only after the pilot has passed validation.

Avoid a prolonged dual-write architecture. Prefer a controlled migration + compatibility read window + explicit cutover.

## 12. Observability

Every new operational event should include non-PII tenant context when applicable:

```text
studio_id
room_id
booking_source
booking_status
```

Required pilot observability includes:

- booking request created;
- booking confirmed/rejected/cancelled;
- manual booking created by staff;
- invite opened;
- studio saved;
- reservation transaction conflict;
- migration/reconciliation error;
- permission denial for privileged studio actions.

Do not put customer names, email addresses or free-text booking notes into analytics event parameters.

## 13. Pilot gates

Before onboarding external paying studios, the Sound Implosion pilot must demonstrate at minimum:

- zero double booking;
- tenant-isolation tests passing;
- no open P0 operational incidents;
- stable booking creation/approval/cancellation;
- owner can manage availability without direct database intervention;
- musician can reach the studio from an invite/QR flow and book independently;
- baseline vs pilot operational KPIs are measurable.

Commercial KPI targets are maintained in the project tracker rather than hard-coded into this architecture ADR.

## 14. Naming gate

The platform will use a new neutral brand. The exact name is intentionally **not** chosen during M0.

The name becomes mandatory at the following gate:

> **After the multi-tenant core and owner backoffice are stable, but before permanent public QR/invite URLs, app-store identity, public launch assets, or onboarding of the first external Founding Studio are finalized.**

At that point the project must choose:

- product name;
- primary domain;
- app-store name/package-facing display identity;
- visual identity baseline;
- customer-facing support/legal naming.

Repository/package/Firebase internal identifiers may remain legacy names if renaming them offers no customer or operational benefit.

## 15. Explicit non-goals for M0/M1

Not part of the initial multi-tenant foundation:

- national marketplace search;
- cross-studio real-time availability index;
- reviews/ratings;
- Stripe Connect booking payments;
- automated studio SaaS subscription billing;
- dynamic marketplace commission engine;
- separate native apps/codebases for musician, owner and platform admin;
- generic fine-grained ACL engine;
- Firestore migration solely for architectural cleanliness;
- major redesign of groups/jams/community;
- final platform naming/rebranding before the naming gate.

## 16. M0 implementation order

1. Domain contracts: `Studio`, `Room`, `StudioMembership`, `Booking v2`.
2. `StudioContext` and repository interfaces.
3. Target RTDB paths and migration fixtures.
4. Tenant-scoped security rules + emulator tests.
5. Trusted reservation/create/cancel booking functions.
6. Tenant-aware booking/availability repositories.
7. Sound Implosion tenant migration.
8. Concurrency, isolation and regression tests.
9. Declarative routing/deep-link foundation.
10. Cutover validation.

## 17. Acceptance tests for the architecture

M0 is not complete until automated or repeatable tests prove:

1. Owner of Studio A cannot read/write private Studio B data.
2. Manager/Staff permissions match the role matrix.
3. Musician can access only their own private booking data plus intentional public data.
4. Platform admin privilege cannot be self-assigned by a client.
5. Two concurrent requests for the same slots result in one winner.
6. Cancelling Booking X cannot release slots reserved by Booking Y.
7. A booking cannot be created without valid studio and room context.
8. Migrated booking/slot counts reconcile with the legacy Sound Implosion dataset.
9. Existing groups/jams continue to work after the booking migration.
10. Invite/deep-link destination survives authentication.

## 18. Consequences

### Positive

- fastest path from the current application to a sellable multi-studio SaaS;
- clear tenant security boundary;
- existing booking/admin/community investment is reused;
- Sound Implosion becomes a real production validation tenant;
- future marketplace, billing and payments remain possible without being required now.

### Costs / trade-offs

- RTDB requires intentional denormalized indexes and reconciliation logic;
- room/day transaction design constrains first-version bookings to a supported calendar-day boundary;
- existing global admin and database paths require a controlled migration;
- one codebase will contain multiple product surfaces until product maturity justifies separation;
- public discovery may later need a dedicated search projection/index as the number of studios grows.

## 19. Revisit triggers

Revisit this ADR if any of these become true:

- RTDB query/index limitations materially block national discovery or reporting;
- write contention on room/day reservation nodes becomes measurable;
- owner and musician release cycles diverge enough to justify separate applications;
- payment/regulatory requirements require a different booking/payment boundary;
- the platform expands beyond rehearsal-room scheduling into resource types that do not fit the `Studio -> Room -> Booking` model.
