# Firebase Connection Plan

## Objective
Define how account auth, roles, and inventory domain data are stored in Firebase with a single source of truth per entity (no duplicate documents for the same product/category/batch/outing/activity).

## Scope (Planning Only)
- Add a Login screen UI (do not enforce app-wide login yet).
- Add Account Registration entry in Settings sidebar.
- Compile backup actions into one parent backup button that opens backup options.
- Add role-based access design (View, Moderator, Admin).
- Define Firebase Authentication + Firestore mapping.
- Define Firestore structure to avoid duplicate storage.

## UI/Navigation Changes (Planned, Not Implemented Yet)
1. New Login screen
- Username input
- 4-digit numeric PIN input
- Keep optional/disabled routing guard for now so admin account can be prepared first.

2. Settings sidebar
- Add button: Register Account
- Replace multiple backup buttons with one button (ex: Backup Options) that opens:
  - Backup Data
  - Restore Data
  - Import Backup

3. Account Registration screen behavior
- Registration action is intended for Admin only (enforce later).
- Must allow choosing role at account creation:
  - view
  - moderator
  - admin

## Firebase Services and Responsibilities
1. Firebase Authentication
- Stores account identity and login credentials.
- Use email/password as the auth provider in the backend.
- Username is not an auth identifier in Firebase Auth; it is app profile metadata in Firestore.

2. Cloud Firestore
- Stores app profile data and domain entities.
- Stores user role and username by auth uid.
- Stores inventory, categories, batches, outings, and activities.

## Account Model

### Registration (Admin/Employee)
Recommended pattern:
- Admin creates account with generated email alias (for example: username@bnm.co) + 4-digit PIN policy handled by app/backend workflow.
- PIN must never be saved as plain text in Firestore.
- For strict PIN-only UX, keep username + PIN on app side and map to Auth sign-in using the generated email.

### Login
- User enters username + 4-digit PIN.
- App resolves username -> uid/auth alias via Firestore.
- App signs in using Firebase Auth credentials.
- After sign-in, app reads role document from Firestore users/{uid}.

## Firestore Structure (Single Source of Truth)

Use top-level collections with deterministic unique IDs from your current local IDs.

```text
/users/{uid}
/categories/{categoryId}
/products/{productId}
/stockBatches/{batchId}
/outings/{outingId}
/activities/{activityId}
```

### 1) users/{uid}
Document ID: Firebase Authentication uid (exactly 1 profile per auth user)

```json
{
  "uid": "auth_uid",
  "username": "john",
  "usernameLower": "john",
  "role": "admin", 
  "isActive": true,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp",
  "createdByUid": "admin_uid"
}
```

Rules:
- One uid -> one user profile document.
- Add unique check for usernameLower in creation flow to prevent duplicate usernames.

### 2) categories/{categoryId}
Document ID: category.id from app

```json
{
  "id": "cat_001",
  "name": "Bread",
  "colorHex": "#FFA726",
  "requireProductImage": true,
  "allowFlexibleSellingPrice": false,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

Rules:
- Category stored once only here.
- Products reference categoryId; do not copy category payload into products.

### 3) products/{productId}
Document ID: product.id from app

```json
{
  "id": "prod_001",
  "categoryId": "cat_001",
  "name": "Bun",
  "imagePath": "gs://... or https://... or null",
  "costPrice": 12.5,
  "sellingPrice": 18.0,
  "createdAt": "Timestamp",
  "updatedAt": "Timestamp"
}
```

Rules:
- Product stored once only here.
- Never duplicate full product objects in batches/outings/activities; store productId references in those documents.

### 4) stockBatches/{batchId}
Document ID: stockBatch.id from app

```json
{
  "id": "batch_001",
  "batchName": "Morning Batch",
  "createdAt": "Timestamp",
  "items": [
    {
      "productId": "prod_001",
      "unitType": "quantity",
      "unitValue": 24,
      "originalPrice": 12.5,
      "sellingPrice": 18.0
    }
  ]
}
```

Rules:
- Batch exists once.
- Item lines reference productId only.
- Keep transactional prices (originalPrice/sellingPrice at batch creation) in batch line since this is historical event data, not product duplication.

### 5) outings/{outingId}
Document ID: outing.id from app

```json
{
  "id": "outing_001",
  "date": "Timestamp",
  "status": "draft",
  "displayedProducts": [{ "productId": "prod_001", "unitType": "quantity", "value": 10, "sellingPriceOverride": null }],
  "returnedProducts": [{ "productId": "prod_001", "unitType": "quantity", "value": 2, "sellingPriceOverride": null }],
  "discardedProducts": [{ "productId": "prod_001", "unitType": "quantity", "value": 1, "sellingPriceOverride": null }],
  "replacedDiscardedProducts": [{ "productId": "prod_001", "unitType": "quantity", "value": 1, "sellingPriceOverride": null }],
  "submittedAt": "Timestamp or null",
  "totalDisplayed": 10,
  "totalReturned": 2,
  "totalDiscarded": 1,
  "totalReplaced": 1,
  "totalSold": 7,
  "totalRevenue": 126,
  "totalCapital": 87.5,
  "approximateProfit": 38.5
}
```

Rules:
- Outing exists once.
- Product references use productId only.
- Totals are allowed here because they are derived snapshot results for that outing record itself.

### 6) activities/{activityId}
Document ID: activity.id from app

```json
{
  "id": "act_001",
  "actionType": "productCreated",
  "title": "Product created",
  "description": "Created Bun",
  "referenceId": "prod_001",
  "createdAt": "Timestamp",
  "displayed": null,
  "returned": null,
  "discarded": null,
  "replaced": null,
  "sold": null,
  "profit": null,
  "lost": null,
  "productDetails": "json string or null",
  "actorUid": "auth_uid"
}
```

Rules:
- Activity log is append-only history.
- It may include event snapshot fields for audit/history, but not become a second source of truth for products/categories.

## Role and Permission Matrix

Feature keys:
- C = Create
- R = Read
- E = Edit
- D = Delete

| Role | Product | Category | Stock | Outing | Analytics | Activities |
|---|---|---|---|---|---|---|
| view | R | R | R | R | R | R |
| moderator | R | R | R | C/R/E | C/R | C/R |
| admin | C/R/E/D | C/R/E/D | C/R/E/D | C/R/E/D | R | R |

UI Behavior:
- View can open and read all listed modules but cannot mutate any data.
- Moderator can open and read all listed modules, can create/edit outing records, and can create analytics/activity records.
- Disable/hide mutation buttons per module based on table permissions.

## Consistency and No-Duplicate Rules

### Scalable ID Format Policy (Adopted)

Use the following human-readable IDs for product and category records:

- Product ID format: prod_AAAA_0001
- Category ID format: cat_AAAA_0001

Validation:
- Product regex: ^prod_[A-Z]{4}_[0-9]{4}$
- Category regex: ^cat_[A-Z]{4}_[0-9]{4}$
- Numeric range: 0001 to 9999 (0000 reserved as invalid)

Rollover examples:
- AAAA_9999 -> AAAB_0001
- AAAZ_9999 -> AABA_0001
- AAZZ_9999 -> ABAA_0001

Important:
- IDs are immutable once created.
- Do not reuse deleted IDs.
- Use transaction-safe ID generation to avoid collisions when multiple clients create records.

Capacity:
- Alpha blocks: 26^4 = 456,976
- Per-block numeric slots: 9,999
- Total capacity per entity type: 4,569,303,024

1. ID authority
- Use existing model IDs as Firestore document IDs.
- Never create a second document for the same logical entity under another ID.

2. Write strategy
- Use set/update against known document path for updates.
- Use transaction/batch writes for multi-document operations.

3. Reference strategy
- Cross-entity references use IDs only (for example productId, categoryId, referenceId).
- Do not embed complete product/category payloads in other collections.

4. Analytics strategy
- Prefer query-time analytics from outings/activities.
- If caching analytics, use deterministic doc IDs (for example analytics/daily_YYYY_MM_DD) and treat as cache-only.

5. Username uniqueness
- Enforce usernameLower uniqueness in registration flow before account creation is finalized.

6. Soft-delete policy (optional)
- If needed later, use isArchived flag instead of duplicating documents into archive collections.

## Suggested Firestore Indexes
- users: usernameLower (ascending)
- products: categoryId + name
- outings: date desc
- activities: createdAt desc
- activities: actionType + createdAt desc

## Security Rule Intent (High-Level)
- Auth required for all app data.
- user role read from users/{uid}.
- admin: read/write all inventory collections.
- moderator: read all collections, write for outing + analytics + activities where allowed by workflow.
- view: read-only access.

## Implementation Phasing

Phase 1 (Now)
- Finalize this plan and schema.
- Prepare Firebase project + collections.
- Seed first admin account.

Phase 2
- Build Login screen UI (username + 4-digit PIN).
- Add Register Account button in Settings sidebar.
- Merge backup buttons into Backup Options menu.

Phase 3
- Implement registration workflow and role assignment.
- Connect login to Firebase Auth + users profile lookup.

Phase 4
- Enforce role-based UI button disable/hide behavior.
- Add backend security rules according to role matrix.

Phase 5
- Enable login enforcement after admin account creation is verified.

## Notes for Your Existing Models
This plan directly matches current domain entities already present in the app:
- Category
- Product
- StockBatch (with BatchItem lines)
- OutingRecord (with OutingLine lists)
- ActivityLog

That mapping keeps each entity in exactly one primary Firestore collection and prevents duplicate documents for the same product or other records.
