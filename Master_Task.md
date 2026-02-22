# Master Task - JK Inventory System

## 1) Project Goal
Build a Flutter Inventory System with local persistence using **Hive**.

### Platform Scope
- Mobile application only: **Android** and **iOS**.
- No web/desktop implementation in MVP.

### In Scope (Now)
- CRUD for **Products**
- CRUD for **Categories**
- Stock **Batch In** flow (incoming inventory)
- **Outing / Sold / Returned / Discarded / Replaced** daily stepper flow
- **Activity Log** for all major inventory actions
- Bottom navigation with pages:
  - Product List
  - Batch List & History
- Floating Action Button actions for:
  - Add Product
  - Add Category
  - Add Stock Batch
  - Start Outing Flow

### Out of Scope (For Now)
- Firebase cloud sync implementation
- Authentication and user roles
- Multi-device conflict resolution

---

## 2) Tech Stack
- Flutter (Material 3)
- State Management: `ChangeNotifier` or `Riverpod` (choose one during implementation)
- Local DB: **Hive**
- Cloud: Firebase (prepare architecture only, do not implement yet)

### Build Targets
- Android (phone/tablet)
- iOS (phone/tablet)

---

## 3) Core Data Models

## 3.1 Category
- `id` (String/UUID)
- `name` (String, required, unique)
- `colorHex` (String, required)
- `createdAt` (DateTime)
- `updatedAt` (DateTime)

## 3.2 Product
- `id` (String/UUID)
- `name` (String, required, unique)
- `categoryId` (String, required)
- `createdAt` (DateTime)
- `updatedAt` (DateTime)

## 3.3 Stock Batch (Incoming)
- `id` (String/UUID)
- `batchName` (String, format: `Batch_MM_DD_YYYY-UID`)
- `createdAt` (DateTime)
- `items` (List<BatchItem>)
- `totalItems` (int, derived)

### BatchItem
- `productId` (String, required)
- `unitType` (enum: `quantity`, `kilo`)
- `unitValue` (double, required, > 0)
- `price` (double, required, >= 0)

## 3.4 Daily Outing Record
- `id` (String/UUID)
- `date` (Date only)
- `status` (draft/submitted)
- `steps` data:
  - displayedProducts (List<OutingLine>)
  - returnedProducts (List<OutingLine>)
  - discardedProducts (List<OutingLine>)
  - replacedDiscardedProducts (List<OutingLine>)
- `summary` (calculated values)
- `submittedAt` (DateTime?)

### OutingLine
- `productId` (String)
- `unitType` (enum: `quantity`, `kilo`)
- `value` (double, > 0)

## 3.5 Inventory Ledger (Recommended)
Event-based stock movement log for accurate calculations.
- `id`
- `productId`
- `movementType`:
  - `batch_in`
  - `displayed_out`
  - `returned_in`
  - `discarded_out`
  - `discarded_replaced_in`
- `unitType`
- `value`
- `price` (nullable except batch-in)
- `referenceId` (batch id / outing id)
- `createdAt`

## 3.6 Activity Log
Tracks user-visible history of important actions for auditability.
- `id` (String/UUID)
- `actionType` (enum):
  - `category_created`
  - `category_updated`
  - `category_deleted`
  - `product_created`
  - `product_updated`
  - `product_deleted`
  - `batch_created`
  - `outing_submitted`
- `title` (String, short readable event title)
- `description` (String, event details)
- `referenceId` (String, optional related entity id)
- `createdAt` (DateTime)

---

## 4) Business Rules & Validations

## 4.1 Category Rules
- Name is required and unique (case-insensitive).
- Color is required.
- Prevent delete if category is used by products, or require reassignment.

## 4.2 Product Rules
- Name is required and unique (case-insensitive).
- Category is required.
- Prevent delete if product has inventory history, or perform soft delete.

## 4.3 Batch In Rules
- Must have at least one item.
- Each item requires product, price, unit type, and value.
- Unit value must be > 0.
- Price must be >= 0.
- Allow multiple products per batch.
- Batch name must auto-generate as `Batch_MM_DD_YYYY-UID`.

## 4.4 Outing Stepper Rules
1. **Collect Displayed Products**
   - Enter product and amount displayed from storage today.
   - Must not exceed current available stock.
2. **Returned Product Today**
   - Returned amount must not exceed displayed amount for same product.
3. **Discarded Products**
   - Must not exceed currently available stock constraints for the day flow.
4. **Returned Discarded Products**
   - Must not exceed total discarded amount for same product.
5. **Review Inputs**
   - Show all entries and validation warnings before submit.
6. **Calculation**
   - Compute net stock change per product and final stock snapshot.

## 4.5 Activity Log Rules
- Log an activity record when category/product is created, edited, or deleted.
- Log a record when a stock batch is created.
- Log a record when outing flow is submitted.
- Activity list is read-only in MVP (no manual create/edit/delete).
- Sort by latest first.

---

## 5) UI / Navigation Requirements

### Mobile UX Constraints
- Mobile-first layouts only.
- Forms and stepper must be optimized for touch input.
- Support portrait orientation as primary layout.
- Use responsive spacing for phone and tablet screens.

## 5.1 Bottom Navigation
- Page 1: **Product List**
- Page 2: **Batch List & History**
- Page 3: **Activity Log**

## 5.2 Floating Action Button (Global)
Open menu/speed dial with actions:
- Add Product
- Add Category
- Add Stock Batch
- Start Outing Flow

## 5.3 Screens
- Category CRUD screens/dialogs
- Product CRUD screens/dialogs
- Batch creation form (multi-item)
- Batch history list + detail view
- Outing stepper (6 steps)
- Daily review summary screen
- Activity log list screen

---

## 6) Feature Task Breakdown

## Phase 1 - Foundation
- [x] Set up folder architecture (`models`, `services`, `repositories`, `providers`, `ui/pages`, `ui/widgets`).
- [x] Add Hive packages and initialize Hive in app startup.
- [x] Register Hive adapters for all entities.
- [x] Create app theme and base scaffold with bottom nav.

## Phase 2 - Category CRUD
- [x] Create Category model + Hive type adapter.
- [x] Create Category repository/service methods: create, read, update, delete.
- [x] Build Category form (name + color picker).
- [x] Add validations (required, unique name).
- [x] Add category list UI.

## Phase 3 - Product CRUD
- [x] Create Product model + Hive adapter.
- [x] Create Product repository/service methods: create, read, update, delete.
- [x] Build Product form (category + product name).
- [x] Add validations (required fields, unique product name).
- [x] Add product list UI with category chips/color.

## Phase 4 - Batch In Flow
- [ ] Create StockBatch and BatchItem models + adapters.
- [ ] Create batch naming utility `Batch_MM_DD_YYYY-UID`.
- [ ] Build multi-item batch creation UI:
  - [ ] Choose product
  - [ ] Enter price
  - [ ] Choose unit (`quantity` or `kilo`)
  - [ ] Enter value
  - [ ] Add/remove row
- [ ] Save batch + generate inventory ledger entries.
- [ ] Build Batch List & History page.
- [ ] Build batch detail page.

## Phase 5 - Outing Stepper Flow
- [ ] Create OutingRecord + OutingLine models + adapters.
- [ ] Build 6-step stepper:
  - [ ] Collect Displayed Products
  - [ ] Returned Product Today
  - [ ] Discarded Products
  - [ ] Returned Discarded Products
  - [ ] Review User Inputs
  - [ ] Calculation
- [ ] Add all stock bound validations at each step.
- [ ] On submit, write ledger movements and update computed stock.
- [ ] Save outing history by date.

## Phase 6 - Inventory Computation Engine
- [ ] Implement stock calculator from ledger events.
- [ ] Support both unit types (`quantity`, `kilo`) safely.
- [ ] Prevent cross-unit math for same product unless explicitly handled.
- [ ] Expose helper methods:
  - [ ] currentStock(productId, unitType)
  - [ ] displayedLimit(productId, date)
  - [ ] discardedLimit(productId, date)

## Phase 7 - Activity Log
- [ ] Create ActivityLog model + Hive adapter.
- [ ] Create activity logger service for write-on-event behavior.
- [ ] Add log hooks to Category/Product CRUD operations.
- [ ] Add log hook when batch is created.
- [ ] Add log hook when outing is submitted.
- [ ] Build Activity Log page (latest first, read-only).

## Phase 8 - UX Hardening
- [ ] Empty states for all list pages.
- [ ] Error messages for invalid inputs.
- [ ] Confirmation dialogs for destructive actions.
- [ ] Basic search/filter in product list (optional MVP+).

## Phase 9 - Firebase-Ready Architecture (No Implementation)
- [ ] Define repository interfaces (`LocalInventoryRepo`, `CloudInventoryRepo`).
- [ ] Keep domain layer independent from Hive implementation.
- [ ] Add TODO markers and docs for future Firebase sync.

---

## 7) Acceptance Criteria
- [ ] User can fully CRUD categories with name and color.
- [ ] User can fully CRUD products with category and name.
- [ ] User can create a batch with multiple items and valid units/values/prices.
- [ ] Batch names follow `Batch_MM_DD_YYYY-UID`.
- [ ] User can complete outing stepper with strict quantity/kilo validations.
- [ ] Calculations correctly adjust stock.
- [ ] Product list shows all registered products.
- [ ] Batch list/history shows all batches and details.
- [ ] Activity Log shows major actions in reverse chronological order.
- [ ] Data persists across app restarts via Hive.
- [ ] No Firebase code execution yet.
- [ ] App runs correctly on Android and iOS devices.

---

## 8) Suggested Initial Dependencies
- `hive`
- `hive_flutter`
- `uuid`
- `intl`
- `flutter_colorpicker` (or equivalent)

---

## 9) Notes for Implementation
- Keep all stock updates event-driven via ledger entries.
- Prefer soft delete for entities with historical references.
- Add seed/demo data only in debug mode.
- Build MVP first, then refine UX.

---

## 10) Delivery Milestones
- Milestone 1: Category + Product CRUD complete.
- Milestone 2: Batch In complete with history.
- Milestone 3: Outing stepper complete with validations and calculations.
- Milestone 4: Activity Log complete.
- Milestone 5: Firebase-ready architecture cleanup and documentation.
