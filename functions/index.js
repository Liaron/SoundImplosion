const admin = require("firebase-admin");
const functions = require("firebase-functions/v1");

admin.initializeApp();

const db = admin.database();

function normalizeNickname(value) {
  return (value || "").toString().trim().toLowerCase();
}

function normalizeEmail(value) {
  return (value || "").toString().trim().toLowerCase();
}

function emailKey(value) {
  return normalizeEmail(value).replace(/\./g, ",");
}

function buildNotificationContent(payload) {
  const type = (payload && payload.type) || "generic";
  const date = (payload && payload.data) || "";
  const start = (payload && payload.ora_inizio) || "";
  const end = (payload && payload.ora_fine) || "";

  switch (type) {
    case "booking_created":
      return {
        title: "Nuova prenotazione di gruppo",
        body: `Nuova prenotazione per ${date} ${start}${end ? ` - ${end}` : ""}`.trim(),
      };
    case "booking_confirmed":
      return {
        title: "Prenotazione confermata",
        body: `La tua prenotazione del ${date} alle ${start} e stata confermata.`,
      };
    case "booking_cancelled":
      return {
        title: "Prenotazione annullata",
        body: `La tua prenotazione del ${date} alle ${start} e stata annullata.`,
      };
    case "jam_approved":
      return {
        title: "Jam approvata",
        body: `La tua jam del ${date} alle ${start} e ora pubblicata.`,
      };
    case "jam_rejected":
      return {
        title: "Jam rifiutata",
        body: `La tua jam del ${date} alle ${start} e stata annullata.`,
      };
    default:
      return {
        title: "Nuova notifica",
        body: (payload && payload.message) || "Hai un nuovo aggiornamento.",
      };
  }
}

async function sendPushToUser(uid, notificationId, payload) {
  const preferences = await getValue(`users/${uid}/preferenze/notifications`);
  if (preferences && preferences.system_enabled === false) {
    return;
  }

  const devices = await getValue(`user_devices/${uid}`);
  if (!devices || typeof devices !== "object") {
    return;
  }

  const tokens = Object.values(devices)
      .filter((value) => value && typeof value === "object" && value.token)
      .map((value) => value.token);

  if (!tokens.length) {
    return;
  }

  const content = buildNotificationContent(payload);
  const response = await admin.messaging().sendEachForMulticast({
    tokens,
    notification: {
      title: content.title,
      body: content.body,
    },
    data: {
      notification_id: notificationId,
      type: (payload && payload.type ? String(payload.type) : "generic"),
    },
    android: {
      priority: "high",
      notification: {
        channelId: "soundimplosion_notifications",
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
        },
      },
    },
  });

  const invalidCodes = new Set([
    "messaging/invalid-registration-token",
    "messaging/registration-token-not-registered",
  ]);

  const cleanup = {};
  response.responses.forEach((result, index) => {
    if (!result.success && result.error && invalidCodes.has(result.error.code)) {
      const token = tokens[index];
      for (const [tokenKey, value] of Object.entries(devices)) {
        if (value && typeof value === "object" && value.token === token) {
          cleanup[`/user_devices/${uid}/${tokenKey}`] = null;
        }
      }
    }
  });

  if (Object.keys(cleanup).length) {
    await db.ref().update(cleanup);
  }
}

async function getValue(path) {
  const snapshot = await db.ref(path).get();
  return snapshot.exists() ? snapshot.val() : null;
}

async function removeFeedEntriesByJamId(jamId, updates) {
  const feed = await getValue("feed");
  if (!feed || typeof feed !== "object") {
    return;
  }

  for (const [feedId, rawItem] of Object.entries(feed)) {
    if (!rawItem || typeof rawItem !== "object") {
      continue;
    }
    if (rawItem.jam_id === jamId) {
      updates[`/feed/${feedId}`] = null;
    }
  }
}

async function removeSlotsByBookingId(dateStr, bookingId, updates) {
  const slots = await getValue(`slots/${dateStr}`);
  if (!slots || typeof slots !== "object") {
    return;
  }

  for (const [slotKey, rawSlot] of Object.entries(slots)) {
    if (!rawSlot || typeof rawSlot !== "object") {
      continue;
    }
    if (rawSlot.booking_id === bookingId) {
      updates[`/slots/${dateStr}/${slotKey}/status`] = "libero";
      updates[`/slots/${dateStr}/${slotKey}/booked_by`] = null;
      updates[`/slots/${dateStr}/${slotKey}/booking_id`] = null;
      updates[`/slots/${dateStr}/${slotKey}/is_jam`] = null;
    }
  }
}

async function buildBookingDeletionUpdates(bookingId, bookingData) {
  const updates = {};
  const bookingOwnerId = bookingData.user_id || "";
  const bookingDate = bookingData.data || "";
  const groupId = bookingData.group_id || "";

  if (!bookingOwnerId || !bookingDate) {
    return updates;
  }

  updates[`/bookings/${bookingId}`] = null;
  updates[`/user_bookings/${bookingOwnerId}/${bookingId}`] = null;

  if (groupId) {
    updates[`/group_bookings/${groupId}/${bookingId}`] = null;
    updates[`/group_booking_notifications/${groupId}/${bookingId}`] = null;
  }

  await removeSlotsByBookingId(bookingDate, bookingId, updates);
  return updates;
}

async function buildJamDeletionUpdates(jamId, jamData) {
  const updates = {};
  const dateStr = jamData.data || "";
  const participants = jamData.participants;

  if (dateStr) {
    await removeSlotsByBookingId(dateStr, jamId, updates);
  }

  await removeFeedEntriesByJamId(jamId, updates);

  if (participants && typeof participants === "object") {
    for (const participantId of Object.keys(participants)) {
      updates[`/user_joined_jams/${participantId}/${jamId}`] = null;
    }
  }

  updates[`/jams/${jamId}`] = null;
  return updates;
}

async function cleanupUserData(uid) {
  const updates = {
    [`/users/${uid}`]: null,
    [`/user_bookings/${uid}`]: null,
    [`/user_joined_jams/${uid}`]: null,
    [`/user_notifications/${uid}`]: null,
  };

  const userData = await getValue(`users/${uid}`);
  const nickname = userData && typeof userData === "object" ? userData.nickname : "";
  const email = userData && typeof userData === "object" ? userData.email : "";
  const normalizedNickname = normalizeNickname(nickname);
  const normalizedEmail = normalizeEmail(email);

  if (normalizedNickname) {
    updates[`/user_search_index/${normalizedNickname}/${uid}`] = null;
    updates[`/nickname_claims/${normalizedNickname}`] = null;
  }

  if (normalizedEmail) {
    const encodedEmail = emailKey(normalizedEmail);
    updates[`/user_email_index/${encodedEmail}/${uid}`] = null;
    updates[`/email_claims/${encodedEmail}`] = null;
  }

  const groupsInfo = await getValue("groups_info");
  if (groupsInfo && typeof groupsInfo === "object") {
    for (const [groupId, rawGroup] of Object.entries(groupsInfo)) {
      if (!rawGroup || typeof rawGroup !== "object") {
        continue;
      }

      if (rawGroup.owner_id === uid) {
        updates[`/groups_info/${groupId}`] = null;
        updates[`/group_bookings/${groupId}`] = null;
        updates[`/group_booking_notifications/${groupId}`] = null;

        const members = rawGroup.members;
        if (members && typeof members === "object") {
          for (const memberId of Object.keys(members)) {
            updates[`/users/${memberId}/gruppi/${groupId}`] = null;
          }
        }
        continue;
      }

      if (rawGroup.members && typeof rawGroup.members === "object" && rawGroup.members[uid] != null) {
        updates[`/groups_info/${groupId}/members/${uid}`] = null;
        updates[`/groups_info/${groupId}/member_nicknames/${uid}`] = null;
        updates[`/users/${uid}/gruppi/${groupId}`] = null;
      }
    }
  }

  const bookings = await getValue("bookings");
  if (bookings && typeof bookings === "object") {
    for (const [bookingId, rawBooking] of Object.entries(bookings)) {
      if (!rawBooking || typeof rawBooking !== "object") {
        continue;
      }
      if (rawBooking.user_id === uid) {
        Object.assign(updates, await buildBookingDeletionUpdates(bookingId, rawBooking));
      }
    }
  }

  const jams = await getValue("jams");
  if (jams && typeof jams === "object") {
    for (const [jamId, rawJam] of Object.entries(jams)) {
      if (!rawJam || typeof rawJam !== "object") {
        continue;
      }

      if (rawJam.creator_id === uid) {
        Object.assign(updates, await buildJamDeletionUpdates(jamId, rawJam));
        continue;
      }

      if (rawJam.participants && typeof rawJam.participants === "object" && rawJam.participants[uid] != null) {
        updates[`/jams/${jamId}/participants/${uid}`] = null;
        updates[`/user_joined_jams/${uid}/${jamId}`] = null;
      }
    }
  }

  await db.ref().update(updates);
}

exports.cleanupDeletedUserData = functions.auth.user().onDelete(async (user) => {
  await cleanupUserData(user.uid);
});

exports.pushUserNotification = functions.database
    .ref("/user_notifications/{uid}/{notificationId}")
    .onCreate(async (snapshot, context) => {
      const payload = snapshot.val();
      if (!payload || typeof payload !== "object") {
        return null;
      }

      await sendPushToUser(
          context.params.uid,
          context.params.notificationId,
          payload,
      );
      return null;
    });
