/**
 * LocalLink Cloud Functions (Firebase Functions v2)
 * PRODUCTION BILLING ENGINE – Subscriptions + Booking Fulfilment (Stripe PI Webhook)
 */

const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

const { onDocumentCreated } = require("firebase-functions/v2/firestore");

const { onCall, onRequest, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const logger = require("firebase-functions/logger");

const STRIPE_API_VERSION = "2023-10-16";

let stripeClient = null;

function getStripe() {
  const key = process.env.STRIPE_SECRET_KEY;
    console.log("🔥 STRIPE KEY:", key.substring(0, 8));
  if (!key) throw new HttpsError("failed-precondition", "Stripe secret not configured.");
  if (!stripeClient) stripeClient = require("stripe")(key, { apiVersion: STRIPE_API_VERSION });
  return stripeClient;
}

function assert(cond, code, msg) {
  if (!cond) throw new HttpsError(code, msg);
}

function safeTrim(s) {
  return String(s ?? "").trim();
}

//
// =================================================
// ENTITLEMENTS HELPERS
// =================================================
//
function timestampToMillis(value) {
  if (!value) return null;

  if (typeof value.toMillis === "function") {
    return value.toMillis();
  }

  if (value instanceof Date) {
    return value.getTime();
  }

  if (typeof value === "number") {
    return value;
  }

  return null;
}

function hoursUntil(timestampValue) {
  const millis = timestampToMillis(timestampValue);
  if (!millis) return null;
  return (millis - Date.now()) / (1000 * 60 * 60);
}

function bookingMessageRef(bookingId) {
  return db.collection("bookings").doc(bookingId).collection("messages");
}

async function isBusinessOwner(uid, businessId) {
  const snap = await db.collection("businesses").doc(businessId).get();
  return snap.exists && snap.data()?.ownerId === uid;
}

async function addSystemBookingMessage(bookingId, text) {
  await bookingMessageRef(bookingId).add({
    senderId: "system",
    senderRole: "system",
    text,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function releaseBookedSlot({ businessId, staffId, slotId }) {
  if (!businessId || !staffId || !slotId) return;

  const slotRef = db
    .collection("businesses")
    .doc(businessId)
    .collection("staff")
    .doc(staffId)
    .collection("availableSlots")
    .doc(slotId);

  const snap = await slotRef.get();
  if (!snap.exists) return;

  await slotRef.update({
    isBooked: false,
    lockedByBookingId: admin.firestore.FieldValue.delete(),
    lockExpiresAt: admin.firestore.FieldValue.delete(),
  });
}

function buildCancellationOutcome({ cancelledBy, shouldRefund, hoursBeforeStart }) {
  if (cancelledBy === "business") {
    return {
      bookingStatus: "cancelled_by_business",
      refundStatus: shouldRefund ? "processed" : "not_applicable",
      systemMessage: shouldRefund
        ? "This booking was cancelled by the business. A refund has been issued."
        : "This booking was cancelled by the business.",
    };
  }

  if (shouldRefund) {
    return {
      bookingStatus: "cancelled_by_customer",
      refundStatus: "processed",
      systemMessage:
        "This booking was cancelled by the customer more than 24 hours before the appointment. A refund has been issued.",
    };
  }

  return {
    bookingStatus: "cancelled_by_customer",
    refundStatus: "not_applicable",
    systemMessage:
      hoursBeforeStart !== null && hoursBeforeStart < 24
        ? "This booking was cancelled by the customer less than 24 hours before the appointment. No refund is due under the cancellation policy."
        : "This booking was cancelled by the customer.",
  };
}
function entitlementsRef(businessId) {
  return db.collection("businesses").doc(businessId).collection("entitlements").doc("default");
}

async function ensureEntitlementsDoc(businessId) {
  const ref = entitlementsRef(businessId);
  const snap = await ref.get();

  if (!snap.exists) {
    await ref.set(
      {
        freeStaffSlots: 1,
        extraStaffSlots: 0,
        stripeStatus: "free",
        restrictionMode: false,
        pastDueSince: null,
        currentPeriodEnd: null,
        stripeCustomerId: null,
        stripeSubscriptionId: null,
      },
      { merge: true }
    );
  }
}
function stripeEventRef(eventId) {
  return db.collection("stripeWebhookEvents").doc(eventId);
}

async function getAllowedSeats(businessId) {
  const snap = await entitlementsRef(businessId).get();
  const data = snap.exists ? snap.data() : {};
  const free = typeof data.freeStaffSlots === "number" ? data.freeStaffSlots : 1;
  const extra = typeof data.extraStaffSlots === "number" ? data.extraStaffSlots : 0;
  return free + extra;
}

async function syncExtraStaffSlots(businessId, quantity) {
  await entitlementsRef(businessId).set(
    { extraStaffSlots: Math.max(0, Number(quantity || 0)) },
    { merge: true }
  );
}

async function syncSubscriptionStatus(businessId, status) {
  await entitlementsRef(businessId).set({ stripeStatus: status }, { merge: true });
}

async function syncCurrentPeriodEnd(businessId, unixSeconds) {
  const ts = unixSeconds
    ? admin.firestore.Timestamp.fromMillis(Number(unixSeconds) * 1000)
    : null;
  await entitlementsRef(businessId).set({ currentPeriodEnd: ts }, { merge: true });
}

async function setPastDueTimestamp(businessId) {
  await entitlementsRef(businessId).set(
    { pastDueSince: admin.firestore.FieldValue.serverTimestamp() },
    { merge: true }
  );
}

async function clearPastDueTimestamp(businessId) {
  await entitlementsRef(businessId).set({ pastDueSince: null }, { merge: true });
}

async function enableRestrictionMode(businessId) {
  await entitlementsRef(businessId).set({ restrictionMode: true }, { merge: true });
}

async function disableRestrictionMode(businessId) {
  await entitlementsRef(businessId).set({ restrictionMode: false }, { merge: true });
}

const { getMessaging } = require("firebase-admin/messaging");

async function sendPushToUser(uid, payload) {
  if (!uid) return;

  const userRef = db.collection("users").doc(uid);
  const snap = await userRef.get();

  if (!snap.exists) return;

  const tokens = snap.data()?.fcmTokens || [];
  if (!tokens.length) return;

  const message = {
    tokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: payload.data || {},
  };

  try {
    await getMessaging().sendEachForMulticast(message);
  } catch (err) {
    console.error("Push send error:", err);
  }
}

// =================================================
// 🔔 NEW BOOKING NOTIFICATION
// =================================================

exports.notifyNewBooking = onDocumentCreated(
  {
    document: "bookings/{bookingId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const booking = event.data?.data();
      if (!booking) return;

      const businessId = booking.businessId;
      if (!businessId) return;

      if (booking.status !== "pending_payment" && booking.status !== "confirmed") return;

      const businessSnap = await db.collection("businesses").doc(businessId).get();
      const ownerId = businessSnap.data()?.ownerId;
      if (!ownerId) return;

      const userSnap = await db.collection("users").doc(ownerId).get();
      const tokens = userSnap.data()?.fcmTokens || [];
      if (!tokens.length) return;

      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "New booking",
          body: `${booking.customerName || "A customer"} booked ${booking.serviceName || "a service"}`
        },
        data: {
          bookingId: event.params.bookingId
        }
      });

    } catch (error) {
      console.error("❌ notifyNewBooking error:", error);
    }
  }
);

// =================================================
// 💬 NEW MESSAGE NOTIFICATION
// =================================================

exports.notifyNewMessage = onDocumentCreated(
  {
    document: "bookings/{bookingId}/messages/{messageId}",
    region: "us-central1",
  },
  async (event) => {
    try {
      const message = event.data?.data();
      if (!message) return;

      const bookingId = event.params.bookingId;

      const bookingSnap = await db.collection("bookings").doc(bookingId).get();
      if (!bookingSnap.exists) return;

      const booking = bookingSnap.data();

      let targetUserId;

      if (message.senderId === booking.customerId) {
        const businessSnap = await db.collection("businesses").doc(booking.businessId).get();
        targetUserId = businessSnap.data()?.ownerId;
      } else {
        targetUserId = booking.customerId;
      }

      if (!targetUserId) return;

      const userSnap = await db.collection("users").doc(targetUserId).get();
      const tokens = userSnap.data()?.fcmTokens || [];
      if (!tokens.length) return;

      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: {
          title: "New message",
          body: message.text || "You have a new message"
        },
        data: { bookingId }
      });

    } catch (error) {
      console.error("❌ notifyNewMessage error:", error);
    }
  }
);
//
// =================================================
// 7-DAY GRACE → RESTRICTION MODE EVALUATION
// =================================================
//

async function evaluateRestrictionState(businessId) {
  const entSnap = await entitlementsRef(businessId).get();
  if (!entSnap.exists) return;

  const ent = entSnap.data();
  const status = ent.stripeStatus;
  const pastDueSince = ent.pastDueSince;

  if (status === "active" || status === "free") {
    await disableRestrictionMode(businessId);
    return;
  }

  if (status === "past_due") {
    if (!pastDueSince) {
      await disableRestrictionMode(businessId);
      return;
    }

    const graceMs = 7 * 24 * 60 * 60 * 1000;
    const now = Date.now();
    const pastDueMs = pastDueSince.toMillis();

    if (now - pastDueMs > graceMs) await enableRestrictionMode(businessId);
    else await disableRestrictionMode(businessId);
    return;
  }

  if (status && status !== "past_due" && status !== "active" && status !== "free") {
    await enableRestrictionMode(businessId);
  }
}

//
// =================================================
// SEAT ENFORCEMENT
// =================================================
//

async function applySeatEnforcement(businessId) {
  const businessRef = db.collection("businesses").doc(businessId);
  const allowed = await getAllowedSeats(businessId);

  const staffSnap = await businessRef.collection("staff").orderBy("seatRank").get();
  if (staffSnap.empty) return;

  const batch = db.batch();

  staffSnap.docs.forEach((doc, idx) => {
    const shouldBeActive = idx < allowed;
    const currentActive = doc.data().isActive !== false;
    if (currentActive !== shouldBeActive) batch.update(doc.ref, { isActive: shouldBeActive });
  });

  await batch.commit();

  logger.info("Seat enforcement applied", { businessId, allowed, staffCount: staffSnap.size });
}
exports.previewSeatReductionImpact = onCall(
  { region: "us-central1" },
  async (request) => {
    assert(request.auth, "unauthenticated", "Login required.");

    const uid = request.auth.uid;
    const businessId = request.data?.businessId;

    assert(businessId, "invalid-argument", "Missing businessId.");

    const businessRef = db.collection("businesses").doc(businessId);
    const businessSnap = await businessRef.get();

    assert(businessSnap.exists, "not-found", "Business not found.");
    assert(businessSnap.data().ownerId === uid, "permission-denied", "Not owner.");

    const allowed = await getAllowedSeats(businessId);
    const newAllowed = Math.max(0, allowed - 1);

    const staffSnap = await businessRef
      .collection("staff")
      .orderBy("seatRank")
      .get();

    const impacted = staffSnap.docs
      .map((doc, idx) => ({
        id: doc.id,
        name: doc.data().name || "Unnamed staff",
        seatRank: doc.data().seatRank ?? 9999,
        wouldBeActive: idx < newAllowed
      }))
      .filter((staff) => !staff.wouldBeActive);

    return {
      currentAllowed: allowed,
      newAllowed,
      impacted
    };
  }
);


exports.cancelBooking = onCall(async (request) => {

  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  const bookingId = safeTrim(request.data?.bookingId);
  if (!bookingId) {
    throw new HttpsError("invalid-argument", "Missing bookingId.");
  }

  const bookingRef = db.collection("bookings").doc(bookingId);
  const bookingSnap = await bookingRef.get();

  if (!bookingSnap.exists) {
    throw new HttpsError("not-found", "Booking not found.");
  }

  const booking = bookingSnap.data() || {};

  const status = safeTrim(booking.status);
  const businessId = safeTrim(booking.businessId);
  const customerId = safeTrim(booking.customerId);
  const staffId = safeTrim(booking.staffId);
  const slotId = safeTrim(booking.slotId);
  const paymentIntentId = safeTrim(booking.paymentIntentId);

  if (!businessId) {
    throw new HttpsError("failed-precondition", "Missing businessId.");
  }

  const startDate = booking.startDate?.toDate?.();
  if (!startDate) {
    throw new HttpsError("failed-precondition", "Missing booking date.");
  }

  const now = new Date();

  // 🚫 Block past bookings
  if (startDate < now) {
    throw new HttpsError("failed-precondition", "Cannot cancel past bookings.");
  }

  // 🚫 Prevent double cancel
  if (status?.startsWith("cancelled")) {
    return { ok: true, alreadyCancelled: true };
  }

  // 🔐 Check permissions
  const isCustomer = uid === customerId;
  const isBusiness = await isBusinessOwner(uid, businessId);

  if (!isCustomer && !isBusiness) {
    throw new HttpsError("permission-denied", "Not allowed.");
  }

  const cancelledBy = isBusiness ? "business" : "customer";

  // ⏱ Time logic
  const hoursBefore = (startDate - now) / (1000 * 60 * 60);

  let shouldRefund = false;

  if (cancelledBy === "business") {
    shouldRefund = true;
  } else if (cancelledBy === "customer") {
    shouldRefund = hoursBefore >= 24;
  }

  // 💸 REFUND
  let refundId = null;

  if (shouldRefund && paymentIntentId) {
    const stripe = getStripe();

    const existing = await stripe.refunds.list({
      payment_intent: paymentIntentId,
      limit: 1
    });

    if (existing.data.length > 0) {
      refundId = existing.data[0].id;
    } else {
      const refund = await stripe.refunds.create({
        payment_intent: paymentIntentId
      });
      refundId = refund.id;
    }

    console.log("💸 Refund processed:", refundId);
  }

  // 📊 Final states
  const bookingStatus = cancelledBy === "business"
    ? "cancelled_by_business"
    : "cancelled_by_customer";

  const refundStatus = shouldRefund ? "refunded" : "not_refunded";

  // 🔄 Batch update
  const batch = db.batch();

  batch.update(bookingRef, {
    status: bookingStatus,
    cancelledBy,
    cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    refundStatus,
    refundId: refundId || null,
    updatedAt: admin.firestore.FieldValue.serverTimestamp()
  });

  // 🔓 Release slot (FIXED PATH + CLEAN DELETE)
  if (slotId && staffId) {
  const slotRef = db
    .collection("businesses")
    .doc(businessId)
    .collection("staff")
    .doc(staffId)
    .collection("availableSlots")
    .doc(slotId);

  batch.update(slotRef, {
    isBooked: false,
    lockedByBookingId: admin.firestore.FieldValue.delete(),
    lockExpiresAt: admin.firestore.FieldValue.delete()
  });
}

  await batch.commit();

  // 🔥 SYSTEM MESSAGE
  await addSystemBookingMessage(
    bookingId,
    cancelledBy === "business"
      ? "Booking cancelled by business"
      : "Booking cancelled by customer"
  );

  // 🔔 PUSH + UNREAD
  if (cancelledBy === "business") {

    await sendPushToUser(customerId, {
      title: "Booking cancelled",
      body: "Your booking was cancelled by the business. A refund has been issued.",
      data: { bookingId, type: "booking_cancelled" }
    });

    await bookingRef.update({
      unreadForCustomer: admin.firestore.FieldValue.increment(1),
    });

} else {

  const businessSnap = await db.collection("businesses").doc(businessId).get();
  const ownerId = businessSnap.data()?.ownerId;

  await sendPushToUser(ownerId, {
    title: "Booking cancelled",
    body: "A customer has cancelled their booking.",
    data: { bookingId, type: "booking_cancelled" }
  });

  await bookingRef.update({
    unreadForBusiness: admin.firestore.FieldValue.increment(1),
  });
}

  return {
    ok: true,
    bookingId,
    bookingStatus,
    cancelledBy,
    refundIssued: !!refundId,
    refundStatus,
    hoursBefore,
  };
});
// =================================================
// STRIPE HELPERS
// =================================================
//

async function resolveBusinessIdFromCustomer(stripe, customerId) {
  console.log("🔍 Resolving business for customer:", customerId);

  const businessesSnap = await db.collection("businesses").get();

  for (const doc of businessesSnap.docs) {
    const entSnap = await doc.ref
      .collection("entitlements")
      .doc("default")
      .get();

    const stripeCustomerId = entSnap.data()?.stripeCustomerId;

    if (stripeCustomerId === customerId) {
      console.log("✅ Resolved businessId:", doc.id);
      return doc.id;
    }
  }

  console.log("❌ No business found for customer:", customerId);
  return null;
}

async function getClientSecretFromSubscription(stripe, subscription) {
  const latestInvoice = subscription.latest_invoice;
  if (!latestInvoice) return null;

  if (typeof latestInvoice === "object") {
    return latestInvoice.payment_intent?.client_secret ?? null;
  }

  if (typeof latestInvoice === "string") {
    const invoice = await stripe.invoices.retrieve(latestInvoice, { expand: ["payment_intent"] });
    return invoice.payment_intent?.client_secret ?? null;
  }

  return null;
}

//
// =================================================
// BOOKING HELPERS
// =================================================

function slotRef(businessId, staffId, slotId) {
  return db
    .collection("businesses")
    .doc(businessId)
    .collection("staff")
    .doc(staffId)
    .collection("availableSlots")
    .doc(slotId);
}

async function fetchServicePricePence(businessId, serviceId) {

  const snap = await db
    .collection("businesses")
    .doc(businessId)
    .collection("services")
    .doc(serviceId)
    .get();

  if (!snap.exists) {
    throw new HttpsError("not-found", "Service not found");
  }

  const service = snap.data();

  if (typeof service.price !== "number") {
    throw new HttpsError("failed-precondition", "Service price invalid");
  }

  return Math.round(service.price * 100);
}
async function staffIsActiveServer(businessId, staffId) {

  const s = await db
    .collection("businesses")
    .doc(businessId)
    .collection("staff")
    .doc(staffId)
    .get()

  if (!s.exists) return false
  return s.data().isActive !== false
}

async function sendSystemMessage(bookingId, text) {

  const messageRef = db
    .collection("bookings")
    .doc(bookingId)
    .collection("messages")
    .doc()

  await messageRef.set({
    senderId: "system",
    senderRole: "system",
    text: text,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  })
}



// =================================================
// CREATE BOOKING + PAYMENT INTENT (CONNECT VERSION)
// =================================================

exports.createBookingPaymentIntent = onCall(
  {
    region: "us-central1",
    secrets: ["STRIPE_SECRET_KEY"],
  },
  async (request) => {

    try {

        console.log("🔥 FUNCTION HIT", {
          uid: request.auth?.uid,
          provider: request.auth?.token?.firebase?.sign_in_provider,
          data: request.data,
        });
      // 🔒 AUTH
      assert(request.auth, "unauthenticated", "Login required.");

      const provider = request.auth.token?.firebase?.sign_in_provider;

      if (provider === "anonymous") {
        console.log("❌ BLOCKED: Anonymous user");
        throw new HttpsError(
          "failed-precondition",
          "Please log in to make a booking"
        );
      }

      const stripe = getStripe();
      const customerId = request.auth.uid;

      // =================================================
      // EXTRACT DATA
      // =================================================

      const businessId = safeTrim(request.data?.businessId);
      const staffId = safeTrim(request.data?.staffId);
      const serviceId = safeTrim(request.data?.serviceId);
      const slotId = safeTrim(request.data?.slotId);
      const customerName = safeTrim(request.data?.customerName);
      const customerAddress = safeTrim(request.data?.customerAddress);

      console.log("📦 Booking Params:", {
        businessId, staffId, serviceId, slotId,
        customerName, customerAddress
      });

      assert(
        businessId && staffId && serviceId && slotId,
        "invalid-argument",
        "Missing booking data."
      );

      // =================================================
      // SLOT REFERENCE
      // =================================================

      const slotDocRef = db
        .collection("businesses")
        .doc(businessId)
        .collection("staff")
        .doc(staffId)
        .collection("availableSlots")
        .doc(slotId);

      // =================================================
      // VALIDATE SLOT
      // =================================================

      const slotSnap = await slotDocRef.get();

      if (!slotSnap.exists) {
        console.log("❌ Slot does not exist:", slotId);
        throw new HttpsError("failed-precondition", "Slot does not exist");
      }

      const slot = slotSnap.data();

      console.log("🕒 Slot data:", slot);

      const isBooked =
        typeof slot.isBooked === "boolean"
          ? slot.isBooked
          : slot.isBooked === 1;

      if (isBooked) {
        console.log("❌ Slot already booked");
        throw new HttpsError("failed-precondition", "Slot already booked");
      }

      if (!slot.startTime || !slot.startTime.toDate) {
        console.log("❌ Invalid slot startTime:", slot.startTime);
        throw new HttpsError("internal", "Invalid slot data");
      }

      if (slot.startTime.toDate() < new Date()) {
        console.log("❌ Slot in the past:", slot.startTime.toDate());
        throw new HttpsError("failed-precondition", "Slot is in the past");

/ ✅ ADD THIS HERE
const minimumNoticeHours = 2;
const hoursBefore = (slot.startTime.toDate() - new Date()) / (1000 * 60 * 60);

if (hoursBefore < minimumNoticeHours) {
  console.log("❌ Slot too soon to book:", {
    slotStart: slot.startTime.toDate(),
    hoursBefore,
  });
  throw new HttpsError(
    "failed-precondition",
    "This slot is too soon to book."
  );
}
      }
// =================================================
// BUSINESS + STRIPE
// =================================================

const businessRef = db.collection("businesses").doc(businessId);
const businessSnap = await businessRef.get();

assert(businessSnap.exists, "not-found", "Business not found.");

const business = businessSnap.data() || {};
const stripeAccountId = business.stripeAccountId;

console.log("🏢 Business:", {
  businessId,
  stripeAccountId,
  stripeConnected: business.stripeConnected
});

assert(stripeAccountId, "failed-precondition", "Stripe not connected.");

const account = await stripe.accounts.retrieve(stripeAccountId);

console.log("💳 Stripe account status:", {
  charges_enabled: account.charges_enabled,
  payouts_enabled: account.payouts_enabled,
});

if (!account.charges_enabled) {
  console.log("❌ Stripe charges not enabled");
  throw new HttpsError(
    "failed-precondition",
    "Business cannot accept payments yet."
  );
}

// =================================================
// SERVICE + STAFF
// =================================================

const active = await staffIsActiveServer(businessId, staffId);
console.log("👤 Staff active:", active);

assert(active, "failed-precondition", "Staff inactive.");

const price = await fetchServicePricePence(businessId, serviceId);
console.log("💷 Price (pence):", price);

assert(price > 0, "failed-precondition", "Invalid service price.");

const serviceSnap = await businessRef.collection("services").doc(serviceId).get();
assert(serviceSnap.exists, "not-found", "Service not found.");

const service = serviceSnap.data() || {};
const serviceName = safeTrim(service.name) || "Service";
const serviceDurationMinutes = Number(service.durationMinutes || 0);

const staffSnap = await businessRef.collection("staff").doc(staffId).get();
assert(staffSnap.exists, "not-found", "Staff not found.");

const staff = staffSnap.data() || {};
const staffName = safeTrim(staff.name) || "Staff";

// =================================================
// 🔑 CREATE BOOKING ID FIRST (CRITICAL FIX)
// =================================================

const bookingRef = db.collection("bookings").doc();
const bookingId = bookingRef.id;

console.log("🧾 Creating booking:", bookingId);

// =================================================
// 🔒 TRANSACTION (LOCK SLOT + CREATE BOOKING)
// =================================================

await db.runTransaction(async (tx) => {

  const slotSnapTx = await tx.get(slotDocRef);
  assert(slotSnapTx.exists, "not-found", "Slot not found.");

  const slotTx = slotSnapTx.data();

  const isBookedTx =
    typeof slotTx.isBooked === "boolean"
      ? slotTx.isBooked
      : slotTx.isBooked === 1;

  assert(!isBookedTx, "failed-precondition", "Slot already booked");

  const now = Date.now();

  tx.update(slotDocRef, {
    lockedByBookingId: bookingId,
    lockExpiresAt: admin.firestore.Timestamp.fromMillis(now + 15 * 60 * 1000),
  });

  const bookingDay = new Date(slotTx.startTime.toDate());
  bookingDay.setHours(0, 0, 0, 0);

  tx.set(bookingRef, {
    bookingId,
    businessId,
    customerId,
    serviceId,
    serviceName,
    serviceDurationMinutes,
    staffId,
    staffName,
    customerName,
    customerAddress,
    price,
    status: "pending_payment",
    slotId,
    bookingDay: admin.firestore.Timestamp.fromDate(bookingDay),
    startDate: slotTx.startTime,
    endDate: slotTx.endTime,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    unreadForCustomer: 0,
    unreadForBusiness: 0,
  });
});

console.log("✅ Booking created, creating PaymentIntent...");

// =================================================
// 💳 PAYMENT INTENT (FIXED)
// =================================================

const paymentIntent = await stripe.paymentIntents.create({
  amount: price, // ✅ FIXED
  currency: "gbp",
  automatic_payment_methods: { enabled: true },

  metadata: {
    bookingId,   // ✅ CRITICAL FIX
    businessId,
    staffId,
    slotId,
    customerId
  },

  transfer_data: {
    destination: stripeAccountId,
  }
});

console.log("💰 PaymentIntent created:", paymentIntent.id);

// =================================================
// 🔄 UPDATE BOOKING (DO NOT OVERWRITE)
// =================================================

await bookingRef.update({
  paymentIntentId: paymentIntent.id,
});

console.log("🎉 SUCCESS");

return {
  clientSecret: paymentIntent.client_secret,
  bookingId: bookingId,
};
    } catch (error) {

      console.error("❌ createBookingPaymentIntent failed:", error);

      if (error instanceof HttpsError) throw error;

      throw new HttpsError(
        "internal",
        error?.message || "Failed to create booking."
      );
    }
  }
);
// =================================================
// DECREMENT SUBSCRIPTION
// =================================================

exports.decrementStaffSubscriptionQuantity = onCall(
  { region: "us-central1", secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => {
      // 🔒 AUTH CHECK
      assert(request.auth, "unauthenticated", "Login required.");

      const provider = request.auth.token.firebase?.sign_in_provider;

      // 🔒 BLOCK ANONYMOUS USERS
      if (provider === "anonymous") {
        throw new HttpsError(
          "failed-precondition",
          "Please log in to make a booking"
        );
      }

    const stripe = getStripe();
    const uid = request.auth.uid;
    const businessId = request.data?.businessId;

    assert(businessId, "invalid-argument", "Missing businessId.");

    const businessRef = db.collection("businesses").doc(businessId);
    const businessSnap = await businessRef.get();

    assert(businessSnap.exists, "not-found", "Business not found.");
    assert(
      businessSnap.data().ownerId === uid,
      "permission-denied",
      "Not owner."
    );

    await ensureEntitlementsDoc(businessId);

    const entRef = entitlementsRef(businessId);
    const entSnap = await entRef.get();
    const subscriptionId = entSnap.data()?.stripeSubscriptionId || null;

    if (!subscriptionId) {
      await syncExtraStaffSlots(businessId, 0);
      await syncSubscriptionStatus(businessId, "free");
      await clearPastDueTimestamp(businessId);
      await disableRestrictionMode(businessId);
      await applySeatEnforcement(businessId);
      return { success: true };
    }

    let sub;

    try {
      sub = await stripe.subscriptions.retrieve(subscriptionId);
    } catch (err) {
      console.error("Subscription retrieve failed", err);

      await syncExtraStaffSlots(businessId, 0);
      await syncSubscriptionStatus(businessId, "free");
      await clearPastDueTimestamp(businessId);
      await disableRestrictionMode(businessId);
      await entRef.set({ stripeSubscriptionId: null }, { merge: true });
      await applySeatEnforcement(businessId);

      return { success: true };
    }

    const item = sub.items?.data?.[0];
    assert(item, "failed-precondition", "Subscription item not found.");

    const newQty = Math.max(0, Number(item.quantity || 0) - 1);

    if (newQty === 0) {
      await stripe.subscriptions.cancel(subscriptionId);
      return { success: true };
    }

    await stripe.subscriptions.update(subscriptionId, {
      items: [{ id: item.id, quantity: newQty }],
      proration_behavior: "always_invoice",
    });

    return { success: true };
  }
);

// =================================================
// STRIPE WEBHOOK (CLEAN + PRODUCTION SAFE)
// =================================================

exports.stripeWebhook = onRequest(
  {
    region: "us-central1",
    secrets: ["STRIPE_SECRET_KEY", "STRIPE_WEBHOOK_SECRET"],
  },
  async (req, res) => {

    console.log("🔥 STRIPE WEBHOOK HIT");

    const stripe = getStripe();
    const sig = req.headers["stripe-signature"];
    const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET;

    if (!sig) return res.status(400).send("Missing stripe-signature.");
    if (!endpointSecret) return res.status(500).send("Missing webhook secret.");

    let event;

    try {
      event = stripe.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
      console.log("✅ Event:", event.type);
    } catch (err) {
      console.error("❌ Signature failed:", err.message);
      return res.status(400).send(`Webhook Error: ${err.message}`);
    }

    const processedRef = stripeEventRef(event.id);
    const processedSnap = await processedRef.get();

    if (processedSnap.exists) {
      console.log("↩️ Duplicate webhook ignored:", event.id);
      return res.status(200).json({ received: true, duplicate: true });
    }

    try {

      // ===============================
// ✅ PAYMENT SUCCESS
// ===============================
if (event.type === "payment_intent.succeeded") {

  const pi = event.data.object;

  const bookingId = pi.metadata?.bookingId;
  const slotId = pi.metadata?.slotId;
  const businessId = pi.metadata?.businessId;
  const staffId = pi.metadata?.staffId;

  console.log("💰 PAYMENT SUCCEEDED:", bookingId);

  // 🔴 HARD GUARD
  if (!bookingId || !businessId || !staffId || !slotId) {
    console.error("❌ Missing metadata on payment_intent:", pi.id, pi.metadata);
    return res.json({ received: true });
  }

  const bookingRef = db.collection("bookings").doc(bookingId);

  await db.runTransaction(async (tx) => {

    const bookingSnap = await tx.get(bookingRef);

    if (!bookingSnap.exists) {
      console.error("❌ Booking not found:", bookingId);
      return;
    }

    const booking = bookingSnap.data();

    // ✅ Prevent double processing (VERY important)
    if (booking.status === "confirmed") {
      console.log("↩️ Already confirmed, skipping:", bookingId);
      return;
    }

    console.log("✏️ Updating booking to confirmed:", bookingId);

    // ✅ Update booking FIRST (this is what your app is waiting for)
    tx.update(bookingRef, {
      status: "confirmed",
      confirmedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // ===============================
    // ✅ FIXED SLOT PATH (CRITICAL)
    // ===============================
    const slotRef = db
      .collection("businesses")
      .doc(businessId)
      .collection("staff")              // ✅ REQUIRED
      .doc(staffId)                    // ✅ REQUIRED
      .collection("availableSlots")
      .doc(slotId);

    console.log("🔒 Locking slot as booked:", slotId);

    tx.update(slotRef, {
      isBooked: true,
      lockExpiresAt: admin.firestore.FieldValue.delete(),
      lockedByBookingId: admin.firestore.FieldValue.delete()
    });

  });

  console.log("✅ BOOKING CONFIRMED:", bookingId);
}

      // ===============================
      // ❌ PAYMENT FAILED / CANCELED
      // ===============================
if (
  event.type === "payment_intent.payment_failed" ||
  event.type === "payment_intent.canceled"
) {

const pi = event.data.object;

const bookingId = pi.metadata?.bookingId;
const slotId = pi.metadata?.slotId;
const businessId = pi.metadata?.businessId;
const staffId = pi.metadata?.staffId;

if (!bookingId || !slotId || !businessId || !staffId) {
  console.error("❌ Missing metadata on failed payment", pi.id, pi.metadata);
  return res.json({ received: true });
}

const bookingRef = db.collection("bookings").doc(bookingId);

const slotRef = db
  .collection("businesses")
  .doc(businessId)
  .collection("staff")
  .doc(staffId)
  .collection("availableSlots")
  .doc(slotId);

  await db.runTransaction(async (tx) => {

    const bookingSnap = await tx.get(bookingRef);
    if (!bookingSnap.exists) return;

    const booking = bookingSnap.data();
    if (booking.status !== "pending_payment") return;

    tx.update(bookingRef, {
      status: "payment_failed",
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.update(slotRef, {
      isBooked: false,
      lockExpiresAt: admin.firestore.FieldValue.delete(),
      lockedByBookingId: admin.firestore.FieldValue.delete(),
    });
  });

  console.log("❌ Payment failed — booking released");
}

      // ===============================
      // 💳 SUBSCRIPTIONS
      // ===============================
      if (event.type === "invoice.paid") {
        const invoice = event.data.object;

        const businessId = await resolveBusinessIdFromCustomer(
          stripe,
          invoice.customer
        );

        if (businessId && invoice.subscription) {

          const sub = await stripe.subscriptions.retrieve(invoice.subscription);

          await entitlementsRef(businessId).set(
            { stripeSubscriptionId: sub.id },
            { merge: true }
          );

          const qty = sub.items?.data?.[0]?.quantity ?? 0;

          await syncExtraStaffSlots(businessId, qty);
          await syncSubscriptionStatus(businessId, sub.status);
          await syncCurrentPeriodEnd(businessId, sub.current_period_end);

          await clearPastDueTimestamp(businessId);
          await evaluateRestrictionState(businessId);
          await applySeatEnforcement(businessId);
        }
      }

      if (event.type === "customer.subscription.deleted") {
        const sub = event.data.object;

        const businessId = await resolveBusinessIdFromCustomer(
          stripe,
          sub.customer
        );

        if (businessId) {
          await entitlementsRef(businessId).set(
            { stripeSubscriptionId: null },
            { merge: true }
          );

          await syncExtraStaffSlots(businessId, 0);
          await syncSubscriptionStatus(businessId, "free");
          await clearPastDueTimestamp(businessId);

          await evaluateRestrictionState(businessId);
          await applySeatEnforcement(businessId);
        }
      }

      // ✅ MARK PROCESSED
      await processedRef.set({
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });

      console.log("ℹ️ Event handled:", event.type);

      return res.status(200).json({ received: true });

    } catch (err) {
      console.error("❌ Webhook error:", err);
      return res.status(500).send("Webhook failed");
    }
  }
);
// =================================================
// CLEAN UP STALE PENDING BOOKINGS
// =================================================

exports.cleanupPendingBookings = onSchedule(
  { schedule: "every 5 minutes", region: "us-central1" },
  async () => {
    const cutoff = new Date(Date.now() - 15 * 60 * 1000);

    const snap = await db
      .collection("bookings")
      .where("status", "==", "pending_payment")
      .where("createdAt", "<", cutoff)
      .get();

    if (snap.empty) return;

    const batch = db.batch();

    for (const doc of snap.docs) {
      const booking = doc.data();

      batch.update(doc.ref, {
        status: "cancelled_by_system",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (booking.businessId && booking.staffId && booking.slotId) {
        const sRef = slotRef(booking.businessId, booking.staffId, booking.slotId);
        batch.update(sRef, {
          lockedByBookingId: null,
          lockExpiresAt: null,
        });
      }
    }

    await batch.commit();

    logger.info("Cancelled stale pending bookings + unlocked slots", {
      count: snap.size,
    });
  }
);
// =================================================
// DAILY SAFETY SWEEP (CRON) – catches missed webhooks
// =================================================

exports.dailyRestrictionSweep = onSchedule(
  { schedule: "every 24 hours", region: "us-central1" },
  async () => {
    const snap = await db
      .collectionGroup("entitlements")
      .where("stripeStatus", "in", [
        "past_due",
        "canceled",
        "unpaid",
        "incomplete",
        "incomplete_expired",
      ])
      .get();

    let count = 0;

    for (const doc of snap.docs) {
      const businessId = doc.ref.parent.parent.id;
      await evaluateRestrictionState(businessId);
      await applySeatEnforcement(businessId);
      count += 1;
    }

    logger.info("Daily restriction sweep completed", { businessesChecked: count });
  }
);

// =================================================
// STRIPE CONNECT / PORTAL
// =================================================

exports.createConnectedAccount = onCall(
  { region: "us-central1", secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => {

    assert(request.auth, "unauthenticated", "Login required.");

    const stripe = getStripe();
    const uid = request.auth.uid;

    const snap = await db
      .collection("businesses")
      .where("ownerId", "==", uid)
      .limit(1)
      .get();

    assert(!snap.empty, "not-found", "Business not found.");

    const businessDoc = snap.docs[0];
    let stripeAccountId = businessDoc.data().stripeAccountId || null;

    // ✅ CREATE ACCOUNT IF NOT EXISTS
    if (!stripeAccountId) {

      const account = await stripe.accounts.create({
        type: "express",
        country: "GB",
        email: request.auth.token.email || undefined,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        metadata: {
          businessId: businessDoc.id,
          uid,
        },
      });

      stripeAccountId = account.id;

      // ✅ SAVE ACCOUNT ID ONLY (NOT CONNECTED YET)
      await businessDoc.ref.set({
        stripeAccountId,
        stripeConnected: false
      }, { merge: true });
    }

    // ✅ ALWAYS RETURN ACCOUNT ID
    return { accountId: stripeAccountId };
  }
);
exports.refreshStripeConnectionStatus = onCall(
  { region: "us-central1", secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => {

    assert(request.auth, "unauthenticated", "Login required.");

    const stripe = getStripe();
    const uid = request.auth.uid;

    const snap = await db
      .collection("businesses")
      .where("ownerId", "==", uid)
      .limit(1)
      .get();

    assert(!snap.empty, "not-found", "Business not found.");

    const businessDoc = snap.docs[0];
    const stripeAccountId = businessDoc.data().stripeAccountId;

    assert(stripeAccountId, "failed-precondition", "Stripe not set up.");

    const account = await stripe.accounts.retrieve(stripeAccountId);

    const isConnected = account.charges_enabled && account.payouts_enabled;

    await businessDoc.ref.set({
      stripeConnected: isConnected
    }, { merge: true });

    return { connected: isConnected };
  }
);

exports.createAccountLink = onCall(
  { region: "us-central1", secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => {
    assert(request.auth, "unauthenticated", "Login required.");

    const stripe = getStripe();
    const uid = request.auth.uid;

    let stripeAccountId = safeTrim(request.data?.accountId);

    if (!stripeAccountId) {
      const snap = await db
        .collection("businesses")
        .where("ownerId", "==", uid)
        .limit(1)
        .get();

      assert(!snap.empty, "not-found", "Business not found.");

      const businessDoc = snap.docs[0];
      stripeAccountId = businessDoc.data().stripeAccountId || null;
    }

    assert(stripeAccountId, "failed-precondition", "Stripe account not created.");

    const link = await stripe.accountLinks.create({
      account: stripeAccountId,
      refresh_url: "https://locallinkapp.co.uk/stripe-refresh",
      return_url: "https://locallinkapp.co.uk/stripe-return",
      type: "account_onboarding",
    });

    return { url: link.url };
  }
);

exports.createStripePortalLink = onCall(
  { region: "us-central1", secrets: ["STRIPE_SECRET_KEY"] },
  async (request) => {
    assert(request.auth, "unauthenticated", "Login required.");

    const stripe = getStripe();
    const uid = request.auth.uid;

    const snap = await db
      .collection("businesses")
      .where("ownerId", "==", uid)
      .limit(1)
      .get();

    assert(!snap.empty, "not-found", "Business not found.");

    const businessRef = snap.docs[0].ref;

    await ensureEntitlementsDoc(businessRef.id);

    const entSnap = await businessRef
      .collection("entitlements")
      .doc("default")
      .get();

    let stripeCustomerId = entSnap.data()?.stripeCustomerId || null;

    if (!stripeCustomerId) {
      const customer = await stripe.customers.create({
        metadata: {
          businessId: businessRef.id,
          uid,
        },
      });

      stripeCustomerId = customer.id;

      await businessRef
        .collection("entitlements")
        .doc("default")
        .set({ stripeCustomerId }, { merge: true });
    }

    console.log("Stripe customer ID:", stripeCustomerId);

    const session = await stripe.billingPortal.sessions.create({
      customer: stripeCustomerId,
      return_url: "https://locallinkapp.co.uk/billing-return",
    });

    return { url: session.url };
  }
);
// =================================================
// APPLE STAFF SEAT PURCHASE
// =================================================

exports.verifyAppleSeatPurchase = onCall(
  { region: "us-central1" },
  async (request) => {

    const uid = request.auth?.uid;
    const businessId = request.data?.businessId;
    const productId = request.data?.productId;

    assert(uid, "unauthenticated", "Login required.");
    assert(businessId, "invalid-argument", "Missing businessId.");
    assert(productId, "invalid-argument", "Missing productId.");

    const businessRef = db.collection("businesses").doc(businessId);
    const businessSnap = await businessRef.get();

    assert(businessSnap.exists, "not-found", "Business not found.");
    assert(
      businessSnap.data().ownerId === uid,
      "permission-denied",
      "Not owner."
    );

    await ensureEntitlementsDoc(businessId);

    const entRef = entitlementsRef(businessId);

    // 🧠 PLAN SIZE
    let planSeats = 0;

    if (productId === "locallink.staff.1") planSeats = 1;
    if (productId === "locallink.staff.3") planSeats = 3;
    if (productId === "locallink.staff.5") planSeats = 5;

    assert(planSeats > 0, "invalid-argument", "Invalid productId.");

    // 💰 APPLY
    await entRef.set(
      {
        extraStaffSlots: planSeats,
        restrictionMode: false,
        stripeStatus: "overridden_by_apple",
        billingSource: "apple"
      },
      { merge: true }
    );

    await applySeatEnforcement(businessId);

    return { success: true };
  }
);
   