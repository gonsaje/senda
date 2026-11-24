# Senda backend API

Proposed first release. Keep training usable offline. Offer an account in Profile and ask before syncing the existing notebook to that account.

## Deployment and ownership

Run one Java 21 Spring Boot service for iOS and, later, Android and web. Use Spring MVC, Spring Security, PostgreSQL JDBC with HikariCP, and Flyway migrations. Put the service in the same AWS region as the Neon project.

| Component | Responsibility |
| --- | --- |
| iPhone | Save each edit locally. After sync is enabled, persist the pending operation with that edit. Resume after relaunch. |
| Neon Auth | Authenticate with Apple, Google, or email code. Let a signed-in person verify an additional sign-in method. |
| Senda API | Validate the Neon bearer token, map its issuer and subject to a Senda account, enforce ownership, and apply sync transactions. |
| Neon Postgres | Store account mappings, workout records, and change history. The API uses a restricted runtime role. Schema changes use a separate migration role. |

The client needs the public Auth URL and Senda API URL. Keep the database connection string and provider secrets server-side. Configure an Ed25519-capable JWT verifier with Neon's published keys, validate expiry, issuer and audience, and use the verified subject for ownership. Email is a contact attribute and can change. Apply the owner constraint to each read and write, including nested set IDs.

## First HTTP contract

| Endpoint | Behavior |
| --- | --- |
| `GET /v1/me` | Return the signed-in person's stable Senda account ID. Resolve the verified identity in Postgres, with a unique issuer/subject mapping even on concurrent first requests. |
| `POST /v1/sync/push` | Accept a bounded list of operations. Each carries a client mutation ID, entity ID, expected revision, and typed payload. Return a result per operation. A logged batch and all its sets form one operation. |
| `GET /v1/sync/changes?cursor=…` | Page through this account's changes in server commit order, including deletions. Omit the cursor on first sync. Return an opaque next cursor and whether more pages are available. |

Use these same write and read paths for the first import and for subsequent edits. A separate bulk upload of the entire backup would couple the API to the export format and could include body measurements and unfinished edits. The first sync covers recorded workouts and the exercise definitions they reference. Draft inputs, Apple Health readings, and manual body measurements stay local in this release.

## Records and sync

- **Accounts.** Create a Senda account ID once. A verified additional provider for the same Neon user resolves to that account. On sign-out, stop sync and retain the local notebook. When another account signs in, isolate pending writes by owner and ask before importing any unclaimed notebook.
- **Workout identity.** Store the local training date as a calendar date. Preserve exercise order, archived custom exercise names, batch IDs, performed-set UUIDs, drop-set grouping, and canonical integer loads in hundredths of a pound. A partial correction keeps the previous recorded value until the edit is valid.
- **Retries.** Store each successful mutation receipt, entity change, and change-feed entry in one transaction. Scope receipt uniqueness to the owner and mutation ID. A retry of the same payload returns the original result. A reused ID with different content is rejected. Retain deletion records so a delayed device cannot resurrect an undone set.
- **Concurrent edits.** Version the records that can change independently. Accept separate batches on the same day. For incompatible edits to the same batch, return a conflict with its current revision and preserve the local edit for resolution. Use a per-account change counter serialized in the write transaction so a client cursor cannot skip a late commit.
- **First sync.** Let the user opt in, preserve original IDs, fetch remote changes, and reconcile by ID and revision before uploading missing records. Identical weights and reps can represent different sets. Two devices submitting distinct sets must retain both.

## First end-to-end proof

1. Sign in with a test account on the iPhone. Call `GET /v1/me` through the running Spring service and confirm the returned ID corresponds to the row in Neon Postgres. An unauthenticated request must receive 401.
2. Log a batch offline, restart Senda, enable sync, and interrupt the response after the server commits. Retry and confirm a second device receives the original set IDs exactly once.
3. Correct one set, undo a batch, and sync the second device. Confirm its history matches, including deletions. A different account must never see or modify those records.
4. Verify Apple with Hide My Email, explicitly link Google, and sign back in with Google. Check that `GET /v1/me` returns the original account ID. Verify email-code sign-in separately.

Before opening account creation to the public, include in-app account deletion, session revocation, and cloud data deletion. Trainer approvals and publishing can later use the same verified account ID with a server-assigned trainer role.

Provider references are [Neon Auth JWT verification](https://neon.com/docs/auth/guides/plugins/jwt), [social provider configuration](https://neon.com/docs/auth/guides/setup-oauth), and [email codes](https://neon.com/docs/auth/guides/plugins/email-otp).
