# HomeCraft – Firebase Auth & Data Architecture

This document describes the Firebase Authentication and Firestore data model used by the HomeCraft mobile app, for use by backend or admin-panel developers.

---

## 1. Overview

- **Auth:** Firebase Authentication (Email/Password).
- **Database:** Cloud Firestore.
- **Roles:** Two app roles — **client** and **provider** — stored in Firestore and used for app routing and features.

---

## 2. Firebase Project

- **Project ID:** `homecraft-robolaxy`
- **Console:** [Firebase Console – homecraft-robolaxy](https://console.firebase.google.com/project/homecraft-robolaxy/overview)
- **Auth method:** Email/Password (enable in Authentication → Sign-in method if not already).

---

## 3. Firestore Collections & Schemas

### 3.1 `users` (main profile for all roles)

Every signed-up user (client or provider) has exactly one document.  
**Document ID = Firebase Auth UID** (`request.auth.uid`).

| Field          | Type   | Required | Description                          |
|----------------|--------|----------|--------------------------------------|
| `uid`          | string | Yes      | Same as document ID (Auth UID).      |
| `email`        | string | Yes      | User email (from Firebase Auth).    |
| `displayName`  | string | Yes      | Display name (e.g. from registration). |
| `role`         | string | Yes      | `"client"` or `"provider"`.         |
| `createdAt`    | number | Yes      | Unix timestamp (milliseconds).      |
| `updatedAt`    | number | No       | Unix timestamp (milliseconds).      |
| `phone`        | string | No       | User phone number.                 |
| `city`         | string | No       | User city.                         |

**Example document** (`users/{uid}`):

```json
{
  "uid": "abc123...",
  "email": "user@example.com",
  "displayName": "Jane Doe",
  "role": "provider",
  "createdAt": 1710000000000,
  "updatedAt": 1710000000000,
  "phone": "+33123456789",
  "city": "Paris"
}
```
(Optional: `phone`, `city`.)

- **Created:** On first registration (after `createUserWithEmailAndPassword`), the app writes this document once.
- **Updated:** App can update `displayName`, `updatedAt` (and later more fields) as needed.

---

### 3.2 `providers` (extended profile for providers only)

Used for provider-specific data (e.g. business info, categories, professional setup).  
**Document ID = Firebase Auth UID** (same as `users/{uid}`).

- **Current use:** Reserved; app may add fields later (e.g. `businessName`, `categories`, `serviceAreas`).
- **Rule:** Same as `users`: only the owner (`request.auth.uid == userId`) can read/write.

For admin panel: you can treat `providers/{uid}` as optional; if missing, the user is client-only or provider profile not yet filled.

---

## 4. Security Rules (Firestore)

Current rules (see `firestore.rules` in repo):

- **`users/{userId}`**  
  - Read/write: only if `request.auth != null` and `request.auth.uid == userId`.  
  - So: each user can only read/update their own document.

- **`providers/{userId}`**  
  - Same: only the signed-in user whose `uid == userId` can read/write.

- **All other paths**  
  - Denied by default (`allow read, write: if false`).

**Implication for admin panel:**  
Client-side (web) admin apps using the Firebase JS SDK still run under these rules, so they **cannot** read or write other users’ documents. To build an admin panel that lists/edits all users:

- Use **Firebase Admin SDK** on a backend (Node, Java, etc.) with a **service account**. Admin SDK bypasses Firestore rules and can read/write any collection.
- Or expose a backend API that uses the Admin SDK; the admin UI calls your API instead of Firestore directly.

---

## 5. Auth Flows (Mobile App)

### 5.1 Registration

1. User submits: email, password, display name, role (client/provider), and accepts terms.
2. App calls Firebase Auth: `createUserWithEmailAndPassword(email, password)`.
3. App updates Auth profile: `updateProfile(displayName)`.
4. App writes one document: **`users/{uid}`** with `uid`, `email`, `displayName`, `role`, `createdAt` (and optionally `updatedAt`).
5. Redirect:
   - **Provider** → professional-setup flow.
   - **Client** → home.

### 5.2 Login

1. User submits email and password.
2. App calls: `signInWithEmailAndPassword(email, password)`.
3. On success, app reads **`users/{uid}`** to get `role`.
4. Redirect:
   - **Provider** → provider home.
   - **Client** → client home.

### 5.3 Password reset

- App calls: `sendPasswordResetEmail(email)`.
- User receives email from Firebase and resets password via link (no custom OTP in this flow).

### 5.4 Sign out

- App calls: `signOut()`.
- Router redirects unauthenticated users to login.

---

## 6. Summary for Admin Panel / Backend

| Item              | Detail                                                                 |
|-------------------|-----------------------------------------------------------------------|
| **List all users**| Use Firebase Admin SDK (e.g. `admin.firestore().collection('users')`) on a server; do not rely on client Firestore rules. |
| **User identity** | Document ID in `users` = Firebase Auth UID. Link to Auth via this UID. |
| **Role**          | Stored in `users/{uid}.role`: `"client"` or `"provider"`.             |
| **Timestamps**    | `createdAt` / `updatedAt` in milliseconds (Unix).                     |
| **Auth operations** | Create/disable/delete users, or send password reset, via **Firebase Admin Auth** (e.g. `admin.auth()`), not via client SDK. |

---

## 7. File References (Repo)

- Firestore rules: **`firestore.rules`** (root).
- Firebase config: **`firebase.json`** (root).
- App user model: **`lib/features/auth/domain/models/app_user.dart`** (mirrors `users` document).
- Auth repository: **`lib/features/auth/domain/repositories/auth_repository.dart`** and **`lib/features/auth/data/repositories/auth_repository_impl.dart`**.
- Firestore usage: **`lib/features/auth/data/datasources/auth_remote_datasource.dart`** (collection name `users`, document ID = uid).

---

*Last updated to match the current HomeCraft Flutter app and Firestore rules.*
