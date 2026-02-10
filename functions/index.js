const functions = require("firebase-functions");
const { onSchedule } = require("firebase-functions/v2/scheduler"); // 👈 Import v2 Scheduler
const { onRequest } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const axios = require("axios");
admin.initializeApp();

exports.payheroCallback = functions.https.onRequest(async (req, res) => {
    const data = req.body;

    // 🛡️ SECURITY: Basic API Key Verification
    // In a production app, use PayHero's signature verification if available.
    const apiKey = req.query.api_key;
    if (apiKey !== process.env.CALLBACK_API_KEY) {
        console.error("⛔ UNAUTHORIZED: Invalid Callback API Key");
        return res.status(401).send("Unauthorized");
    }

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

                // --- WALLET DEDUCTION FOR TRANSACTION FEES ---
                else {
                    const amountPaid = parseFloat(payheroResponse.Amount) || 0;
                    const payheroCost = calculatePayHeroFee(amountPaid);
                    const markup = 2.0; // Small markup to cover platform overhead
                    const totalDeduction = payheroCost + markup;

                    await shopRef.collection('wallet_history').add({
                        amount: type === "TOPUP" ? amountPaid : -totalDeduction,
                        type: type,
                        status: "PAID",
                        description: type === "TOPUP" ? "Wallet Top Up" : `STK Processing Fee (KES ${payheroCost} + ${markup} Service)`,
                        date_time: admin.firestore.FieldValue.serverTimestamp(),
                    });

                    if (type === "TOPUP") {
                        await shopRef.update({
                            wallet_balance: admin.firestore.FieldValue.increment(amountPaid)
                        });
                    } else if (totalDeduction > 0) {
                        // Deduct fee from wallet
                        await shopRef.update({
                            wallet_balance: admin.firestore.FieldValue.increment(-totalDeduction)
                        });
                        console.log(`💸 Dynamic Deduction: ${totalDeduction} from Shop ${shopId} (Amount: ${amountPaid})`);
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

/**
 * Calculates the exact PayHero transaction fee based on tiered pricing
 */
function calculatePayHeroFee(amount) {
    if (amount <= 49) return 0;
    if (amount <= 499) return 6;
    if (amount <= 999) return 10;
    if (amount <= 1499) return 15;
    if (amount <= 2499) return 20;
    if (amount <= 3499) return 25;
    if (amount <= 4999) return 30;
    if (amount <= 7499) return 40;
    if (amount <= 9999) return 45;
    if (amount <= 14999) return 50;
    if (amount <= 19999) return 55;
    if (amount <= 34999) return 80;
    if (amount <= 49999) return 105;
    if (amount <= 149999) return 130;
    if (amount <= 249999) return 160;
    if (amount <= 349999) return 195;
    if (amount <= 549999) return 230;
    if (amount <= 749999) return 275;
    return 320; // 750k+
}
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

// --- 🚀 NEW: AUTOMATED MERCHANT ACTIVATION ---
exports.activateMerchantChannel = functions.https.onCall(async (data, context) => {
    // 🛡️ Ensure user is authenticated
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'User must be logged in.');
    }

    const { shop_id, type, short_code, till_number, shop_name } = data;

    if (!shop_id || !short_code || !type) {
        throw new functions.https.HttpsError('invalid-argument', 'Missing shop_id, type, or short_code.');
    }

    try {
        const payheroKey = process.env.PAYHERO_API_KEY;
        if (!payheroKey) {
            console.error("🔥 Missing PAYHERO_API_KEY in environment");
            throw new functions.https.HttpsError('failed-precondition', 'Server not configured for activation.');
        }

        // 1. Register Channel on PayHero Programmatically using Axios
        const response = await axios.post('https://backend.payhero.co.ke/api/v2/payment_channels', {
            name: shop_name || `Shop_${shop_id}`,
            type: type, // 'Till' or 'Paybill'
            shortcode: short_code,
            till_number: till_number || null
        }, {
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Basic ${payheroKey}`
            }
        });

        const result = response.data;

        if (!result.success) {
            console.error("❌ PayHero Registration Failed:", result);
            throw new functions.https.HttpsError('internal', result.message || 'Failed to register with PayHero.');
        }

        const channelId = result.channel_id;

        // 2. Link this channel_id to the shop in Firestore
        await admin.firestore().collection('shops').doc(shop_id).set({
            payhero_channel_id: channelId.toString(),
            is_active: true,
            activation_processed: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        console.log(`✅ Automated Activation Success for Shop ${shop_id}. Channel: ${channelId}`);

        return {
            success: true,
            channel_id: channelId
        };

    } catch (err) {
        console.error("🔥 Activation Critical Error:", err.response ? err.response.data : err.message);
        throw new functions.https.HttpsError('internal', (err.response && err.response.data && err.response.data.message) ? err.response.data.message : err.message);
    }
});