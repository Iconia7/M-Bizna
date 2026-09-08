const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

if (!admin.apps.length) {
    admin.initializeApp();
}

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

        const axios = require("axios");
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

// --- 📱 AFRICA'S TALKING SMS OTP VERIFICATION ---

function normalizePhoneNumber(phone) {
    if (!phone) return null;
    let cleaned = phone.toString().replace(/[\s\-\+\(\)]/g, '');

    // Check test reviewer bypass number (+16505551234)
    if (cleaned === '16505551234') {
        return '+16505551234';
    }

    // Standard Kenyan mobile normalization:
    // Starts with 0 (e.g. 0712345678 or 0117814250 - 10 digits)
    if (cleaned.startsWith('0') && cleaned.length === 10) {
        cleaned = '254' + cleaned.substring(1);
    } 
    // 9 digits starting with 7 or 1 (e.g. 712345678 or 117814250)
    else if (cleaned.length === 9 && (cleaned.startsWith('7') || cleaned.startsWith('1'))) {
        cleaned = '254' + cleaned;
    }

    // Must start with 254 and have 12 digits, with mobile prefix 7 or 1
    if (cleaned.startsWith('254') && cleaned.length === 12) {
        const mobilePrefix = cleaned.charAt(3); // character after '254'
        if (mobilePrefix === '7' || mobilePrefix === '1') {
            return '+' + cleaned;
        }
    }

    return null; // Reject all non-Kenyan and invalid formats
}

exports.sendPhoneOTP = onCall(async (request) => {
    const { phone_number } = request.data || {};

    if (!phone_number) {
        throw new HttpsError('invalid-argument', 'Phone number is required.');
    }

    // 1. Strict Kenyan phone number validation
    const normalizedPhone = normalizePhoneNumber(phone_number);
    if (!normalizedPhone) {
        throw new HttpsError(
            'invalid-argument',
            'Invalid phone number. Only Kenyan mobile numbers (e.g. 07XXXXXXXX or 01XXXXXXXX) are supported.'
        );
    }

    // 2. Test bypass for Play Store review and testing bot (never hits Africa's Talking)
    if (normalizedPhone === '+254117814250' || normalizedPhone === '+16505551234') {
        await admin.firestore().collection('phone_verifications').doc(normalizedPhone).set({
            code: '123456',
            expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 60 * 60 * 1000)),
            attempts: 0,
            createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        return { success: true, message: 'Test verification code generated.' };
    }

    // 3. Strict 24-hour Rate Limiter & 60s cooldown
    const rateLimitRef = admin.firestore().collection('otp_rate_limits').doc(normalizedPhone);
    const rateLimitDoc = await rateLimitRef.get();
    const nowMs = Date.now();
    const oneDayAgoMs = nowMs - 24 * 60 * 60 * 1000;
    let recentAttempts = [];

    if (rateLimitDoc.exists) {
        const rateData = rateLimitDoc.data() || {};

        // Cooldown check: 60 seconds minimum between consecutive requests
        if (rateData.lastAttemptAt) {
            const lastAttemptMs = rateData.lastAttemptAt.toMillis ? rateData.lastAttemptAt.toMillis() : new Date(rateData.lastAttemptAt).getTime();
            const timeSinceLastSec = (nowMs - lastAttemptMs) / 1000;
            if (timeSinceLastSec < 60) {
                const waitSec = Math.ceil(60 - timeSinceLastSec);
                throw new HttpsError(
                    'resource-exhausted',
                    `Please wait ${waitSec} second${waitSec === 1 ? '' : 's'} before requesting another verification code.`
                );
            }
        }

        // Filter attempts to rolling 24-hour window
        const rawAttempts = Array.isArray(rateData.attempts) ? rateData.attempts : [];
        recentAttempts = rawAttempts
            .map(t => (t && typeof t.toMillis === 'function') ? t.toMillis() : (typeof t === 'number' ? t : new Date(t).getTime()))
            .filter(timestamp => !isNaN(timestamp) && timestamp > oneDayAgoMs);

        const MAX_OTP_PER_24H = 3;
        if (recentAttempts.length >= MAX_OTP_PER_24H) {
            recentAttempts.sort((a, b) => a - b);
            const oldestAttemptMs = recentAttempts[0];
            const msUntilReset = (oldestAttemptMs + 24 * 60 * 60 * 1000) - nowMs;
            const hoursLeft = Math.max(1, Math.ceil(msUntilReset / (1000 * 60 * 60)));
            throw new HttpsError(
                'resource-exhausted',
                `Daily limit reached: Maximum ${MAX_OTP_PER_24H} verification codes allowed per 24 hours. Please try again in ${hoursLeft} hour${hoursLeft === 1 ? '' : 's'}.`
            );
        }
    }

    // Generate secure 6-digit OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    // Store OTP in Firestore (10 min expiry)
    await admin.firestore().collection('phone_verifications').doc(normalizedPhone).set({
        code: otp,
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 10 * 60 * 1000)),
        attempts: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Record this attempt in rate limiter
    recentAttempts.push(nowMs);
    await rateLimitRef.set({
        phoneNumber: normalizedPhone,
        attempts: recentAttempts.map(ts => admin.firestore.Timestamp.fromMillis(ts)),
        lastAttemptAt: admin.firestore.Timestamp.fromMillis(nowMs),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    try {
        const atApiKey = process.env.AT_API_KEY;
        const atUsername = process.env.AT_USERNAME || 'dita';
        const atSenderId = process.env.AT_SENDER_ID || 'NexoraKE';

        if (!atApiKey) {
            console.error("❌ ERROR: AT_API_KEY is not set in environment.");
            throw new HttpsError('failed-precondition', 'Africa\'s Talking API Key is not configured on the server.');
        }

        const payload = new URLSearchParams({
            username: atUsername,
            to: normalizedPhone,
            message: `Your M-Bizna verification code is ${otp}. Valid for 10 minutes.`,
            from: atSenderId
        });

        const axios = require("axios");
        console.log(`📤 Sending SMS to ${normalizedPhone} via Africa's Talking (Sender: ${atSenderId}, User: ${atUsername})`);

        const response = await axios.post('https://api.africastalking.com/version1/messaging', payload.toString(), {
            headers: {
                'apiKey': atApiKey,
                'Content-Type': 'application/x-www-form-urlencoded',
                'Accept': 'application/json'
            }
        });

        console.log("✅ Africa's Talking Response:", JSON.stringify(response.data));

        return {
            success: true,
            message: 'Verification code sent successfully.'
        };
    } catch (err) {
        console.error("🔥 Africa's Talking SMS Error:", err.response ? JSON.stringify(err.response.data) : err.message);
        if (err instanceof HttpsError) throw err;
        throw new HttpsError('internal', 'Failed to send SMS verification code. Please try again.');
    }
});

exports.verifyPhoneOTP = onCall(async (request) => {
    const { phone_number, code } = request.data || {};

    if (!phone_number || !code) {
        throw new HttpsError('invalid-argument', 'Phone number and verification code are required.');
    }

    const normalizedPhone = normalizePhoneNumber(phone_number.toString().trim());
    if (!normalizedPhone) {
        throw new HttpsError('invalid-argument', 'Invalid phone number. Only Kenyan mobile numbers are supported.');
    }
    const docRef = admin.firestore().collection('phone_verifications').doc(normalizedPhone);
    const doc = await docRef.get();

    if (!doc.exists) {
        throw new HttpsError('not-found', 'No verification code was requested for this phone number.');
    }

    const data = doc.data();

    if (data.expiresAt.toDate() < new Date()) {
        await docRef.delete();
        throw new HttpsError('deadline-exceeded', 'Verification code has expired. Please request a new one.');
    }

    if (data.attempts >= 5) {
        await docRef.delete();
        throw new HttpsError('resource-exhausted', 'Too many failed attempts. Please request a new code.');
    }

    if (data.code !== code.toString().trim()) {
        await docRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
        throw new HttpsError('invalid-argument', 'Invalid verification code. Please try again.');
    }

    // Code is valid - clean up
    await docRef.delete();

    // Find or create Firebase Auth user
    let userRecord;
    try {
        userRecord = await admin.auth().getUserByPhoneNumber(normalizedPhone);
    } catch (err) {
        if (err.code === 'auth/user-not-found') {
            userRecord = await admin.auth().createUser({
                phoneNumber: normalizedPhone,
                displayName: `Merchant (${normalizedPhone.slice(-4)})`
            });
        } else {
            console.error("🔥 Firebase User lookup error:", err);
            throw new HttpsError('internal', 'Authentication failed during user creation.');
        }
    }

    // Mint custom auth token for Flutter Firebase Auth client (with safe fallback if Service Account Token Creator role is missing)
    let customToken = null;
    try {
        customToken = await admin.auth().createCustomToken(userRecord.uid);
    } catch (tokenErr) {
        console.warn("⚠️ createCustomToken notice (falling back to user UID):", tokenErr.message);
    }

    return {
        success: true,
        custom_token: customToken,
        uid: userRecord.uid,
        phone_number: normalizedPhone
    };
});