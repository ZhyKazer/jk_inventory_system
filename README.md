# JK Inventory System

JK Inventory System is an offline-first Flutter inventory management app that tracks:

- Categories and products
- Incoming stock batches
- Daily outing/return/sold/discard flows
- Activity logs for auditability
- Analytics summaries
- Local backup and restore

The current implementation uses Hive as the local source of truth, while the repository layer is already structured to support a future cloud/Firebase sync implementation.

## Table of Contents

1. [Project Status](#project-status)
2. [Core Features](#core-features)
3. [Tech Stack](#tech-stack)
4. [Project Structure](#project-structure)
5. [Data Layer and Architecture](#data-layer-and-architecture)
6. [Getting Started](#getting-started)
7. [Run and Build Commands](#run-and-build-commands)
8. [Backup and Restore](#backup-and-restore)
9. [Cloud/Firebase Readiness](#cloudfirebase-readiness)
10. [Testing and Debugging](#testing-and-debugging)
11. [Common Development Tasks](#common-development-tasks)
12. [Roadmap](#roadmap)
13. [Contributing](#contributing)
14. [Important Files](#important-files)
15. [Copyright and Usage](#copyright-and-usage)

## Project Status

- App type: Flutter mobile-first application (Android/iOS), with desktop/web platform folders present.
- Persistence: Fully local via Hive.
- Sync: Cloud sync is not enabled yet.
- Current app version in `pubspec.yaml`: `1.0.6-BnM.4`
- Dart SDK constraint: `^3.10.1`

## Core Features

- Category CRUD with color tagging
- Product CRUD with category assignment and pricing fields
- Stock batch creation and tracking (incoming inventory)
- Outing stepper workflow (displayed, returned, discarded, replaced, sold)
- Activity log tracking key inventory actions
- Product search/filter support
- Monthly and yearly analytics page
- Backup and restore workflows (JSON/ZIP-based)
- Theme options (light/dark/custom seed color)

## Tech Stack

- Flutter (Material 3)
- Hive + Hive Flutter (local data persistence)
- Provider-style state holders (project uses provider classes under `lib/providers`)
- UUID (entity IDs)
- Intl (date/number formatting)
- File/system utilities for backup features:
  - `file_picker`
  - `path`
  - `path_provider`
  - `permission_handler`
  - `archive`
  - `image`
  - `shared_preferences`
  - `package_info_plus`

## Project Structure

```text
lib/
  main.dart
  models/
    activity_log.dart
    category.dart
    outing_record.dart
    product.dart
    stock_batch.dart
    unit_type.dart
  providers/
    activity_log_provider.dart
    category_provider.dart
    outing_provider.dart
    product_provider.dart
    stock_batch_provider.dart
  repositories/
    activity_log_repository.dart
    category_repository.dart
    inventory_repo_interfaces.dart
    outing_repository.dart
    product_repository.dart
    stock_batch_repository.dart
  services/
    backup_service.dart
    inventory_stock_calculator.dart
    inventory_storage.dart
    cloud_sync/
      cloud_inventory_repo_stub.dart
  ui/
    pages/
      activity_log_page.dart
      analytics_page.dart
      batches_page.dart
      categories_page.dart
      create_batch_page.dart
      home_shell.dart
      outing_stepper_page.dart
      products_page.dart
    widgets/
      forms/
        category_form_sheet.dart
        product_form_sheet.dart
docs/
  firebase_sync.md
Master_Task.md
Backup.md
```

## Data Layer and Architecture

### High-level flow

1. `main.dart` initializes storage via `InventoryStorage.initialize()`.
2. Hive adapters (typeIds `0..4`) are registered and boxes are opened.
3. `InventoryStorage.localRepo()` returns a local repository facade.
4. Providers load data from repositories.
5. UI pages consume providers and trigger repository-backed operations.

### Domain models (Hive adapters)

- `Category` (`typeId = 0`)
- `Product` (`typeId = 1`)
- `StockBatch` (`typeId = 2`)
- `OutingRecord` (`typeId = 3`)
- `ActivityLog` (`typeId = 4`)

### Repository abstraction

`lib/repositories/inventory_repo_interfaces.dart` defines interfaces for:

- Product repository
- Category repository
- Stock batch repository
- Outing repository
- Activity log repository
- `LocalInventoryRepo` facade
- `CloudInventoryRepo` placeholder

This provides a clean migration path from local-only storage to local-plus-cloud architecture.

## Getting Started

### Prerequisites

- Flutter SDK compatible with Dart `^3.10.1`
- Android Studio/Xcode (for device tooling)
- A connected device or emulator/simulator

### Setup

1. Clone repository

```bash
git clone https://github.com/ZhyKazer/jk_inventory_system.git
cd jk_inventory_system
```

2. Install dependencies

```bash
flutter pub get
```

3. Run the app

```bash
flutter run
```

## Run and Build Commands

### Development

```bash
flutter run
```

### Analyze

```bash
flutter analyze
```

### Test

```bash
flutter test
```

### Build APK (Android)

```bash
flutter build apk
```

### Build App Bundle (Android)

```bash
flutter build appbundle
```

### Build iOS (macOS only)

```bash
flutter build ios
```

## Backup and Restore

The project contains an implemented backup service in `lib/services/backup_service.dart`.

### What it does

- Exports backup payloads as `.zip` (with JSON and related product images)
- Supports manual import from `.zip` or `.json`
- Persists selected backup directory in shared preferences
- Applies retention policy (`maxBackupFiles = 10`)
- Provides recent backup listing for quick restore workflows
- Validates backup integrity during create/restore flow

### Related design notes

- `Backup.md` documents requirements and UX expectations for backup/restore behavior.

## Cloud/Firebase Readiness

The app is intentionally structured for future sync.

- Interface abstractions are already present in `lib/repositories/inventory_repo_interfaces.dart`.
- `lib/services/cloud_sync/cloud_inventory_repo_stub.dart` is a placeholder for future cloud implementation.
- `docs/firebase_sync.md` contains design notes and a checklist for introducing Firebase/cloud sync safely.

Current behavior remains offline-first with Hive as the source of truth.

## Testing and Debugging

- Run unit/widget tests:

```bash
flutter test
```

- Use analyzer/lints:

```bash
flutter analyze
```

- If local data appears inconsistent during development:
  - Use the in-app backup before destructive testing.
  - Clear app data on emulator/device and relaunch to recreate boxes.

## Common Development Tasks

### Add a new persisted entity

1. Add model + Hive adapter in `lib/models`.
2. Assign a unique `typeId`.
3. Register adapter and open box in `lib/services/inventory_storage.dart`.
4. Add repository methods in `lib/repositories`.
5. Wire provider loading/updating in `lib/providers`.
6. Add UI entry points/forms under `lib/ui/pages` and `lib/ui/widgets`.
7. Add activity logging where user-visible data changes occur.

### Extend analytics

1. Add metric logic in services/provider layer (if needed).
2. Update `lib/ui/pages/analytics_page.dart` with new summaries/graphs.
3. Verify performance with realistic data size.

### Add cloud sync later

1. Extend repository interfaces to full parity.
2. Implement cloud repository in `lib/services/cloud_sync`.
3. Add sync coordinator and conflict strategy.
4. Keep local writes authoritative until sync is proven stable.

## Roadmap

- Complete cloud repository and sync coordinator implementation
- Add integration tests for backup/restore and sync flows
- Improve empty states and validation UX where needed
- Expand automated test coverage beyond baseline widget tests
- Add CI quality gates for lint/test/build

## Contributing

1. Review `Master_Task.md` and related docs before major changes.
2. Keep architecture boundaries clear:
   - models -> repositories -> providers -> UI
3. Keep Hive type IDs unique and stable.
4. Prefer small, focused PRs with clear scope.
5. Include screenshots/GIFs for UI changes and reproduction steps for bug fixes.

## Important Files

- `lib/main.dart`: App bootstrap, provider wiring, theme selection
- `lib/services/inventory_storage.dart`: Hive init, adapter registration, local repo facade
- `lib/services/backup_service.dart`: Backup, retention, import/restore logic
- `lib/repositories/inventory_repo_interfaces.dart`: Repository interfaces and cloud placeholder contract
- `lib/ui/pages/home_shell.dart`: Main shell/navigation entry
- `lib/ui/pages/outing_stepper_page.dart`: Daily outing workflow UI
- `lib/ui/pages/analytics_page.dart`: Analytics summaries and chart rendering
- `docs/firebase_sync.md`: Cloud sync planning notes
- `Master_Task.md`: Product planning/spec
- `Backup.md`: Backup/restore specification notes

## Copyright and Usage

Copyright (c) 2026 SkyeLucas

All rights reserved.

This source code and associated files may not be copied, modified, distributed, or used in any form without explicit written permission from the author.
