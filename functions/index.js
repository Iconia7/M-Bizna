const functions = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler"); // 👈 Import v2 Scheduler
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
admin.initializeApp();

exports.payheroCallback = functions.https.onRequest(async (req, res) => {
    const data = req.body;

    const payheroResponse = data.response || {};
    const fullReference = payheroResponse.ExternalReference; 
    const status = payheroResponse.Status; 

    if (!fullReference) {
        console.error("❌ ERROR: Missing ExternalReference", data);
        return res.status(400).send("Missing Reference");
    }

    try {
        const uiStatus = (status === "Success") ? "PAID" : "FAILED";

        // 1. Update the listener document
        await admin.firestore()
            .collection('payment_requests')
            .doc(fullReference)
            .set({
                status: uiStatus,
                amount: parseFloat(payheroResponse.Amount) || 0,
                mpesa_code: payheroResponse.MpesaReceiptNumber || "",
                updatedAt: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });

        // 2. Handle Logic if Payment was Successful
        if (status === "Success") {
            const parts = fullReference.split('|');
            const type = parts[0];   // "TOPUP", "SALE", or "SUB"
            const shopId = parts[1]; 
            const amountPaid = parseFloat(payheroResponse.Amount) || 0;

            if (shopId) {
                const shopRef = admin.firestore().collection('shops').doc(shopId);

                // --- 🚀 NEW: SUBSCRIPTION LOGIC ---
                if (type === "SUB") {
                    const shopDoc = await shopRef.get();
                    let currentExpiry = new Date();

                    if (shopDoc.exists && shopDoc.data().pro_expiry) {
                        const existingDate = shopDoc.data().pro_expiry.toDate();
                        // If current sub is still active, extend from that date. 
                        // Otherwise, start from today.
                        if (existingDate > currentExpiry) {
                            currentExpiry = existingDate;
                        }
                    }

                    // Add 30 days
                    currentExpiry.setDate(currentExpiry.getDate() + 30);

                    await shopRef.update({
                        pro_expiry: admin.firestore.Timestamp.fromDate(currentExpiry),
                        is_pro: true,
                        last_sub_date: admin.firestore.FieldValue.serverTimestamp()
                    });

                    // Log to history
                    await shopRef.collection('wallet_history').add({
                        amount: amountPaid,
                        type: "SUBSCRIPTION",
                        status: "SUCCESS",
                        description: "Pro Monthly Subscription",
                        date_time: admin.firestore.FieldValue.serverTimestamp(),
                    });
                } 
                
                // --- EXISTING WALLET LOGIC ---
                else {
                    await shopRef.collection('wallet_history').add({
                        amount: type === "TOPUP" ? amountPaid : -0.0, // We no longer charge 2.0 per sale
                        type: type,
                        status: "PAID",
                        description: type === "TOPUP" ? "Wallet Top Up" : "M-Pesa Sale (Pro)",
                        date_time: admin.firestore.FieldValue.serverTimestamp(),
                    });

                    if (type === "TOPUP") {
                        await shopRef.update({
                            wallet_balance: admin.firestore.FieldValue.increment(amountPaid)
                        });
                    }
                }
            }
        }

        return res.status(200).send("OK");
    } catch (err) {
        console.error("🔥 Sync Error:", err);
        return res.status(500).send("Internal Error");
    }
});
// This runs every day at midnight
exports.scheduledAutoRenewal = onSchedule('0 0 * * *', async (event) => {
    const now = admin.firestore.Timestamp.now();
    const shopsRef = admin.firestore().collection('shops');
    
    // 1. Find shops where subscription expired AND auto_renew is enabled
    const snapshot = await shopsRef
        .where('auto_renew', '==', true)
        .where('pro_expiry', '<=', now)
        .get();

    if (snapshot.empty) {
        console.log("No subscriptions due for renewal today.");
        return null;
    }

    const batch = admin.firestore().batch();

    snapshot.forEach(doc => {
        const data = doc.data();
        const balance = data.wallet_balance || 0;

        if (balance >= 200) {
            const currentExpiry = data.pro_expiry ? data.pro_expiry.toDate() : new Date();
            const newExpiry = new Date(currentExpiry);
            newExpiry.setDate(newExpiry.getDate() + 30);

            // 2. Deduct 200 and extend 30 days
            batch.update(doc.ref, {
                wallet_balance: admin.firestore.FieldValue.increment(-200),
                pro_expiry: admin.firestore.Timestamp.fromDate(newExpiry),
                is_pro: true
            });

            // 3. Log to history
            const historyRef = doc.ref.collection('wallet_history').doc();
            batch.set(historyRef, {
                amount: -200,
                type: 'SUBSCRIPTION',
                status: 'PAID',
                description: 'Automatic Pro Renewal',
                date_time: admin.firestore.FieldValue.serverTimestamp()
            });
            console.log(`✅ Renewed subscription for shop: ${doc.id}`);
        } else {
            // 4. If insufficient balance, turn off pro status
            batch.update(doc.ref, { is_pro: false });
            console.log(`⚠️ Insufficient balance for shop: ${doc.id}. Pro features disabled.`);
        }
    });

    return batch.commit();
});