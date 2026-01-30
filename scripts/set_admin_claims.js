/**
 * Set Admin Custom Claims Script
 *
 * USAGE:
 * 1. Install firebase-admin: npm install firebase-admin
 * 2. Download service account key from Firebase Console:
 *    - Go to Project Settings > Service Accounts
 *    - Click "Generate new private key"
 *    - Save as "serviceAccountKey.json" in this folder
 * 3. Run: node set_admin_claims.js <user-uid>
 *
 * Example: node set_admin_claims.js abc123def456
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

try {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (error) {
  console.error('❌ Error: Could not load serviceAccountKey.json');
  console.error('   Download it from Firebase Console > Project Settings > Service Accounts');
  process.exit(1);
}

async function setAdminClaim(uid) {
  try {
    // Set custom claim
    await admin.auth().setCustomUserClaims(uid, { admin: true });

    // Verify the claim was set
    const user = await admin.auth().getUser(uid);
    const claims = user.customClaims || {};

    if (claims.admin === true) {
      console.log('✅ Admin claim set successfully for user:', uid);
      console.log('   Email:', user.email);
      console.log('   Claims:', JSON.stringify(claims));
      console.log('');
      console.log('⚠️  User must sign out and sign back in for claims to take effect.');
    } else {
      console.error('❌ Failed to verify admin claim');
    }
  } catch (error) {
    console.error('❌ Error setting admin claim:', error.message);
  }
}

async function listAdmins() {
  console.log('📋 Listing users with admin claims...\n');

  const listUsersResult = await admin.auth().listUsers(1000);
  const admins = listUsersResult.users.filter(user =>
    user.customClaims && user.customClaims.admin === true
  );

  if (admins.length === 0) {
    console.log('   No users with admin claims found.');
  } else {
    admins.forEach(user => {
      console.log(`   - ${user.email || user.uid}`);
    });
  }
  console.log('');
}

async function removeAdminClaim(uid) {
  try {
    await admin.auth().setCustomUserClaims(uid, { admin: false });
    console.log('✅ Admin claim removed for user:', uid);
  } catch (error) {
    console.error('❌ Error removing admin claim:', error.message);
  }
}

// Main
async function main() {
  const args = process.argv.slice(2);
  const command = args[0];
  const uid = args[1];

  if (!command) {
    console.log('Usage:');
    console.log('  node set_admin_claims.js set <user-uid>     - Set admin claim');
    console.log('  node set_admin_claims.js remove <user-uid>  - Remove admin claim');
    console.log('  node set_admin_claims.js list               - List all admins');
    console.log('');
    console.log('Example:');
    console.log('  node set_admin_claims.js set abc123def456');
    process.exit(0);
  }

  switch (command) {
    case 'set':
      if (!uid) {
        console.error('❌ Please provide a user UID');
        process.exit(1);
      }
      await setAdminClaim(uid);
      break;
    case 'remove':
      if (!uid) {
        console.error('❌ Please provide a user UID');
        process.exit(1);
      }
      await removeAdminClaim(uid);
      break;
    case 'list':
      await listAdmins();
      break;
    default:
      console.error('❌ Unknown command:', command);
      process.exit(1);
  }

  process.exit(0);
}

main();
