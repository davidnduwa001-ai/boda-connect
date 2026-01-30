# BODA CONNECT - Comprehensive Testing Checklist

**Version:** 1.0.0
**Last Updated:** January 2026
**Purpose:** Manual QA Testing Guide for All User Roles

---

## Table of Contents

1. [Testing Overview](#testing-overview)
2. [Pre-Testing Setup](#pre-testing-setup)
3. [Authentication Testing](#1-authentication-testing)
4. [Client Role Testing](#2-client-role-testing)
5. [Supplier Role Testing](#3-supplier-role-testing)
6. [Admin Role Testing](#4-admin-role-testing)
7. [Cross-Role Features Testing](#5-cross-role-features-testing)
8. [Security Testing](#6-security-testing)
9. [Performance Testing](#7-performance-testing)
10. [Edge Cases & Error Handling](#8-edge-cases--error-handling)

---

## Testing Overview

### Test Accounts Needed

| Role | Phone Number | Purpose |
|------|--------------|---------|
| **Client 1** | +244 923 XXX XXX | Primary client testing |
| **Client 2** | +244 923 XXX XXX | Secondary client (for messaging tests) |
| **Supplier 1** | +244 923 XXX XXX | Primary supplier testing |
| **Supplier 2** | +244 923 XXX XXX | Secondary supplier (for comparison tests) |
| **Admin** | admin@bodaconnect.ao | Admin panel testing |

### Test Data Requirements

- [ ] At least 2 supplier accounts with completed profiles
- [ ] At least 2 client accounts
- [ ] Multiple service packages created
- [ ] Test payment methods configured
- [ ] Sample reviews and ratings

---

## Pre-Testing Setup

### Environment Checklist

- [ ] App installed on test device
- [ ] Internet connection stable
- [ ] Firebase project configured
- [ ] Test phone numbers whitelisted (if using Firebase test numbers)
- [ ] Admin account created in Firebase Console
- [ ] ProxyPay test environment configured (if testing payments)

### Device Requirements

- [ ] Android 11+ or iOS 14+ device
- [ ] Camera permissions available
- [ ] Location permissions available
- [ ] Notification permissions available
- [ ] Adequate storage space (500MB+)

---

## 1. Authentication Testing

### 1.1 New User Registration

#### Phone Number Registration
| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1.1.1 | Valid phone registration | 1. Open app → Welcome → "Get Started" 2. Select "Client" or "Supplier" 3. Enter valid Angolan phone (+244 9XX XXX XXX) 4. Tap "Send Code" | OTP sent, redirected to verification screen | [ ] Pass [ ] Fail |
| 1.1.2 | Invalid phone format | Enter phone without country code or wrong format | Error: "Número de telefone inválido" | [ ] Pass [ ] Fail |
| 1.1.3 | OTP verification - correct code | Enter correct 6-digit OTP | Verification successful, proceed to profile setup | [ ] Pass [ ] Fail |
| 1.1.4 | OTP verification - wrong code | Enter incorrect OTP 3 times | Error message, option to resend | [ ] Pass [ ] Fail |
| 1.1.5 | OTP resend | Tap "Resend Code" after 60 seconds | New OTP sent successfully | [ ] Pass [ ] Fail |
| 1.1.6 | OTP expiry | Wait 5+ minutes without entering code | Code expired message, prompt to resend | [ ] Pass [ ] Fail |

#### Email Registration
| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1.1.7 | Valid email registration | Enter valid email + strong password | Account created, verification email sent | [ ] Pass [ ] Fail |
| 1.1.8 | Weak password | Enter password less than 8 chars | Password strength indicator shows "Weak" | [ ] Pass [ ] Fail |
| 1.1.9 | Invalid email format | Enter "test@" or "test.com" | Error: Invalid email format | [ ] Pass [ ] Fail |
| 1.1.10 | Duplicate email | Use already registered email | Error: Email already in use | [ ] Pass [ ] Fail |

#### Google Sign-In
| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1.1.11 | Google sign-in success | Tap Google button → Select account | Signed in, redirected based on account status | [ ] Pass [ ] Fail |
| 1.1.12 | Google sign-in cancel | Tap Google → Cancel on Google picker | Returns to login screen gracefully | [ ] Pass [ ] Fail |

### 1.2 Existing User Login

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1.2.1 | Phone login existing user | Enter registered phone → OTP → Verify | Logged in, redirected to home | [ ] Pass [ ] Fail |
| 1.2.2 | Email login correct credentials | Enter email + correct password | Logged in successfully | [ ] Pass [ ] Fail |
| 1.2.3 | Email login wrong password | Enter email + wrong password 5 times | Account locked for 15 minutes | [ ] Pass [ ] Fail |
| 1.2.4 | Remember me functionality | Login with "Remember me" checked | Next app open auto-logs in | [ ] Pass [ ] Fail |

### 1.3 Session Management

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 1.3.1 | Session persistence | Login → Close app → Reopen after 10 min | Still logged in | [ ] Pass [ ] Fail |
| 1.3.2 | Session timeout | Leave app idle for 30+ minutes | Session expired, re-authentication required | [ ] Pass [ ] Fail |
| 1.3.3 | Logout | Go to Settings → Logout | Logged out, redirected to welcome screen | [ ] Pass [ ] Fail |
| 1.3.4 | Multi-device limit | Login on 4th device (max 3 allowed) | Oldest session terminated, warning shown | [ ] Pass [ ] Fail |

---

## 2. Client Role Testing

### 2.1 Client Onboarding

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 2.1.1 | Complete profile setup | After registration: Enter name, upload photo, set location | Profile saved, redirected to home | [ ] Pass [ ] Fail |
| 2.1.2 | Skip optional fields | Skip profile photo, complete with name only | Proceeds with default avatar | [ ] Pass [ ] Fail |
| 2.1.3 | Set preferences | Select wedding preferences (date range, budget) | Preferences saved for recommendations | [ ] Pass [ ] Fail |

### 2.2 Home Screen & Discovery

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 2.2.1 | Home screen loads | Open app as logged-in client | Home screen displays: search bar, categories, featured suppliers | [ ] Pass [ ] Fail |
| 2.2.2 | Location permission request | First time: Location permission prompt | Prompt appears with explanation | [ ] Pass [ ] Fail |
| 2.2.3 | Nearby suppliers | Grant location → View "Nearby" section | Shows suppliers within radius, sorted by distance | [ ] Pass [ ] Fail |
| 2.2.4 | Featured suppliers | View "Featured" section | Shows Diamond/Premium tier suppliers | [ ] Pass [ ] Fail |
| 2.2.5 | Category navigation | Tap any category (e.g., "Decoração") | Shows suppliers in that category | [ ] Pass [ ] Fail |
| 2.2.6 | Warning banner (if violations) | Client with violations opens home | Yellow/red warning banner visible with link | [ ] Pass [ ] Fail |

### 2.3 Search & Filtering

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 2.3.1 | Basic text search | Type "fotógrafo casamento" → Search | Relevant results shown | [ ] Pass [ ] Fail |
| 2.3.2 | Filter by category | Search → Filter icon → Select "Fotografia" | Results filtered to photography only | [ ] Pass [ ] Fail |
| 2.3.3 | Filter by price range | Set min: 50000 AOA, max: 200000 AOA | Only packages in range shown | [ ] Pass [ ] Fail |
| 2.3.4 | Filter by minimum rating | Set minimum: 4 stars | Only 4+ star suppliers shown | [ ] Pass [ ] Fail |
| 2.3.5 | Sort by price (low to high) | Tap Sort → Price: Low to High | Results sorted ascending by price | [ ] Pass [ ] Fail |
| 2.3.6 | Sort by rating | Tap Sort → Rating: High to Low | Results sorted by rating descending | [ ] Pass [ ] Fail |
| 2.3.7 | Combined filters | Category + Price + Rating + Sort | All filters applied correctly | [ ] Pass [ ] Fail |
| 2.3.8 | Clear filters | Apply filters → Tap "Clear All" | All filters reset, full results shown | [ ] Pass [ ] Fail |
| 2.3.9 | No results | Search "xyznonexistent123" | "No results found" message with suggestions | [ ] Pass [ ] Fail |
| 2.3.10 | Recent searches | Perform search → Return to search | Recent searches displayed | [ ] Pass [ ] Fail |
| 2.3.11 | Popular searches | Open search screen | Popular/trending searches shown | [ ] Pass [ ] Fail |

### 2.4 Supplier Profile Viewing

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 2.4.1 | View supplier profile | Tap supplier from search/home | Full profile loads: photos, description, rating, packages | [ ] Pass [ ] Fail |
| 2.4.2 | Photo gallery | Tap on photo thumbnail | Full-screen gallery opens, swipeable | [ ] Pass [ ] Fail |
| 2.4.3 | Video playback | Tap video in gallery | Video plays in viewer | [ ] Pass [ ] Fail |
| 2.4.4 | View reviews | Scroll to "Reviews" section | Reviews displayed with ratings, photos, tags | [ ] Pass [ ] Fail |
| 2.4.5 | Filter reviews by stars | Tap "5 stars" filter | Only 5-star reviews shown | [ ] Pass [ ] Fail |
| 2.4.6 | View all packages | Scroll to packages section | All available packages listed with prices | [ ] Pass [ ] Fail |
| 2.4.7 | Supplier tier badge | View Diamond/Gold supplier | Tier badge displayed prominently | [ ] Pass [ ] Fail |
| 2.4.8 | Response time display | View supplier stats | Average response time shown | [ ] Pass [ ] Fail |

### 2.5 Favorites Management

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 2.5.1 | Add to favorites | On supplier profile → Tap heart icon | Heart fills, supplier added to favorites | [ ] Pass [ ] Fail |
| 2.5.2 | Remove from favorites | Tap filled heart | Heart empties, removed from favorites | [ ] Pass [ ] Fail |
| 2.5.3 | View favorites list | Navigate to Favorites tab | All favorited suppliers shown | [ ] Pass [ ] Fail |
| 2.5.4 | Navigate from favorites | Tap supplier in favorites | Opens supplier profile | [ ] Pass [ ] Fail |
| 2.5.5 | Empty favorites state | View favorites with none saved | "No favorites yet" message with CTA | [ ] Pass [ ] Fail |

### 2.6 Cart & Checkout

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 2.6.1 | Add package to cart | On package detail → "Add to Cart" | Package added, cart badge updates | [ ] Pass [ ] Fail |
| 2.6.2 | View cart | Tap cart icon | Cart screen shows all items with totals | [ ] Pass [ ] Fail |
| 2.6.3 | Remove item from cart | Swipe left or tap remove on item | Item removed, total updated | [ ] Pass [ ] Fail |
| 2.6.4 | Empty cart state | Remove all items | "Your cart is empty" message | [ ] Pass [ ] Fail |
| 2.6.5 | Proceed to checkout | Tap "Checkout" with items in cart | Checkout screen loads with order summary | [ ] Pass [ ] Fail |
| 2.6.6 | Select event date | Choose date on calendar | Date selected, availability confirmed | [ ] Pass [ ] Fail |
| 2.6.7 | Date unavailable | Try to select blocked date | Date not selectable, message shown | [ ] Pass [ ] Fail |

### 2.7 Payment Flow

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 2.7.1 | View payment methods | Checkout → Payment step | Saved methods shown + "Add new" | [ ] Pass [ ] Fail |
| 2.7.2 | Add new payment method | Tap "Add Payment Method" | Form appears for bank/mobile money | [ ] Pass [ ] Fail |
| 2.7.3 | Select payment method | Tap saved method | Method selected with checkmark | [ ] Pass [ ] Fail |
| 2.7.4 | High-value SMS verification | Amount > 100,000 AOA → Confirm | SMS OTP required for verification | [ ] Pass [ ] Fail |
| 2.7.5 | Critical SMS verification | Amount > 500,000 AOA → Confirm | Mandatory SMS verification step | [ ] Pass [ ] Fail |
| 2.7.6 | Payment success | Complete payment | Success screen, booking created | [ ] Pass [ ] Fail |
| 2.7.7 | Payment failure | Simulate failed payment | Error screen with retry option | [ ] Pass [ ] Fail |
| 2.7.8 | View receipt | After success → "View Receipt" | Receipt displayed with details | [ ] Pass [ ] Fail |

### 2.8 Booking Management

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 2.8.1 | View active bookings | Navigate to Bookings tab | Active bookings listed with status | [ ] Pass [ ] Fail |
| 2.8.2 | Booking detail view | Tap on a booking | Full details: supplier, package, date, status | [ ] Pass [ ] Fail |
| 2.8.3 | Pending status display | View newly created booking | Status shows "Pending" (yellow) | [ ] Pass [ ] Fail |
| 2.8.4 | Confirmed status update | After supplier confirms | Status changes to "Confirmed" (green) | [ ] Pass [ ] Fail |
| 2.8.5 | Contact supplier | Tap "Message Supplier" on booking | Opens chat with supplier | [ ] Pass [ ] Fail |
| 2.8.6 | Cancel booking | Tap "Cancel" on pending booking | Confirmation prompt → Cancelled | [ ] Pass [ ] Fail |
| 2.8.7 | View booking history | Go to History tab | Past bookings shown | [ ] Pass [ ] Fail |
| 2.8.8 | Filter history by status | Filter → "Completed" | Only completed bookings shown | [ ] Pass [ ] Fail |

### 2.9 Reviews & Ratings

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 2.9.1 | Leave review prompt | Completed booking → "Leave Review" | Review form opens | [ ] Pass [ ] Fail |
| 2.9.2 | Star rating selection | Tap 4 stars | 4 stars highlighted | [ ] Pass [ ] Fail |
| 2.9.3 | Write review text | Enter 50+ characters | Text accepted | [ ] Pass [ ] Fail |
| 2.9.4 | Add photo to review | Tap "Add Photo" → Select | Photo uploaded and shown | [ ] Pass [ ] Fail |
| 2.9.5 | Add multiple photos | Add 5 photos (max) | All 5 displayed | [ ] Pass [ ] Fail |
| 2.9.6 | Exceed photo limit | Try to add 6th photo | "Maximum 5 photos" message | [ ] Pass [ ] Fail |
| 2.9.7 | Select review tags | Select "Professional", "Quality" | Tags highlighted and selected | [ ] Pass [ ] Fail |
| 2.9.8 | Submit review | Tap "Submit Review" | Success message, review visible on supplier profile | [ ] Pass [ ] Fail |
| 2.9.9 | Review without text | Submit with stars only (no text) | Review accepted (text optional) | [ ] Pass [ ] Fail |

### 2.10 Client Profile Management

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 2.10.1 | View own profile | Navigate to Profile tab | Profile displayed with stats | [ ] Pass [ ] Fail |
| 2.10.2 | Edit profile | Tap "Edit" → Change name | Name updated successfully | [ ] Pass [ ] Fail |
| 2.10.3 | Change profile photo | Tap photo → Take/Choose new | Photo updated | [ ] Pass [ ] Fail |
| 2.10.4 | Update location | Edit → Change location | Location updated in profile | [ ] Pass [ ] Fail |
| 2.10.5 | View safety history | Profile → "Safety History" | Violations and warning level shown | [ ] Pass [ ] Fail |

---

## 3. Supplier Role Testing

### 3.1 Supplier Onboarding & Registration

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 3.1.1 | Select supplier role | Welcome → "Get Started" → "Supplier" | Supplier registration flow begins | [ ] Pass [ ] Fail |
| 3.1.2 | Enter business basics | Name, phone, email, location | Data saved, proceeds to next step | [ ] Pass [ ] Fail |
| 3.1.3 | Select service category | Choose primary category (e.g., "Decoração") | Category selected, subcategories shown | [ ] Pass [ ] Fail |
| 3.1.4 | Select subcategories | Choose 1-5 subcategories | Subcategories saved | [ ] Pass [ ] Fail |
| 3.1.5 | Write business description | Enter 100+ character description | Description saved | [ ] Pass [ ] Fail |
| 3.1.6 | Upload photos (min 3) | Upload 3 business photos | Photos uploaded with progress | [ ] Pass [ ] Fail |
| 3.1.7 | Upload video (optional) | Upload 1 video | Video processed, thumbnail generated | [ ] Pass [ ] Fail |
| 3.1.8 | Set working hours | Define hours for each day | Working hours saved | [ ] Pass [ ] Fail |
| 3.1.9 | Complete registration | Finish all steps | Success screen, verification pending message | [ ] Pass [ ] Fail |

### 3.2 Document Verification

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 3.2.1 | View verification status | After registration → Check status | "Pending Verification" displayed | [ ] Pass [ ] Fail |
| 3.2.2 | Upload ID document | Verification → "Upload ID" → Select photo | ID uploaded successfully | [ ] Pass [ ] Fail |
| 3.2.3 | Upload business license | Verification → "Business License" → Select | Document uploaded | [ ] Pass [ ] Fail |
| 3.2.4 | Invalid file type | Try to upload .exe file | "Invalid file type" error | [ ] Pass [ ] Fail |
| 3.2.5 | File too large | Upload >5MB file | "File too large" error (max 5MB) | [ ] Pass [ ] Fail |
| 3.2.6 | Track document status | View uploaded documents | Status shown: Pending/Approved/Rejected | [ ] Pass [ ] Fail |
| 3.2.7 | Resubmit rejected doc | Document rejected → Upload new | New document uploaded for review | [ ] Pass [ ] Fail |
| 3.2.8 | Verification approved | Admin approves | Status changes to "Verified", full access granted | [ ] Pass [ ] Fail |

### 3.3 Supplier Dashboard

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 3.3.1 | Dashboard loads | Login as verified supplier | Dashboard shows: revenue, bookings, rating, completeness | [ ] Pass [ ] Fail |
| 3.3.2 | Revenue display | View revenue card | Total revenue shown with period selector | [ ] Pass [ ] Fail |
| 3.3.3 | Booking count | View bookings card | Total and pending bookings count | [ ] Pass [ ] Fail |
| 3.3.4 | Rating display | View rating card | Average rating with star visualization | [ ] Pass [ ] Fail |
| 3.3.5 | Profile completeness | View completeness card | Percentage shown with missing items | [ ] Pass [ ] Fail |
| 3.3.6 | Recent bookings list | Scroll to recent bookings | Latest 5 bookings shown | [ ] Pass [ ] Fail |
| 3.3.7 | Quick actions | View action buttons | "Add Package", "View Orders", "Edit Profile" available | [ ] Pass [ ] Fail |
| 3.3.8 | Chat notification badge | Receive message → View dashboard | Badge shows unread count | [ ] Pass [ ] Fail |

### 3.4 Package Management

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 3.4.1 | View packages list | Dashboard → "My Packages" | All packages listed | [ ] Pass [ ] Fail |
| 3.4.2 | Create new package | Tap "+" → Fill form | Package created successfully | [ ] Pass [ ] Fail |
| 3.4.3 | Package name validation | Leave name empty → Submit | "Name required" error | [ ] Pass [ ] Fail |
| 3.4.4 | Package price validation | Enter 0 or negative price | "Invalid price" error | [ ] Pass [ ] Fail |
| 3.4.5 | Add included services | Add 3 items to inclusions list | Items saved and displayed | [ ] Pass [ ] Fail |
| 3.4.6 | Add package photos | Upload 2 photos for package | Photos saved to package | [ ] Pass [ ] Fail |
| 3.4.7 | Set as featured | Toggle "Featured" switch | Package marked as featured | [ ] Pass [ ] Fail |
| 3.4.8 | Edit existing package | Tap package → Edit → Change price | Price updated | [ ] Pass [ ] Fail |
| 3.4.9 | Deactivate package | Toggle active switch off | Package hidden from clients | [ ] Pass [ ] Fail |
| 3.4.10 | Delete package | Long press → Delete → Confirm | Package removed | [ ] Pass [ ] Fail |
| 3.4.11 | Enable customization | Toggle "Allow customization" | Customization form appears | [ ] Pass [ ] Fail |

### 3.5 Availability Management

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 3.5.1 | View calendar | Dashboard → "Availability" | Calendar view with booked dates | [ ] Pass [ ] Fail |
| 3.5.2 | Block date | Tap date → "Mark Unavailable" | Date blocked, shown in red | [ ] Pass [ ] Fail |
| 3.5.3 | Unblock date | Tap blocked date → "Mark Available" | Date unblocked | [ ] Pass [ ] Fail |
| 3.5.4 | Set vacation period | Select date range → "Set Vacation" | Range blocked | [ ] Pass [ ] Fail |
| 3.5.5 | View booked dates | Check calendar | Booked dates shown differently | [ ] Pass [ ] Fail |
| 3.5.6 | Update working hours | Settings → Working Hours → Edit Monday | Hours updated | [ ] Pass [ ] Fail |
| 3.5.7 | Set day as closed | Toggle day to "Closed" | Day not available for bookings | [ ] Pass [ ] Fail |

### 3.6 Order Management

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 3.6.1 | View all orders | Dashboard → "Orders" | Orders listed with filters | [ ] Pass [ ] Fail |
| 3.6.2 | Filter by status | Tap "Pending" filter | Only pending orders shown | [ ] Pass [ ] Fail |
| 3.6.3 | View order detail | Tap order → View details | Full order info: client, package, date, amount | [ ] Pass [ ] Fail |
| 3.6.4 | Accept/Confirm order | Pending order → "Confirm" | Status changes to Confirmed, client notified | [ ] Pass [ ] Fail |
| 3.6.5 | Decline order | Pending order → "Decline" → Reason | Order declined, client notified with reason | [ ] Pass [ ] Fail |
| 3.6.6 | Start service | Confirmed order → "Start Service" | Status changes to "In Progress" | [ ] Pass [ ] Fail |
| 3.6.7 | Complete service | In Progress → "Mark Complete" | Status changes to "Completed" | [ ] Pass [ ] Fail |
| 3.6.8 | Contact client | Order → "Message Client" | Opens chat with client | [ ] Pass [ ] Fail |
| 3.6.9 | Search orders | Type client name in search | Matching orders shown | [ ] Pass [ ] Fail |

### 3.7 Revenue & Payments

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 3.7.1 | View revenue screen | Dashboard → "Revenue" | Revenue breakdown shown | [ ] Pass [ ] Fail |
| 3.7.2 | Filter by period | Select "This Month" | Monthly revenue displayed | [ ] Pass [ ] Fail |
| 3.7.3 | View pending payments | Check "Pending" section | Unpaid bookings listed | [ ] Pass [ ] Fail |
| 3.7.4 | View completed payments | Check "Completed" section | Paid transactions shown | [ ] Pass [ ] Fail |
| 3.7.5 | Platform fee breakdown | View fee details | 10% platform fee shown separately | [ ] Pass [ ] Fail |
| 3.7.6 | Add payment method | Payments → "Add Method" | Bank/mobile money form | [ ] Pass [ ] Fail |
| 3.7.7 | Set default payment method | Long press method → "Set Default" | Method marked as default | [ ] Pass [ ] Fail |
| 3.7.8 | Delete payment method | Swipe → Delete | Method removed | [ ] Pass [ ] Fail |

### 3.8 Reviews Management

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 3.8.1 | View all reviews | Dashboard → "Reviews" | All received reviews listed | [ ] Pass [ ] Fail |
| 3.8.2 | Filter by rating | Tap "4 Stars" | Only 4-star reviews shown | [ ] Pass [ ] Fail |
| 3.8.3 | View review detail | Tap review | Full review with photos, tags | [ ] Pass [ ] Fail |
| 3.8.4 | Average rating calculation | Check displayed average | Matches calculated average | [ ] Pass [ ] Fail |
| 3.8.5 | Review count | Check total count | Matches actual reviews | [ ] Pass [ ] Fail |

### 3.9 Supplier Profile Management

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 3.9.1 | View own profile | Navigate to Profile | Full profile displayed | [ ] Pass [ ] Fail |
| 3.9.2 | View as client | Profile → "View as Client" | Public profile preview shown | [ ] Pass [ ] Fail |
| 3.9.3 | Edit business name | Edit → Change name → Save | Name updated | [ ] Pass [ ] Fail |
| 3.9.4 | Update description | Edit → Modify description | Description updated | [ ] Pass [ ] Fail |
| 3.9.5 | Add/edit social links | Edit → Social Links → Add Instagram | Link saved and displayed | [ ] Pass [ ] Fail |
| 3.9.6 | Update photos | Edit → Add new photo | Photo added to gallery | [ ] Pass [ ] Fail |
| 3.9.7 | Delete photo | Long press photo → Delete | Photo removed | [ ] Pass [ ] Fail |
| 3.9.8 | Update location | Edit → Change address | Location updated | [ ] Pass [ ] Fail |
| 3.9.9 | View tier status | Profile → Tier badge | Current tier displayed with benefits | [ ] Pass [ ] Fail |
| 3.9.10 | Check tier requirements | View tier requirements | Progress toward next tier shown | [ ] Pass [ ] Fail |

### 3.10 Custom Offers

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 3.10.1 | Send custom offer | Chat → "Send Offer" | Offer form appears | [ ] Pass [ ] Fail |
| 3.10.2 | Fill offer details | Enter price, description, validity | Details saved | [ ] Pass [ ] Fail |
| 3.10.3 | Submit offer | "Send Offer" button | Offer sent, shown in chat | [ ] Pass [ ] Fail |
| 3.10.4 | Client accepts offer | Wait for client acceptance | Booking auto-created from offer | [ ] Pass [ ] Fail |
| 3.10.5 | Client rejects offer | Wait for client rejection | Offer marked as rejected | [ ] Pass [ ] Fail |
| 3.10.6 | Offer expiry | Wait for validity period to pass | Offer marked as expired | [ ] Pass [ ] Fail |

---

## 4. Admin Role Testing

### 4.1 Admin Authentication

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 4.1.1 | Admin login | Enter admin credentials | Access to admin dashboard | [ ] Pass [ ] Fail |
| 4.1.2 | Non-admin access attempt | Login with regular user credentials | Access denied message | [ ] Pass [ ] Fail |
| 4.1.3 | Admin session timeout | Idle for extended period | Re-authentication required | [ ] Pass [ ] Fail |

### 4.2 Admin Dashboard

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 4.2.1 | Dashboard loads | Login as admin | Dashboard with platform stats | [ ] Pass [ ] Fail |
| 4.2.2 | Total users count | View users stat | Correct count of all users | [ ] Pass [ ] Fail |
| 4.2.3 | Total bookings | View bookings stat | Correct booking count | [ ] Pass [ ] Fail |
| 4.2.4 | Total revenue | View revenue stat | Platform revenue displayed | [ ] Pass [ ] Fail |
| 4.2.5 | Pending verifications alert | New suppliers waiting | Badge/alert shown | [ ] Pass [ ] Fail |
| 4.2.6 | Pending reports alert | Open reports exist | Badge/alert shown | [ ] Pass [ ] Fail |

### 4.3 Supplier Verification

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 4.3.1 | View pending documents | Verification → Pending Docs | List of pending documents | [ ] Pass [ ] Fail |
| 4.3.2 | Preview document | Tap document → Preview | Document viewer opens | [ ] Pass [ ] Fail |
| 4.3.3 | Approve document | Document → "Approve" | Document status updated, supplier notified | [ ] Pass [ ] Fail |
| 4.3.4 | Reject document | Document → "Reject" → Add reason | Document rejected with reason, supplier notified | [ ] Pass [ ] Fail |
| 4.3.5 | Request additional doc | Supplier → "Request Document" | Request sent to supplier | [ ] Pass [ ] Fail |
| 4.3.6 | Approve supplier | All docs approved → "Approve Supplier" | Supplier verified, full access granted | [ ] Pass [ ] Fail |
| 4.3.7 | View verification stats | Verification → Statistics tab | Queue size, approval rate, avg time | [ ] Pass [ ] Fail |

### 4.4 Reports Management

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 4.4.1 | View pending reports | Reports → Pending tab | Pending reports listed by severity | [ ] Pass [ ] Fail |
| 4.4.2 | View report detail | Tap report | Full report: reporter, reported, category, evidence | [ ] Pass [ ] Fail |
| 4.4.3 | Start investigation | Report → "Investigate" | Status changes to Investigating | [ ] Pass [ ] Fail |
| 4.4.4 | Add investigation note | Write internal note → Save | Note added with timestamp | [ ] Pass [ ] Fail |
| 4.4.5 | Resolve report | Investigate → "Resolve" → Select outcome | Report resolved, parties notified | [ ] Pass [ ] Fail |
| 4.4.6 | Dismiss report | Report → "Dismiss" → Reason | Report dismissed with reason | [ ] Pass [ ] Fail |
| 4.4.7 | Escalate report | Report → "Escalate" → Reason | Report escalated to higher authority | [ ] Pass [ ] Fail |
| 4.4.8 | Issue warning | Resolve → "Issue Warning" | Warning added to user, rating impacted | [ ] Pass [ ] Fail |
| 4.4.9 | Suspend user | Resolve → "Suspend Account" | User suspended, notified | [ ] Pass [ ] Fail |

### 4.5 Support Tickets

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 4.5.1 | View open tickets | Support → Open tab | Open tickets listed | [ ] Pass [ ] Fail |
| 4.5.2 | Filter by category | Filter → "Payment Problems" | Matching tickets shown | [ ] Pass [ ] Fail |
| 4.5.3 | Filter by priority | Filter → "Urgent" | High priority tickets shown | [ ] Pass [ ] Fail |
| 4.5.4 | Assign to self | Ticket → "Assign to Me" | Ticket assigned, status updated | [ ] Pass [ ] Fail |
| 4.5.5 | Add internal note | Ticket → Add note (internal) | Note visible to admins only | [ ] Pass [ ] Fail |
| 4.5.6 | Send response to user | Ticket → Add response (public) | User receives response | [ ] Pass [ ] Fail |
| 4.5.7 | Change ticket status | Set to "Awaiting User Response" | Status updated | [ ] Pass [ ] Fail |
| 4.5.8 | Resolve ticket | Mark as Resolved | Ticket closed, user notified | [ ] Pass [ ] Fail |
| 4.5.9 | View ticket history | Ticket → History | Full timeline of actions | [ ] Pass [ ] Fail |

### 4.6 User Management

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 4.6.1 | Search user | Enter phone/email/name | User found and displayed | [ ] Pass [ ] Fail |
| 4.6.2 | View user profile | Tap user | Full profile with history | [ ] Pass [ ] Fail |
| 4.6.3 | View violation history | User → Violations | All violations listed | [ ] Pass [ ] Fail |
| 4.6.4 | Manual suspension | User → "Suspend" → Reason | User suspended immediately | [ ] Pass [ ] Fail |
| 4.6.5 | Reactivate user | Suspended user → "Reactivate" | Account reactivated | [ ] Pass [ ] Fail |
| 4.6.6 | Adjust warning level | User → "Adjust Warning" | Warning level modified | [ ] Pass [ ] Fail |

### 4.7 Platform Settings

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 4.7.1 | View platform fee | Settings → Platform Fee | Current fee displayed (default 10%) | [ ] Pass [ ] Fail |
| 4.7.2 | Update platform fee | Change to 15% → Save | Fee updated for new transactions | [ ] Pass [ ] Fail |
| 4.7.3 | Fee validation | Enter 60% (>50% max) | Error: "Maximum fee is 50%" | [ ] Pass [ ] Fail |

---

## 5. Cross-Role Features Testing

### 5.1 Messaging & Chat

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 5.1.1 | Client initiates chat | Supplier profile → "Message" | Chat created, both parties see it | [ ] Pass [ ] Fail |
| 5.1.2 | Send text message | Type message → Send | Message appears for both users | [ ] Pass [ ] Fail |
| 5.1.3 | Real-time delivery | Send message | Recipient sees instantly | [ ] Pass [ ] Fail |
| 5.1.4 | Online status | User is active | Shows "Online" indicator | [ ] Pass [ ] Fail |
| 5.1.5 | Last seen | User goes offline | Shows "Last seen at X" | [ ] Pass [ ] Fail |
| 5.1.6 | Unread count | Receive messages without reading | Badge shows unread count | [ ] Pass [ ] Fail |
| 5.1.7 | Mark as read | Open conversation | Unread count clears | [ ] Pass [ ] Fail |
| 5.1.8 | Delete message | Long press → Delete | Message removed for both | [ ] Pass [ ] Fail |
| 5.1.9 | Search conversations | Type in search box | Matching conversations shown | [ ] Pass [ ] Fail |
| 5.1.10 | Empty conversations | No chats yet | "No conversations" message | [ ] Pass [ ] Fail |

### 5.2 Push Notifications

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 5.2.1 | Request permission | First notification trigger | Permission dialog appears | [ ] Pass [ ] Fail |
| 5.2.2 | Booking notification | Create booking | Supplier receives "New booking" notification | [ ] Pass [ ] Fail |
| 5.2.3 | Message notification | Send chat message | Recipient receives notification | [ ] Pass [ ] Fail |
| 5.2.4 | Payment notification | Complete payment | Both parties notified | [ ] Pass [ ] Fail |
| 5.2.5 | Notification tap navigation | Tap booking notification | Opens booking detail | [ ] Pass [ ] Fail |
| 5.2.6 | Background notification | App in background | Notification received | [ ] Pass [ ] Fail |
| 5.2.7 | Foreground notification | App in foreground | In-app notification shown | [ ] Pass [ ] Fail |
| 5.2.8 | Disable notifications | Settings → Disable | No more notifications | [ ] Pass [ ] Fail |

### 5.3 Settings & Preferences

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 5.3.1 | Change theme | Settings → Dark mode | App switches to dark theme | [ ] Pass [ ] Fail |
| 5.3.2 | Change font size | Settings → Large font | Text size increases | [ ] Pass [ ] Fail |
| 5.3.3 | Change language | Settings → English | App language changes | [ ] Pass [ ] Fail |
| 5.3.4 | Settings persistence | Change settings → Restart app | Settings preserved | [ ] Pass [ ] Fail |

### 5.4 Help & Support

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 5.4.1 | View help center | Settings → Help | Help center with FAQs | [ ] Pass [ ] Fail |
| 5.4.2 | Search help | Type question | Relevant articles shown | [ ] Pass [ ] Fail |
| 5.4.3 | Submit support ticket | Help → Contact Support | Ticket form opens | [ ] Pass [ ] Fail |
| 5.4.4 | Submit report | Profile → Report User | Report form opens | [ ] Pass [ ] Fail |

---

## 6. Security Testing

### 6.1 Authentication Security

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 6.1.1 | Brute force protection | 5 wrong passwords in 5 min | Account locked for 15 minutes | [ ] Pass [ ] Fail |
| 6.1.2 | OTP rate limiting | Request OTP 4 times in 1 min | "Too many attempts" after 3rd | [ ] Pass [ ] Fail |
| 6.1.3 | Session invalidation on password change | Change password | All other sessions terminated | [ ] Pass [ ] Fail |
| 6.1.4 | Concurrent session limit | Login on 4 devices | Oldest session logged out | [ ] Pass [ ] Fail |

### 6.2 Transaction Security

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 6.2.1 | High-value SMS verification | Transaction >100k AOA | SMS OTP required | [ ] Pass [ ] Fail |
| 6.2.2 | Critical transaction verification | Transaction >500k AOA | Mandatory SMS step | [ ] Pass [ ] Fail |
| 6.2.3 | Data export requires verification | Request data export | SMS OTP required | [ ] Pass [ ] Fail |
| 6.2.4 | Account deletion requires verification | Delete account | SMS OTP required | [ ] Pass [ ] Fail |

### 6.3 Data Protection

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 6.3.1 | Sensitive data masking | View payment method | Card: **** **** **** 1234 | [ ] Pass [ ] Fail |
| 6.3.2 | Phone masking | View masked phone | +244 923 *** *** | [ ] Pass [ ] Fail |
| 6.3.3 | HTTPS only | Intercept network traffic | All traffic encrypted | [ ] Pass [ ] Fail |

### 6.4 Device Security

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 6.4.1 | New device login notification | Login from new device | Notification sent to existing sessions | [ ] Pass [ ] Fail |
| 6.4.2 | Device fingerprint | Login → Check device tracking | Device registered in system | [ ] Pass [ ] Fail |
| 6.4.3 | Trusted device management | Settings → Devices | Can view and remove devices | [ ] Pass [ ] Fail |

### 6.5 Account Safety

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 6.5.1 | Warning at 3.5 rating | Rating drops below 3.5 | Warning displayed to user | [ ] Pass [ ] Fail |
| 6.5.2 | Suspension at 2.5 rating | Rating drops below 2.5 | Account suspended automatically | [ ] Pass [ ] Fail |
| 6.5.3 | Violation impact | Receive violation | Rating impact shown (-0.2 to -0.5) | [ ] Pass [ ] Fail |
| 6.5.4 | Appeal process | Suspended → Submit appeal | Appeal submitted, status tracked | [ ] Pass [ ] Fail |

---

## 7. Performance Testing

### 7.1 Load Times

| # | Test Case | Expected Time | Actual Time | Status |
|---|-----------|---------------|-------------|--------|
| 7.1.1 | App cold start | < 3 seconds | | [ ] Pass [ ] Fail |
| 7.1.2 | Home screen load | < 2 seconds | | [ ] Pass [ ] Fail |
| 7.1.3 | Search results | < 1.5 seconds | | [ ] Pass [ ] Fail |
| 7.1.4 | Supplier profile load | < 2 seconds | | [ ] Pass [ ] Fail |
| 7.1.5 | Image gallery load | < 1 second per image | | [ ] Pass [ ] Fail |
| 7.1.6 | Chat message sync | < 500ms | | [ ] Pass [ ] Fail |

### 7.2 Offline Behavior

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 7.2.1 | Offline indicator | Turn off internet | "No connection" indicator shown | [ ] Pass [ ] Fail |
| 7.2.2 | Cached data display | Go offline | Previously loaded data visible | [ ] Pass [ ] Fail |
| 7.2.3 | Action queue | Try to send message offline | Message queued, sent when online | [ ] Pass [ ] Fail |
| 7.2.4 | Graceful degradation | Perform actions offline | Appropriate error messages shown | [ ] Pass [ ] Fail |

---

## 8. Edge Cases & Error Handling

### 8.1 Input Validation

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 8.1.1 | Empty required field | Leave name empty → Submit | "Field required" error | [ ] Pass [ ] Fail |
| 8.1.2 | Special characters | Enter "<script>" in text field | Input sanitized or rejected | [ ] Pass [ ] Fail |
| 8.1.3 | Very long input | Enter 10000 character description | Truncated or character limit enforced | [ ] Pass [ ] Fail |
| 8.1.4 | Negative numbers | Enter -100 for price | "Invalid value" error | [ ] Pass [ ] Fail |
| 8.1.5 | Invalid date | Select past date for booking | Date not selectable | [ ] Pass [ ] Fail |

### 8.2 Network Errors

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 8.2.1 | Network timeout | Slow connection during action | Timeout message with retry | [ ] Pass [ ] Fail |
| 8.2.2 | Server error (500) | Server returns error | "Something went wrong" message | [ ] Pass [ ] Fail |
| 8.2.3 | Connection lost mid-action | Disconnect during upload | Error message, retry option | [ ] Pass [ ] Fail |

### 8.3 Edge Cases

| # | Test Case | Steps | Expected Result | Status |
|---|-----------|-------|-----------------|--------|
| 8.3.1 | First-time user | New account, no data | Proper empty states shown | [ ] Pass [ ] Fail |
| 8.3.2 | Very old data | View 1+ year old booking | Data loads correctly | [ ] Pass [ ] Fail |
| 8.3.3 | Maximum items | Add 100 items to cart | Handles gracefully | [ ] Pass [ ] Fail |
| 8.3.4 | Simultaneous booking | Two clients book same slot | One succeeds, one gets "unavailable" | [ ] Pass [ ] Fail |
| 8.3.5 | Account deletion mid-conversation | User deleted while chatting | Graceful handling, "User unavailable" | [ ] Pass [ ] Fail |

---

## Test Results Summary

### Overall Statistics

| Category | Total Tests | Passed | Failed | Blocked |
|----------|-------------|--------|--------|---------|
| Authentication | 16 | | | |
| Client Features | 60 | | | |
| Supplier Features | 55 | | | |
| Admin Features | 35 | | | |
| Cross-Role Features | 22 | | | |
| Security | 15 | | | |
| Performance | 10 | | | |
| Edge Cases | 13 | | | |
| **TOTAL** | **226** | | | |

### Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| QA Lead | | | |
| Dev Lead | | | |
| Product Owner | | | |

---

## Notes & Issues Found

### Critical Issues
1.
2.
3.

### High Priority Issues
1.
2.
3.

### Medium Priority Issues
1.
2.
3.

### Low Priority Issues
1.
2.
3.

---

*Document Version: 1.0.0*
*Last Updated: January 2026*
*Total Test Cases: 226*
