# Firestore Indexes Deployment

## Status: ✅ Deployed Successfully

All required Firestore indexes have been deployed to project `boda-connect-49eb9`.

---

## Indexes Deployed

### 1. Featured Suppliers Index
**Purpose**: Powers the "Destaques" (Featured) section on client home

**Query**:
```javascript
suppliers
  .where('isActive', isEqualTo: true)
  .where('isFeatured', isEqualTo: true)
  .orderBy('rating', descending: true)
  .limit(10)
```

**Index Fields**:
- `isActive` (Ascending)
- `isFeatured` (Ascending)
- `rating` (Descending)

**Code Location**: [lib/core/services/storage_service.dart:166-176](../lib/core/services/storage_service.dart)

---

### 2. Active Suppliers Index
**Purpose**: Powers "Perto de si" (Nearby) and general supplier browsing

**Query**:
```javascript
suppliers
  .where('isActive', isEqualTo: true)
  .orderBy('rating', descending: true)
  .limit(20)
```

**Index Fields**:
- `isActive` (Ascending)
- `rating` (Descending)

**Code Location**: [lib/core/services/storage_service.dart:129-163](../lib/core/services/storage_service.dart)

---

### 3. Category Suppliers Index
**Purpose**: Filter suppliers by category with rating sort

**Query**:
```javascript
suppliers
  .where('isActive', isEqualTo: true)
  .where('category', isEqualTo: selectedCategory)
  .orderBy('rating', descending: true)
```

**Index Fields**:
- `isActive` (Ascending)
- `category` (Ascending)
- `rating` (Descending)

**Usage**: Category browse screen, search filters

---

### 4. Client Bookings Index
**Purpose**: Load client's bookings sorted by date

**Query**:
```javascript
bookings
  .where('clientId', isEqualTo: userId)
  .orderBy('createdAt', descending: true)
```

**Index Fields**:
- `clientId` (Ascending)
- `createdAt` (Descending)

**Code Location**: Booking provider queries

---

### 5. Supplier Bookings Index
**Purpose**: Load supplier's received bookings

**Query**:
```javascript
bookings
  .where('supplierId', isEqualTo: supplierId)
  .orderBy('createdAt', descending: true)
```

**Index Fields**:
- `supplierId` (Ascending)
- `createdAt` (Descending)

**Code Location**: Supplier orders screen

---

### 6. Supplier Bookings by Status Index
**Purpose**: Filter supplier bookings by status

**Query**:
```javascript
bookings
  .where('supplierId', isEqualTo: supplierId)
  .where('status', isEqualTo: 'pending')
  .orderBy('createdAt', descending: true)
```

**Index Fields**:
- `supplierId` (Ascending)
- `status` (Ascending)
- `createdAt` (Descending)

**Usage**: Supplier dashboard, order filtering

---

### 7. Chat Messages Index
**Purpose**: Load user's chats sorted by last message

**Query**:
```javascript
chats
  .where('participantIds', arrayContains: userId)
  .orderBy('lastMessageTime', descending: true)
```

**Index Fields**:
- `participantIds` (Array Contains)
- `lastMessageTime` (Descending)

**Code Location**: Chat list screen

---

### 8. Supplier Reviews Index
**Purpose**: Load reviews for a supplier

**Query**:
```javascript
reviews
  .where('supplierId', isEqualTo: supplierId)
  .orderBy('createdAt', descending: true)
```

**Index Fields**:
- `supplierId` (Ascending)
- `createdAt` (Descending)

**Usage**: Supplier detail screen, reviews section

---

## Deployment Command

```bash
firebase deploy --only firestore:indexes
```

## Deployment Output

```
✅ Deployed indexes in firestore.indexes.json successfully for (default) database
Project: boda-connect-49eb9
Database: (default)
Location: africa-south1
```

---

## Verification

### Check Indexes in Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com/project/boda-connect-49eb9/firestore/indexes)
2. Navigate to Firestore Database → Indexes
3. Verify all 8 indexes are in "Enabled" state

### Test Queries:
Run the app and verify:
- ✅ Destaques section loads suppliers
- ✅ Perto de si section loads suppliers
- ✅ Category filtering works
- ✅ Bookings load correctly
- ✅ Chat list displays
- ✅ Reviews appear on supplier profiles

---

## Index Building Time

- Single-field indexes: Near instant
- Composite indexes: 1-5 minutes (depending on data volume)
- Current project: Minimal data, all indexes should be ready immediately

**Note**: The deployment message mentioned 4 existing indexes not in the file. These can be safely ignored or removed with `--force` flag if needed.

---

## Adding More Indexes

If you need to add more indexes in the future:

1. Edit [firestore.indexes.json](../firestore.indexes.json)
2. Add new index definition:
```json
{
  "collectionGroup": "collection_name",
  "queryScope": "COLLECTION",
  "fields": [
    {
      "fieldPath": "field1",
      "order": "ASCENDING"
    },
    {
      "fieldPath": "field2",
      "order": "DESCENDING"
    }
  ]
}
```
3. Deploy: `firebase deploy --only firestore:indexes`

---

## Common Issues

### Issue: Index already exists
**Solution**: Firebase auto-creates indexes from errors. This is fine, your deployment adds missing ones.

### Issue: Query still fails
**Cause**: Index may still be building
**Solution**: Wait 1-5 minutes, then retry

### Issue: Too many indexes warning
**Solution**: Review and remove unused indexes with:
```bash
firebase deploy --only firestore:indexes --force
```

---

## Related Files

- **Indexes Definition**: [firestore.indexes.json](../firestore.indexes.json)
- **Firestore Rules**: [firestore.rules](../firestore.rules)
- **Storage Service**: [lib/core/services/storage_service.dart](../lib/core/services/storage_service.dart)
- **Supplier Queries**: [lib/core/repositories/supplier_repository.dart](../lib/core/repositories/supplier_repository.dart)

---

**Last Updated**: 2026-01-21
**Status**: ✅ All indexes deployed and active
**Project**: boda-connect-49eb9
**Database Location**: africa-south1
