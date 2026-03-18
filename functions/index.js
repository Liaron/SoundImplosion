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

function groupInviteNotificationId(groupId) {
  return `group_invite_${groupId}`;
}

const GROUP_INVITE_EXPIRY_MS = 7 * 24 * 60 * 60 * 1000;

function nowPlusInviteExpiry() {
  return Date.now() + GROUP_INVITE_EXPIRY_MS;
}

function groupActivityEntry(type, message) {
  return {
    type,
    message,
    timestamp: admin.database.ServerValue.TIMESTAMP,
  };
}

function groupInviteHistoryEntry(status, username, actorUsername) {
  return {
    status,
    username,
    actor_username: actorUsername,
    timestamp: admin.database.ServerValue.TIMESTAMP,
  };
}

function extractIds(rawValue) {
  if (!rawValue) {
    return [];
  }

  if (Array.isArray(rawValue)) {
    return rawValue
        .map((value, index) => value != null ? String(index) : "")
        .filter(Boolean);
  }

  if (typeof rawValue === "object") {
    return Object.keys(rawValue);
  }

  return [];
}

function parseIndexedUserIds(rawValue) {
  if (!rawValue) {
    return [];
  }

  if (typeof rawValue === "string") {
    return rawValue.trim() ? [rawValue.trim()] : [];
  }

  if (typeof rawValue !== "object" || Array.isArray(rawValue)) {
    return [];
  }

  if (
    Object.prototype.hasOwnProperty.call(rawValue, "uid") ||
    Object.prototype.hasOwnProperty.call(rawValue, "nickname") ||
    Object.prototype.hasOwnProperty.call(rawValue, "username")
  ) {
    const uid = String(rawValue.uid || "").trim();
    return uid ? [uid] : [];
  }

  return Object.keys(rawValue);
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

function notificationCategory(type) {
  switch (type) {
    case "booking_created":
    case "booking_confirmed":
    case "booking_cancelled":
      return "booking";
    case "jam_approved":
    case "jam_rejected":
      return "jam";
    case "group_invite":
    case "group_invite_accepted":
    case "group_invite_rejected":
      return "group";
    default:
      return "system";
  }
}

async function sendPushToUser(uid, notificationId, payload) {
  const preferences = await getValue(`users/${uid}/preferenze/notifications`);
  if (preferences && preferences.system_enabled === false) {
    return;
  }

  const category = notificationCategory(payload && payload.type);
  if (
    (category === "booking" && preferences && preferences.booking_enabled === false) ||
    (category === "jam" && preferences && preferences.jam_enabled === false) ||
    (category === "group" && preferences && preferences.group_enabled === false) ||
    (category === "system" && preferences && preferences.system_category_enabled === false)
  ) {
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
      group_id: (payload && payload.group_id ? String(payload.group_id) : ""),
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
    [`/user_public_profiles/${uid}`]: null,
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

exports.inviteUserToGroup = functions.region("us-central1").https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Utente non autenticato.",
    );
  }

  const groupId = String((data && data.groupId) || "").trim();
  const nickname = String((data && data.nickname) || "").trim();
  if (!groupId || !nickname) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "groupId e username sono obbligatori.",
    );
  }

  const callerUid = context.auth.uid;
  const group = await getValue(`groups_info/${groupId}`);
  if (!group || typeof group !== "object") {
    throw new functions.https.HttpsError("not-found", "Gruppo non trovato.");
  }

  const callerData = await getValue(`users/${callerUid}`);
  const isAdmin = callerData && typeof callerData === "object" && callerData.role === "admin";
  if (group.owner_id !== callerUid && !isAdmin) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Solo il proprietario del gruppo puo invitare membri.",
    );
  }

  const normalizedNickname = normalizeNickname(nickname);
  const rawIndexEntry = await getValue(`user_search_index/${normalizedNickname}`);
  const candidateUids = parseIndexedUserIds(rawIndexEntry);
  if (!candidateUids.length) {
    throw new functions.https.HttpsError(
        "not-found",
        "Nessun utente trovato con questo username.",
    );
  }

  const targetUid = candidateUids[0];
  if (!targetUid) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Utente non valido.",
    );
  }

  const members = new Set([
    ...extractIds(group.members),
    ...extractIds(group.member_nicknames),
  ]);
  if (members.has(targetUid)) {
    throw new functions.https.HttpsError(
        "already-exists",
        "Questo utente e gia nel gruppo.",
    );
  }

  const pendingInvites = new Set(extractIds(group.pending_invites));
  if (pendingInvites.has(targetUid)) {
    throw new functions.https.HttpsError(
        "already-exists",
        "Questo utente ha gia un invito pendente.",
    );
  }

  const targetUser = await getValue(`users/${targetUid}`);
  if (!targetUser || typeof targetUser !== "object") {
    throw new functions.https.HttpsError(
        "not-found",
        "Utente non trovato.",
    );
  }

  const inviterUsername =
      String(callerData?.username || callerData?.nickname || callerUid);
  const invitedUsername =
      String(targetUser.username || targetUser.nickname || nickname);
  const groupName = String(group.name || "Gruppo");
  const notificationId = groupInviteNotificationId(groupId);
  const expiresAt = nowPlusInviteExpiry();
  const activityRef = db.ref(`groups_info/${groupId}/activity`).push();
  const historyRef = db.ref(`groups_info/${groupId}/invite_history`).push();

  await db.ref().update({
    [`/groups_info/${groupId}/pending_invites/${targetUid}`]: {
      username: invitedUsername,
      inviter_uid: callerUid,
      inviter_username: inviterUsername,
      invited_at: admin.database.ServerValue.TIMESTAMP,
      expires_at: expiresAt,
    },
    [`/group_invites/${targetUid}/${groupId}`]: {
      group_id: groupId,
      group_name: groupName,
      inviter_uid: callerUid,
      inviter_username: inviterUsername,
      invited_username: invitedUsername,
      status: "pending",
      timestamp: admin.database.ServerValue.TIMESTAMP,
      expires_at: expiresAt,
    },
    [`/groups_info/${groupId}/invite_history/${historyRef.key}`]:
      groupInviteHistoryEntry("pending", invitedUsername, inviterUsername),
    [`/groups_info/${groupId}/activity/${activityRef.key}`]:
      groupActivityEntry(
          "invite_sent",
          `${inviterUsername} ha invitato ${invitedUsername} nel gruppo.`,
      ),
    [`/user_notifications/${targetUid}/${notificationId}`]: {
      type: "group_invite",
      group_id: groupId,
      group_name: groupName,
      inviter_uid: callerUid,
      inviter_username: inviterUsername,
      invited_username: invitedUsername,
      invite_status: "pending",
      timestamp: admin.database.ServerValue.TIMESTAMP,
      expires_at: expiresAt,
      creator_id: callerUid,
      read: false,
    },
  });

  return {ok: true};
});

exports.acceptGroupInvite = functions.region("us-central1").https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Utente non autenticato.",
    );
  }

  const uid = context.auth.uid;
  const groupId = String((data && data.groupId) || "").trim();
  if (!groupId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "groupId obbligatorio.",
    );
  }

  const invite = await getValue(`group_invites/${uid}/${groupId}`);
  if (!invite || typeof invite !== "object" || invite.status !== "pending") {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Invito non disponibile.",
    );
  }

  const group = await getValue(`groups_info/${groupId}`);
  if (!group || typeof group !== "object") {
    await db.ref().update({
      [`/group_invites/${uid}/${groupId}`]: null,
      [`/user_notifications/${uid}/${groupInviteNotificationId(groupId)}`]: null,
    });
    throw new functions.https.HttpsError("not-found", "Gruppo non trovato.");
  }

  const userData = await getValue(`users/${uid}`);
  const username = String(
      invite.invited_username ||
      userData?.username ||
      userData?.nickname ||
      uid,
  );
  const ownerId = String(group.owner_id || "");
  const notificationId = groupInviteNotificationId(groupId);
  const expiresAt = Number(invite.expires_at || 0);
  if (expiresAt && expiresAt < Date.now()) {
    const expiredHistoryRef = db.ref(`groups_info/${groupId}/invite_history`).push();
    const expiredActivityRef = db.ref(`groups_info/${groupId}/activity`).push();
    await db.ref().update({
      [`/groups_info/${groupId}/pending_invites/${uid}`]: null,
      [`/group_invites/${uid}/${groupId}/status`]: "expired",
      [`/user_notifications/${uid}/${notificationId}/invite_status`]: "expired",
      [`/user_notifications/${uid}/${notificationId}/read`]: true,
      [`/user_notifications/${uid}/${notificationId}/responded_at`]:
        admin.database.ServerValue.TIMESTAMP,
      [`/groups_info/${groupId}/invite_history/${expiredHistoryRef.key}`]:
        groupInviteHistoryEntry("expired", username, username),
      [`/groups_info/${groupId}/activity/${expiredActivityRef.key}`]:
        groupActivityEntry("invite_expired", `L'invito per ${username} e scaduto.`),
    });
    throw new functions.https.HttpsError(
        "deadline-exceeded",
        "Questo invito e scaduto.",
    );
  }
  const acceptedHistoryRef = db.ref(`groups_info/${groupId}/invite_history`).push();
  const acceptedActivityRef = db.ref(`groups_info/${groupId}/activity`).push();

  const updates = {
    [`/groups_info/${groupId}/members/${uid}`]: true,
    [`/groups_info/${groupId}/member_nicknames/${uid}`]: username,
    [`/groups_info/${groupId}/pending_invites/${uid}`]: null,
    [`/users/${uid}/gruppi/${groupId}`]: true,
    [`/group_invites/${uid}/${groupId}`]: null,
    [`/user_notifications/${uid}/${notificationId}/invite_status`]: "accepted",
    [`/user_notifications/${uid}/${notificationId}/read`]: true,
    [`/user_notifications/${uid}/${notificationId}/responded_at`]:
      admin.database.ServerValue.TIMESTAMP,
    [`/groups_info/${groupId}/invite_history/${acceptedHistoryRef.key}`]:
      groupInviteHistoryEntry("accepted", username, username),
    [`/groups_info/${groupId}/activity/${acceptedActivityRef.key}`]:
      groupActivityEntry(
          "invite_accepted",
          `${username} ha accettato l'invito al gruppo.`,
      ),
  };

  if (ownerId && ownerId !== uid) {
    updates[`/user_notifications/${ownerId}/group_invite_accepted_${groupId}_${uid}`] = {
      type: "group_invite_accepted",
      group_id: groupId,
      group_name: String(group.name || ""),
      user_id: uid,
      username,
      timestamp: admin.database.ServerValue.TIMESTAMP,
      creator_id: uid,
      read: false,
    };
  }

  await db.ref().update(updates);
  return {ok: true};
});

exports.rejectGroupInvite = functions.region("us-central1").https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Utente non autenticato.",
    );
  }

  const uid = context.auth.uid;
  const groupId = String((data && data.groupId) || "").trim();
  if (!groupId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "groupId obbligatorio.",
    );
  }

  const invite = await getValue(`group_invites/${uid}/${groupId}`);
  if (!invite || typeof invite !== "object" || invite.status !== "pending") {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Invito non disponibile.",
    );
  }

  const userData = await getValue(`users/${uid}`);
  const username = String(
      invite.invited_username ||
      userData?.username ||
      userData?.nickname ||
      uid,
  );
  const ownerId = String(invite.inviter_uid || "");
  const notificationId = groupInviteNotificationId(groupId);
  const expiresAt = Number(invite.expires_at || 0);
  if (expiresAt && expiresAt < Date.now()) {
    const expiredHistoryRef = db.ref(`groups_info/${groupId}/invite_history`).push();
    const expiredActivityRef = db.ref(`groups_info/${groupId}/activity`).push();
    await db.ref().update({
      [`/groups_info/${groupId}/pending_invites/${uid}`]: null,
      [`/group_invites/${uid}/${groupId}/status`]: "expired",
      [`/user_notifications/${uid}/${notificationId}/invite_status`]: "expired",
      [`/user_notifications/${uid}/${notificationId}/read`]: true,
      [`/user_notifications/${uid}/${notificationId}/responded_at`]:
        admin.database.ServerValue.TIMESTAMP,
      [`/groups_info/${groupId}/invite_history/${expiredHistoryRef.key}`]:
        groupInviteHistoryEntry("expired", username, username),
      [`/groups_info/${groupId}/activity/${expiredActivityRef.key}`]:
        groupActivityEntry("invite_expired", `L'invito per ${username} e scaduto.`),
    });
    throw new functions.https.HttpsError(
        "deadline-exceeded",
        "Questo invito e scaduto.",
    );
  }
  const rejectedHistoryRef = db.ref(`groups_info/${groupId}/invite_history`).push();
  const rejectedActivityRef = db.ref(`groups_info/${groupId}/activity`).push();

  const updates = {
    [`/groups_info/${groupId}/pending_invites/${uid}`]: null,
    [`/group_invites/${uid}/${groupId}`]: null,
    [`/user_notifications/${uid}/${notificationId}/invite_status`]: "rejected",
    [`/user_notifications/${uid}/${notificationId}/read`]: true,
    [`/user_notifications/${uid}/${notificationId}/responded_at`]:
      admin.database.ServerValue.TIMESTAMP,
    [`/groups_info/${groupId}/invite_history/${rejectedHistoryRef.key}`]:
      groupInviteHistoryEntry("rejected", username, username),
    [`/groups_info/${groupId}/activity/${rejectedActivityRef.key}`]:
      groupActivityEntry(
          "invite_rejected",
          `${username} ha rifiutato l'invito al gruppo.`,
      ),
  };

  if (ownerId && ownerId !== uid) {
    updates[`/user_notifications/${ownerId}/group_invite_rejected_${groupId}_${uid}`] = {
      type: "group_invite_rejected",
      group_id: groupId,
      group_name: String(invite.group_name || ""),
      user_id: uid,
      username,
      timestamp: admin.database.ServerValue.TIMESTAMP,
      creator_id: uid,
      read: false,
    };
  }

  await db.ref().update(updates);
  return {ok: true};
});

exports.cleanupPastSlots = functions.region("us-central1").https.onCall(async (_data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Utente non autenticato.",
    );
  }

  const slots = await getValue("slots");
  if (!slots || typeof slots !== "object") {
    return {deletedCount: 0};
  }

  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const updates = {};
  let deletedCount = 0;

  for (const dateKey of Object.keys(slots)) {
    const parsedDate = new Date(`${dateKey}T00:00:00`);
    if (Number.isNaN(parsedDate.getTime())) {
      continue;
    }

    if (parsedDate < today) {
      updates[`/slots/${dateKey}`] = null;
      deletedCount += 1;
    }
  }

  if (deletedCount > 0) {
    await db.ref().update(updates);
  }

  return {deletedCount};
});
