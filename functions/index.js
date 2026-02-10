const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
const axios = require("axios");

admin.initializeApp();

// --- 💳 PAYHERO CALLBACK (V2) ---
exports.payheroCallback = onRequest(async (req, res) => {
    try {
        const data = req.body;
        const apiKey = req.query.api_key;
        if (apiKey !== process.env.CALLBACK_API_KEY) {
            console.warn("⚠️ UNAUTHORIZED CALLBACK ATTEMPT");
            return res.status(401).send("Unauthorized");
        }

        const payheroResponse = data.response || {};
        const fullReference = payheroResponse.ExternalReference;
        const status = payheroResponse.Status;

        if (!fullReference) return res.status(200).send("OK_IGNORE");

        const uiStatus = (status === "Success") ? "PAID" : "FAILED";
        await admin.firestore().collection('payment_requests').doc(fullReference).set({
            status: uiStatus,
            amount: parseFloat(payheroResponse.Amount) || 0,
            mpesa_code: payheroResponse.MpesaReceiptNumber || "",
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        if (status === "Success") {
            const parts = fullReference.split('|');
            const type = parts[0];   // "TOPUP", "SALE", or "SUB"
            const shopId = parts[1];
            const amountPaid = parseFloat(payheroResponse.Amount) || 0;

            if (shopId) {
                const shopRef = admin.firestore().collection('shops').doc(shopId);

                if (type === "SUB") {
                    const shopDoc = await shopRef.get();
                    let currentExpiry = new Date();
                    if (shopDoc.exists && shopDoc.data().pro_expiry) {
                        const existingDate = shopDoc.data().pro_expiry.toDate();
                        if (existingDate > currentExpiry) currentExpiry = existingDate;
                    }
                    currentExpiry.setDate(currentExpiry.getDate() + 30);
                    await shopRef.update({
                        pro_expiry: admin.firestore.Timestamp.fromDate(currentExpiry),
                        is_pro: true,
                        last_sub_date: admin.firestore.FieldValue.serverTimestamp()
                    });
                } else {
                    const payheroCost = calculatePayHeroFee(amountPaid);
                    const markup = 2.0;
                    const totalDeduction = payheroCost + markup;

                    await shopRef.collection('wallet_history').add({
                        amount: type === "TOPUP" ? amountPaid : -totalDeduction,
                        type: type,
                        status: "PAID",
                        description: type === "TOPUP" ? "Wallet Top Up" : `STK Processing Fee (KES ${payheroCost} + ${markup} Service)`,
                        date_time: admin.firestore.FieldValue.serverTimestamp(),
                    });

                    if (type === "TOPUP") {
                        await shopRef.update({ wallet_balance: admin.firestore.FieldValue.increment(amountPaid) });
                    } else if (totalDeduction > 0) {
                        await shopRef.update({ wallet_balance: admin.firestore.FieldValue.increment(-totalDeduction) });
                    }
                }
            }
        }
        return res.status(200).send("OK");
    } catch (err) {
        console.error("🔥 Callback Error:", err);
        return res.status(500).send("Error");
    }
});

// --- ⏰ DAILY AUTO-RENEWAL (V2) ---
exports.scheduledAutoRenewal = onSchedule('0 0 * * *', async (event) => {
    const now = admin.firestore.Timestamp.now();
    const snapshot = await admin.firestore().collection('shops').where('auto_renew', '==', true).where('pro_expiry', '<=', now).get();

    if (snapshot.empty) return null;
    const batch = admin.firestore().batch();

    snapshot.forEach(doc => {
        const data = doc.data();
        const balance = data.wallet_balance || 0;
        if (balance >= 200) {
            const currentExpiry = data.pro_expiry ? data.pro_expiry.toDate() : new Date();
            const newExpiry = new Date(currentExpiry);
            newExpiry.setDate(newExpiry.getDate() + 30);

            batch.update(doc.ref, {
                wallet_balance: admin.firestore.FieldValue.increment(-200),
                pro_expiry: admin.firestore.Timestamp.fromDate(newExpiry),
                is_pro: true
            });

            const historyRef = doc.ref.collection('wallet_history').doc();
            batch.set(historyRef, {
                amount: -200, type: 'SUBSCRIPTION', status: 'PAID',
                description: 'Automatic Pro Renewal', date_time: admin.firestore.FieldValue.serverTimestamp()
            });
        } else {
            batch.update(doc.ref, { is_pro: false });
        }
    });
    return batch.commit();
});

// --- 🚀 AUTOMATED MERCHANT ACTIVATION (V2) ---
exports.activateMerchantChannel = onCall(async (request) => {
    console.log("🛠️ ACTIVATION REQUEST DATA:", JSON.stringify(request.data));

    if (!request.auth) {
        console.error("❌ ERROR: Unauthenticated access attempt.");
        throw new HttpsError('unauthenticated', 'Login required.');
    }

    // Input from Flutter App
    const { shop_id, type, short_code, till_number, shop_name } = request.data;

    if (!shop_id || !short_code || !type) {
        console.error("❌ ERROR: Missing required fields in activation request.");
        throw new HttpsError('invalid-argument', 'Missing shop_id, type, or short_code.');
    }

    try {
        const payheroKey = process.env.PAYHERO_API_KEY;
        const accountId = parseInt(process.env.PAYHERO_ACCOUNT_ID); // 👈 New Required Field

        if (!payheroKey) {
            console.error("❌ ERROR: PAYHERO_API_KEY is missing in process.env");
            throw new HttpsError('failed-precondition', 'Server API Key configuration error.');
        }
        if (!accountId) {
            console.error("❌ ERROR: PAYHERO_ACCOUNT_ID is missing in process.env");
            throw new HttpsError('failed-precondition', 'Server Account ID configuration error.');
        }

        // Map App values to API values
        // App sends 'till' or 'paybill' (or capitalized). Docs require lowercase 'till' or 'paybill'.
        const apiChannelType = type.toLowerCase() === 'till' ? 'till' : 'paybill';

        // For 'till', account_number is often the same as the short_code (the till number itself).
        // For 'paybill', account_number is the specific account to pay to (if any), otherwise typically the paybill number again or a business ID.
        // Based on user app logic: type == 'Till' ? shortCode : null. 
        // Docs ensure account_number is required string. If null, we'll default to the short_code.
        const apiAccountNumber = till_number || short_code;

        console.log(`🔗 Registering ${apiChannelType} channel for shop: ${shop_id}`);

        const payload = {
            channel_type: apiChannelType,
            account_id: accountId,
            short_code: short_code.toString(), // 👈 Fix: Send as String, not Number
            account_number: apiAccountNumber.toString(), // Docs say string
            description: shop_name || `Shop_${shop_id}`
        };

        console.log("📤 Sending Payload to PayHero:", JSON.stringify(payload));

        const response = await axios.post('https://backend.payhero.co.ke/api/v2/payment_channels', payload, {
            headers: { 'Content-Type': 'application/json', 'Authorization': `Basic ${payheroKey}` }
        });

        console.log("✅ PAYHERO RESPONSE:", JSON.stringify(response.data));

        // Docs response: 200 OK with ID. 400 Bad Request.
        // We check if we got an ID back.
        if (!response.data.id) {
            throw new HttpsError('internal', 'PayHero registration did not return an ID.');
        }

        const channelId = response.data.id; // PayHero returns 'id', we store as 'payhero_channel_id'

        await admin.firestore().collection('shops').doc(shop_id).set({
            payhero_channel_id: channelId.toString(),
            is_active: true,
            activation_processed: true,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        console.log(`🎉 Success! Shop ${shop_id} linked to Channel ${channelId}`);
        return { success: true, channel_id: channelId };

    } catch (err) {
        console.error("🔥 Activation Critical Error:", err.response ? JSON.stringify(err.response.data) : err.message);

        if (err instanceof HttpsError) throw err;

        // Pass through PayHero error message if available
        const msg = err.response && err.response.data && err.response.data.error_message
            ? err.response.data.error_message
            : (err.message || 'Unknown activation error.');

        throw new HttpsError('internal', msg);
    }
});

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
    return 320;
}