# Backup & Restore Specification (Phase 9)

## Goal
Provide a user-controlled backup/restore system using JSON files, stored in a user-accessible directory, with retention and restore visibility rules.

---

## Functional Requirements

### 1) Backup button in Settings
- Add a **Backup Data** button in Settings.
- On press, app exports all current app data into a JSON backup file.

### 2) First-time backup directory selection
- On first backup click, user must choose a backup folder using system file manager.
- Selected folder path/URI is saved for future backups.
- If folder access is revoked or invalid later, prompt user to re-select.

### 3) Backup filename format
- Backup file naming pattern:
  - `backup_<sequence>_<DD_MM_YYYY>_<HH_mm_ss>.json`
- Example:
  - `backup_1_03_03_2026_14_20_55.json`
- `sequence` increments from existing backups in selected directory.

### 4) Retention policy (max 10)
- Keep maximum of **10 backups** in backup directory.
- When creating backup #11+, auto-delete oldest backup(s) by timestamp in filename/metadata.

### 5) Restore list visibility policy
- In app restore UI, show only the **5 most recent backups**.
- Older backups (up to max 10 total) are considered **archive**:
  - Not listed in normal restore list.
  - Can still be restored only via **Import Backup** action (manual file selection).

### 6) Persistence requirements
- Backups must be saved outside app cache/temp.
- Clearing app cache must not delete backups.
- Uninstall/reinstall should not delete backups **if stored in user-selected external/document directory**.
- Note: persistence behavior depends on OS policies and selected location permissions.

### 7) Import support
- User can import any backup file from file manager.
- Imported file must pass JSON schema/format validation.
- Reject invalid backup files with user-friendly error message.

---

## Non-Functional Requirements

1. **Data integrity**
   - Write backup atomically (temp file then rename).
   - Include app version and schema version in JSON.

2. **Error handling**
   - Handle permission denial, no storage access, invalid path, malformed JSON.
   - Show clear snackbar/dialog messages.

3. **Performance**
   - Backup operation should run async and show progress/loading indicator.

4. **Security**
   - Do not include secrets/tokens in backup unless explicitly required.
   - Validate imported content before restore.

---

## JSON Backup Format (Proposed)

```json
{
  "meta": {
    "schemaVersion": 1,
    "appVersion": "x.y.z",
    "createdAt": "2026-03-03T14:20:55Z",
    "device": "optional"
  },
  "data": {
    "products": [],
    "inventory": [],
    "transactions": [],
    "settings": {}
  }
}
```

---

## UX Flow

### Backup
1. User taps **Backup Data**.
2. If no folder saved: open directory picker.
3. Export data -> create JSON -> save file.
4. Enforce max 10 backups (delete oldest if needed).
5. Show success message with file name/path.

### Restore (quick)
1. User taps **Restore Data**.
2. Show 5 most recent backups only.
3. User selects one -> validate -> confirm overwrite -> restore.

### Import (archive/manual)
1. User taps **Import Backup**.
2. Open file picker.
3. Validate JSON format/schema.
4. Confirm overwrite -> restore.

---

## Acceptance Criteria

- [ ] Backup button exists in Settings and exports JSON.
- [ ] First backup prompts folder selection.
- [ ] Backups saved to user-accessible folder.
- [ ] Filename matches required pattern.
- [ ] Max 10 backups retained; oldest auto-deleted.
- [ ] Restore list shows only latest 5.
- [ ] Archive backups restorable only via Import.
- [ ] Cache clear does not remove backups.
- [ ] Uninstall does not remove backups when directory is external/user-managed.
- [ ] Import accepts valid backup schema and rejects invalid files.
- [ ] Clear user feedback for success/failure states.

---

## Technical Notes for Flutter (Implementation Direction)

- Suggested packages:
  - `file_picker` (directory/file selection)
  - `path` (filename/path handling)
  - `dart:io` (file operations)
- Android: use SAF-compatible URIs where needed.
- Desktop (Windows): use selected folder path and normal file I/O.
- Store selected backup location in persistent settings (e.g., SharedPreferences/local DB).

---

## Open Questions (to finalize before coding)

1. Exact data entities to include in backup (`products`, `sales`, `customers`, etc.)?
2. Should restore fully overwrite current DB or merge?
3. Should backups be optionally encrypted/password-protected?
4. Should import also copy file into backup directory or just restore in-place?

---