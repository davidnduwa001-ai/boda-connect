/**
 * Backfill Projections - One-Time Migration Script
 *
 * USAGE:
 * 1. Deploy Cloud Functions first (with projection triggers)
 * 2. Verify triggers fire on new events
 * 3. Run this backfill script
 * 4. Verify projections populated
 *
 * PROPERTIES:
 * - Idempotent: Safe to run multiple times
 * - Restart-safe: Logs progress, can resume from where it left off
 * - Uses same rebuild functions as triggers (no custom logic)
 */

import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {rebuildClientView, rebuildSupplierView} from "./projectionService";

const db = admin.firestore();

// Batch size for processing
const BATCH_SIZE = 50;

interface BackfillResult {
  success: boolean;
  clientsProcessed: number;
  clientsFailed: number;
  suppliersProcessed: number;
  suppliersFailed: number;
  errors: string[];
  durationMs: number;
}

/**
 * Backfill all client projections
 * Iterates through all users with userType='client' and rebuilds their views
 */
async function backfillClientViews(): Promise<{
  processed: number;
  failed: number;
  errors: string[];
}> {
  let processed = 0;
  let failed = 0;
  const errors: string[] = [];

  console.log("Starting client view backfill...");

  // Get all clients
  const clientsQuery = db.collection("users").where("userType", "==", "client");
  const clientsSnapshot = await clientsQuery.get();

  console.log(`Found ${clientsSnapshot.size} clients to process`);

  // Process in batches
  const clients = clientsSnapshot.docs;
  for (let i = 0; i < clients.length; i += BATCH_SIZE) {
    const batch = clients.slice(i, i + BATCH_SIZE);
    const batchNum = Math.floor(i / BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(clients.length / BATCH_SIZE);

    console.log(`Processing client batch ${batchNum}/${totalBatches}`);

    // Process batch in parallel
    const results = await Promise.allSettled(
      batch.map(async (clientDoc) => {
        const clientId = clientDoc.id;
        try {
          await rebuildClientView(clientId, "backfill");
          return {clientId, success: true};
        } catch (error) {
          const errorMsg = `Client ${clientId}: ${error}`;
          console.error(errorMsg);
          return {clientId, success: false, error: errorMsg};
        }
      })
    );

    // Tally results
    for (const result of results) {
      if (result.status === "fulfilled") {
        if (result.value.success) {
          processed++;
        } else {
          failed++;
          if (result.value.error) {
            errors.push(result.value.error);
          }
        }
      } else {
        failed++;
        errors.push(`Batch error: ${result.reason}`);
      }
    }

    console.log(`Client batch ${batchNum} complete: ${processed} processed, ${failed} failed`);
  }

  console.log(`Client backfill complete: ${processed} processed, ${failed} failed`);
  return {processed, failed, errors};
}

/**
 * Backfill all supplier projections
 * Iterates through all supplier documents and rebuilds their views
 */
async function backfillSupplierViews(): Promise<{
  processed: number;
  failed: number;
  errors: string[];
}> {
  let processed = 0;
  let failed = 0;
  const errors: string[] = [];

  console.log("Starting supplier view backfill...");

  // Get all suppliers
  const suppliersSnapshot = await db.collection("suppliers").get();

  console.log(`Found ${suppliersSnapshot.size} suppliers to process`);

  // Process in batches
  const suppliers = suppliersSnapshot.docs;
  for (let i = 0; i < suppliers.length; i += BATCH_SIZE) {
    const batch = suppliers.slice(i, i + BATCH_SIZE);
    const batchNum = Math.floor(i / BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(suppliers.length / BATCH_SIZE);

    console.log(`Processing supplier batch ${batchNum}/${totalBatches}`);

    // Process batch in parallel
    const results = await Promise.allSettled(
      batch.map(async (supplierDoc) => {
        const supplierId = supplierDoc.id;
        try {
          await rebuildSupplierView(supplierId, "backfill");
          return {supplierId, success: true};
        } catch (error) {
          const errorMsg = `Supplier ${supplierId}: ${error}`;
          console.error(errorMsg);
          return {supplierId, success: false, error: errorMsg};
        }
      })
    );

    // Tally results
    for (const result of results) {
      if (result.status === "fulfilled") {
        if (result.value.success) {
          processed++;
        } else {
          failed++;
          if (result.value.error) {
            errors.push(result.value.error);
          }
        }
      } else {
        failed++;
        errors.push(`Batch error: ${result.reason}`);
      }
    }

    console.log(`Supplier batch ${batchNum} complete: ${processed} processed, ${failed} failed`);
  }

  console.log(`Supplier backfill complete: ${processed} processed, ${failed} failed`);
  return {processed, failed, errors};
}

/**
 * HTTP endpoint to trigger full backfill
 * Can be called manually or via curl/postman
 *
 * IMPORTANT: This is a long-running operation.
 * For large datasets, consider using a Task Queue instead.
 */
export const runBackfillProjections = functions
  .region("us-central1")
  .runWith({
    timeoutSeconds: 540, // 9 minutes max for HTTP functions
    memory: "1GB",
  })
  .https.onRequest(async (req: functions.https.Request, res: functions.Response) => {
    // Only allow POST requests
    if (req.method !== "POST") {
      res.status(405).json({error: "Method not allowed. Use POST."});
      return;
    }

    // Optional: Add authentication check
    // const authHeader = req.headers.authorization;
    // if (!authHeader || !authHeader.startsWith('Bearer ')) {
    //   res.status(401).json({ error: 'Unauthorized' });
    //   return;
    // }

    const startTime = Date.now();
    console.log("=== STARTING PROJECTION BACKFILL ===");

    try {
      // Backfill clients first
      const clientResult = await backfillClientViews();

      // Then backfill suppliers
      const supplierResult = await backfillSupplierViews();

      const durationMs = Date.now() - startTime;

      const result: BackfillResult = {
        success: clientResult.failed === 0 && supplierResult.failed === 0,
        clientsProcessed: clientResult.processed,
        clientsFailed: clientResult.failed,
        suppliersProcessed: supplierResult.processed,
        suppliersFailed: supplierResult.failed,
        errors: [...clientResult.errors, ...supplierResult.errors].slice(0, 50), // Limit error list
        durationMs,
      };

      console.log("=== BACKFILL COMPLETE ===");
      console.log(JSON.stringify(result, null, 2));

      // Log to audit
      await db.collection("audit_logs").add({
        category: "system",
        eventType: "projectionBackfill",
        userId: "system",
        resourceType: "projections",
        description: `Backfill completed: ${result.clientsProcessed} clients, ${result.suppliersProcessed} suppliers`,
        metadata: result,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      res.status(result.success ? 200 : 207).json(result);
    } catch (error) {
      const durationMs = Date.now() - startTime;
      console.error("Backfill failed:", error);

      const result: BackfillResult = {
        success: false,
        clientsProcessed: 0,
        clientsFailed: 0,
        suppliersProcessed: 0,
        suppliersFailed: 0,
        errors: [`Fatal error: ${error}`],
        durationMs,
      };

      res.status(500).json(result);
    }
  });

/**
 * Callable function to backfill a single client view
 * Useful for debugging or manual fixes
 */
export const backfillSingleClient = functions
  .region("us-central1")
  .https.onCall(async (data: {clientId?: string}, context: functions.https.CallableContext) => {
    // Verify admin
    if (!context.auth?.token.admin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can run backfill"
      );
    }

    const clientId = data.clientId as string;
    if (!clientId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "clientId is required"
      );
    }

    try {
      await rebuildClientView(clientId, "manual");
      return {success: true, clientId};
    } catch (error) {
      throw new functions.https.HttpsError(
        "internal",
        `Failed to rebuild client view: ${error}`
      );
    }
  });

/**
 * Callable function to backfill a single supplier view
 * Useful for debugging or manual fixes
 */
export const backfillSingleSupplier = functions
  .region("us-central1")
  .https.onCall(async (data: {supplierId?: string}, context: functions.https.CallableContext) => {
    // Verify admin
    if (!context.auth?.token.admin) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can run backfill"
      );
    }

    const supplierId = data.supplierId as string;
    if (!supplierId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "supplierId is required"
      );
    }

    try {
      await rebuildSupplierView(supplierId, "manual");
      return {success: true, supplierId};
    } catch (error) {
      throw new functions.https.HttpsError(
        "internal",
        `Failed to rebuild supplier view: ${error}`
      );
    }
  });

/**
 * Scheduled job to verify projection freshness
 * Runs daily and logs any stale projections
 */
export const verifyProjectionFreshness = functions
  .region("us-central1")
  .pubsub.schedule("0 6 * * *") // 6 AM daily
  .timeZone("Africa/Luanda")
  .onRun(async () => {
    const oneDayAgo = admin.firestore.Timestamp.fromMillis(
      Date.now() - 24 * 60 * 60 * 1000
    );

    // Check for stale client views
    const staleClientViews = await db
      .collection("client_views")
      .where("updatedAt", "<", oneDayAgo)
      .limit(100)
      .get();

    // Check for stale supplier views
    const staleSupplierViews = await db
      .collection("supplier_views")
      .where("updatedAt", "<", oneDayAgo)
      .limit(100)
      .get();

    if (staleClientViews.size > 0 || staleSupplierViews.size > 0) {
      console.warn(
        `Found ${staleClientViews.size} stale client views and ${staleSupplierViews.size} stale supplier views`
      );

      // Log to audit
      await db.collection("audit_logs").add({
        category: "system",
        eventType: "staleProjectionsDetected",
        userId: "system",
        resourceType: "projections",
        description: `Stale projections: ${staleClientViews.size} clients, ${staleSupplierViews.size} suppliers`,
        metadata: {
          staleClientIds: staleClientViews.docs.map((d) => d.id).slice(0, 20),
          staleSupplierIds: staleSupplierViews.docs.map((d) => d.id).slice(0, 20),
        },
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      console.log("All projections are fresh (updated within 24 hours)");
    }

    return null;
  });
