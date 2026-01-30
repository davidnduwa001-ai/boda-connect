# 🧪 QUICK TEST GUIDE - Google OAuth Registration

## ⚡ Quick Start (5 Minutes)

### Step 1: Hot Restart App
Press `R` in terminal or `Shift+R` for full restart

### Step 2: Create Supplier Account
1. Open app
2. Tap "Registar" (Sign Up)
3. Select "FORNECEDOR" (Supplier)
4. Tap Google Sign-In
5. Use email: **youremail+supplier@gmail.com**

**Check:**
- ✅ App shows supplier dashboard
- ✅ No errors in console

### Step 3: Create Client Account
1. Sign out
2. Tap "Registar" again
3. Select "CLIENTE" (Client)
4. Tap Google Sign-In
5. Use email: **youremail+client@gmail.com** (DIFFERENT EMAIL!)

**Check:**
- ✅ App shows client dashboard
- ✅ No errors in console

### Step 4: Test Seed Database
1. Login as supplier (youremail+supplier@gmail.com)
2. Go to Profile
3. Scroll down
4. Tap "Popular Base de Dados (Dev)"
5. Wait for success message

**Check:**
- ✅ Success message appears
- ✅ Rating shows 5.0 (not 0.0)
- ✅ Categories populated
- ✅ Multiple suppliers created

### Step 5: Verify Data in Firebase Console

**Users Collection:**
```
users/
  ├── ABC123 (supplier account)
  │   ├── email: youremail+supplier@gmail.com
  │   ├── userType: supplier
  │   └── rating: 5.0
  └── XYZ789 (client account)
      ├── email: youremail+client@gmail.com
      ├── userType: client
      └── rating: 5.0
```

**Suppliers Collection:**
```
suppliers/
  ├── auto-id-1 (linked to ABC123)
  │   ├── userId: ABC123
  │   ├── rating: 5.0
  │   └── completedBookings: 0
  ├── auto-id-2 (from seed)
  ├── auto-id-3 (from seed)
  └── ...
```

---

## 🔬 Advanced Tests

### Test: UserType Conflict Protection
1. Login with youremail+supplier@gmail.com as SUPPLIER ✅
2. Logout
3. Try to register youremail+supplier@gmail.com as CLIENT ❌

**Expected:**
- Error: "Esta conta já está registada como supplier"
- Registration blocked

### Test: Re-Login Existing Account
1. Login with existing account
2. Select same userType as before

**Expected:**
- ✅ Login successful
- ✅ All data loads correctly
- ✅ No duplicate documents created

---

## 🐛 Troubleshooting

### Error: "User not found in Firestore"
**Solution:** Hot restart the app (not just hot reload)

### Error: "Rating shows 0.0"
**Solution:**
1. Check you're running latest code
2. Delete test suppliers
3. Re-seed database

### Error: "Cannot seed database"
**Solution:**
1. Ensure you have BOTH supplier and client accounts
2. Check Firebase Console that both exist
3. Try again

### Error: "Permission denied"
**Solution:**
1. Check Firestore rules are deployed
2. Run: `firebase deploy --only firestore:rules`

---

## ✅ Success Criteria

You know everything works when:

- [x] Supplier registration creates user + supplier profile
- [x] Client registration creates user only
- [x] Rating always shows 5.0
- [x] Cannot use same email for different userType
- [x] Seed database works without errors
- [x] All data appears in Firebase Console

---

## 💡 Pro Tips

### Use Gmail + Trick
Instead of creating multiple Google accounts:
- youremail+supplier@gmail.com
- youremail+client@gmail.com
- youremail+test1@gmail.com

All go to the same inbox but Firebase treats them as different emails!

### Quick Firebase Console Check
Press `Ctrl+F` and search for your email to find your user documents quickly.

### Debug Logs
Watch the console for:
```
✅ User document created in Firestore: xyz123
✅ Supplier profile created with ID: abc456 for user: xyz123
✅ New user registered with Google: xyz123
```

---

**Estimated Time**: 5-10 minutes for complete test
**Prerequisites**: Flutter app running, Firebase configured
**Result**: Fully functional authentication system
