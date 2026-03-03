# Firebase-ready architecture notes

This document contains notes and TODOs to prepare the codebase for a future Firebase/cloud sync implementation without changing app behavior today.

Goals
- Keep the domain layer independent from Hive implementation details.
- Introduce repository interfaces and a cloud implementation that can be swapped at runtime or used for sync.
- Minimize data-loss risk by continuing to write authoritative events to the local ledger (inventory ledger) and shipping those events to the cloud.

Short checklist
- [ ] Implement `CloudInventoryRepo` (mirrors `LocalInventoryRepo`) using Firestore/Realtime Database.
- [ ] Add a sync coordinator service that reconciles local ledger events with cloud records.
- [ ] Add opt-in settings and conflict resolution strategy (last-writer-wins or vector clocks depending on complexity).
- [ ] Add integration tests for sync and a small sample dataset for manual verification.

Where to start
- The file `lib/repositories/inventory_repo_interfaces.dart` contains the initial interface types. Extend them to include other domain persistence APIs (batches, outings, activity logs).
- Implement a `CloudInventoryRepo` in `lib/services/cloud_sync/` and keep all network code isolated there.
- Wire an adapter in startup (e.g. a factory in `lib/services/inventory_storage.dart`) to pick local-only or local+cloud modes.

Notes
- Do not enable cloud writes automatically — keep the app fully functional offline-first with Hive as the source of truth until sync is explicitly enabled.
- Use small transactions for batch uploads and idempotent event IDs (UUIDs present in domain models) to avoid duplicates.
