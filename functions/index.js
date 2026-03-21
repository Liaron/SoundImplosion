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
        .map((value) => {
          if (value == null) {
            return "";
          }
          if (typeof value === "string" || typeof value === "number") {
            return String(value).trim();
          }
          if (typeof value === "object") {
            const uid = String(value.uid || value.id || "").trim();
            return uid;
          }
          return "";
        })
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

function parseCount(value) {
  const parsed = Number.parseInt(String(value || 0), 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

function buildNotificationContent(payload) {
  const type = (payload && payload.type) || "generic";
  const date = (payload && payload.data) || "";
  const start = (payload && payload.ora_inizio) || "";
  const end = (payload && payload.ora_fine) || "";
  const username = (payload && payload.username) || "Un utente";
  const jamTitle = payload && payload.titolo ? String(payload.titolo).trim() : "";
  const jamTitleText = jamTitle ? ` \"${jamTitle}\" ` : " ";

  switch (type) {
    case "booking_created":
      return {
        title: "Nuova prenotazione di gruppo",
        body: `Nuova prenotazione per ${date} ${start}${end ? ` - ${end}` : ""}`.trim(),
      };
    case "group_booking_modified":
      return {
        title: "Prenotazione di gruppo modificata",
        body: `${username} ha modificato la prenotazione del ${date} alle ${start}.`,
      };
    case "group_booking_confirmed":
      return {
        title: "Prenotazione di gruppo confermata",
        body: `La prenotazione di gruppo del ${date} alle ${start} e stata confermata.`,
      };
    case "group_booking_cancelled":
      return {
        title: "Prenotazione di gruppo annullata",
        body: `La prenotazione di gruppo del ${date} alle ${start} e stata annullata.`,
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
    case "group_jam_created":
      return {
        title: "Nuova jam di gruppo",
        body: `${username} ha creato la jam${jamTitleText}per il ${date} alle ${start}.`,
      };
    case "group_jam_modified":
      return {
        title: "Jam di gruppo modificata",
        body: `${username} ha modificato la jam${jamTitleText}del ${date} alle ${start}.`,
      };
    case "group_jam_approved":
      return {
        title: "Jam di gruppo approvata",
        body: `La jam di gruppo${jamTitleText}del ${date} alle ${start} e ora pubblicata.`,
      };
    case "group_jam_rejected":
      return {
        title: "Jam di gruppo annullata",
        body: `La jam di gruppo${jamTitleText}del ${date} alle ${start} e stata annullata.`,
      };
    case "admin_booking_created":
      return {
        title: "Nuova richiesta di prenotazione",
        body: `${username} ha richiesto una prenotazione per il ${date} alle ${start}.`,
      };
    case "admin_booking_modified":
      return {
        title: "Prenotazione modificata",
        body: `${username} ha modificato la prenotazione del ${date} alle ${start}.`,
      };
    case "admin_booking_cancelled":
      return {
        title: "Prenotazione annullata",
        body: `${username} ha annullato la prenotazione del ${date} alle ${start}.`,
      };
    case "admin_booking_update_proposed":
      return {
        title: "Proposta di modifica inviata",
        body: `Hai inviato una proposta di modifica per la prenotazione del ${date} alle ${start}.`,
      };
    case "admin_booking_update_accepted":
      return {
        title: "Proposta prenotazione accettata",
        body: `${username} ha accettato la proposta di modifica per la prenotazione del ${date} alle ${start}.`,
      };
    case "admin_booking_update_rejected":
      return {
        title: "Proposta prenotazione rifiutata",
        body: `${username} ha rifiutato la proposta di modifica per la prenotazione del ${date} alle ${start}.`,
      };
    case "booking_update_proposal":
      return {
        title: "Proposta modifica prenotazione",
        body: `${username} propone di modificare la tua prenotazione del ${date} alle ${start}.`,
      };
    case "admin_jam_created":
      return {
        title: "Nuova richiesta di Jam Session",
        body: `${username} ha richiesto una Jam Session per il ${date} alle ${start}.`,
      };
    case "admin_jam_modified":
      return {
        title: "Jam Session modificata",
        body: `${username} ha modificato la Jam Session del ${date} alle ${start}.`,
      };
    case "admin_jam_cancelled":
      return {
        title: "Jam Session annullata",
        body: `${username} ha annullato la Jam Session del ${date} alle ${start}.`,
      };
    case "admin_jam_update_proposed":
      return {
        title: "Proposta di modifica inviata",
        body: `Hai inviato una proposta di modifica per la jam del ${date} alle ${start}.`,
      };
    case "admin_jam_update_accepted":
      return {
        title: "Proposta jam accettata",
        body: `${username} ha accettato la proposta di modifica per la jam del ${date} alle ${start}.`,
      };
    case "admin_jam_update_rejected":
      return {
        title: "Proposta jam rifiutata",
        body: `${username} ha rifiutato la proposta di modifica per la jam del ${date} alle ${start}.`,
      };
    case "jam_update_proposal":
      return {
        title: "Proposta modifica jam",
        body: `${username} propone di modificare la tua jam del ${date} alle ${start}.`,
      };
    case "group_invite":
      return {
        title: "Invito a un gruppo",
        body: `${(payload && payload.inviter_username) || "Un utente"} ti ha invitato in un gruppo.`,
      };
    case "group_invite_accepted":
      return {
        title: "Invito gruppo accettato",
        body: `${username} ha accettato l'invito al gruppo.`,
      };
    case "group_invite_rejected":
      return {
        title: "Invito gruppo rifiutato",
        body: `${username} ha rifiutato l'invito al gruppo.`,
      };
    case "support_chat_message": {
      const subject = payload && payload.subject ? String(payload.subject).trim() : "Richiesta assistenza";
      const preview = payload && payload.message_preview ? String(payload.message_preview).trim() : "Nuovo messaggio ricevuto.";
      return {
        title: `Supporto: ${subject}`,
        body: `${username}: ${preview}`,
      };
    }
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
    case "group_booking_modified":
    case "group_booking_confirmed":
    case "group_booking_cancelled":
    case "booking_confirmed":
    case "booking_cancelled":
    case "admin_booking_created":
    case "admin_booking_modified":
    case "admin_booking_cancelled":
    case "admin_booking_update_proposed":
    case "admin_booking_update_accepted":
    case "admin_booking_update_rejected":
    case "booking_update_proposal":
      return "booking";
    case "group_jam_created":
    case "group_jam_modified":
    case "group_jam_approved":
    case "group_jam_rejected":
    case "jam_approved":
    case "jam_rejected":
    case "admin_jam_created":
    case "admin_jam_modified":
    case "admin_jam_cancelled":
    case "admin_jam_update_proposed":
    case "admin_jam_update_accepted":
    case "admin_jam_update_rejected":
    case "jam_update_proposal":
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
      booking_id: (payload && payload.booking_id ? String(payload.booking_id) : ""),
      jam_id: (payload && payload.jam_id ? String(payload.jam_id) : ""),
      chat_id: (payload && payload.chat_id ? String(payload.chat_id) : ""),
      subject_id: (payload && payload.subject_id ? String(payload.subject_id) : ""),
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

async function isAdminUid(uid) {
  if (!uid) {
    return false;
  }

  const userData = await getValue(`users/${uid}`);
  return !!(userData && typeof userData === "object" && userData.role === "admin");
}

async function checkRegistrationAvailabilityValues({
  nickname,
  email,
  excludingUid,
}) {
  const normalizedNickname = normalizeNickname(nickname);
  const normalizedEmail = normalizeEmail(email);
  const excludedUid = String(excludingUid || "").trim();

  let nicknameAvailable = false;
  if (normalizedNickname) {
    const nicknameClaim = await getValue(`nickname_claims/${normalizedNickname}`);
    const claimedBy = nicknameClaim == null ? "" : String(nicknameClaim).trim();
    if (!claimedBy || claimedBy === excludedUid) {
      const indexedUsers = parseIndexedUserIds(
          await getValue(`user_search_index/${normalizedNickname}`),
      ).filter((uid) => uid && uid !== excludedUid);
      nicknameAvailable = indexedUsers.length === 0;
    }
  }

  let emailAvailable = false;
  if (normalizedEmail) {
    const claimedBy = String(
        (await getValue(`email_claims/${emailKey(normalizedEmail)}`)) || "",
    ).trim();
    emailAvailable = !claimedBy || claimedBy === excludedUid;
  }

  return {nicknameAvailable, emailAvailable};
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

function clearSlotBookingReference(dateStr, slotKey, updates) {
  updates[`/slots/${dateStr}/${slotKey}/status`] = "libero";
  updates[`/slots/${dateStr}/${slotKey}/booked_by`] = null;
  updates[`/slots/${dateStr}/${slotKey}/booking_id`] = null;
  updates[`/slots/${dateStr}/${slotKey}/is_jam`] = null;
}

async function removeSlotsByBookingId(dateStr, bookingId, updates) {
  const scannedDates = new Set();

  async function scanDateSlots(targetDate) {
    if (!targetDate || scannedDates.has(targetDate)) {
      return;
    }

    scannedDates.add(targetDate);
    const slots = await getValue(`slots/${targetDate}`);
    if (!slots || typeof slots !== "object") {
      return;
    }

    for (const [slotKey, rawSlot] of Object.entries(slots)) {
      if (!rawSlot || typeof rawSlot !== "object") {
        continue;
      }
      if (rawSlot.booking_id === bookingId) {
        clearSlotBookingReference(targetDate, slotKey, updates);
      }
    }
  }

  await scanDateSlots(dateStr);

  const allSlots = await getValue("slots");
  if (!allSlots || typeof allSlots !== "object") {
    return;
  }

  for (const [targetDate, rawDay] of Object.entries(allSlots)) {
    if (scannedDates.has(targetDate) || !rawDay || typeof rawDay !== "object") {
      continue;
    }

    for (const [slotKey, rawSlot] of Object.entries(rawDay)) {
      if (!rawSlot || typeof rawSlot !== "object") {
        continue;
      }
      if (rawSlot.booking_id === bookingId) {
        clearSlotBookingReference(targetDate, slotKey, updates);
      }
    }
  }
}

async function removeUserNotificationsByField(fieldName, fieldValue, updates) {
  if (!fieldValue) {
    return;
  }

  const notifications = await getValue("user_notifications");
  if (!notifications || typeof notifications !== "object") {
    return;
  }

  for (const [uid, rawUserNotifications] of Object.entries(notifications)) {
    if (!rawUserNotifications || typeof rawUserNotifications !== "object") {
      continue;
    }

    for (const [notificationId, rawNotification] of Object.entries(rawUserNotifications)) {
      if (!rawNotification || typeof rawNotification !== "object") {
        continue;
      }

      if (
        rawNotification[fieldName] === fieldValue ||
        notificationId === fieldValue
      ) {
        updates[`/user_notifications/${uid}/${notificationId}`] = null;
      }
    }
  }
}

async function buildBookingDeletionUpdates(
    bookingId,
    bookingData,
    notificationMemberIds = null,
) {
  const updates = {
    [`/bookings/${bookingId}`]: null,
  };
  const bookingOwnerId = bookingData.user_id || "";
  const bookingDate = bookingData.data || "";
  const groupId = bookingData.group_id || "";

  if (bookingOwnerId) {
    updates[`/user_bookings/${bookingOwnerId}/${bookingId}`] = null;
  }

  await removeUserNotificationsByField("booking_id", bookingId, updates);

  if (groupId) {
    updates[`/group_bookings/${groupId}/${bookingId}`] = null;
    updates[`/group_booking_notifications/${groupId}/${bookingId}`] = null;

    const memberIds = notificationMemberIds || new Set(extractIds(
        await getValue(`groups_info/${groupId}/members`),
    ));
    for (const memberId of memberIds) {
        updates[`/user_notifications/${memberId}/${bookingId}`] = null;
      }
  }

  await removeSlotsByBookingId(bookingDate, bookingId, updates);
  return updates;
}

async function buildJamDeletionUpdates(jamId, jamData) {
  const updates = {};
  const dateStr = jamData.data || "";
  const participants = jamData.participants;

  await removeSlotsByBookingId(dateStr, jamId, updates);

  await removeFeedEntriesByJamId(jamId, updates);
  await removeUserNotificationsByField("jam_id", jamId, updates);

  if (participants && typeof participants === "object") {
    for (const participantId of Object.keys(participants)) {
      updates[`/user_joined_jams/${participantId}/${jamId}`] = null;
    }
  }

  updates[`/jams/${jamId}`] = null;
  return updates;
}

function removeGroupInviteArtifacts(groupId, targetUid, updates) {
  if (!groupId || !targetUid) {
    return;
  }

  updates[`/group_invites/${targetUid}/${groupId}`] = null;
  updates[`/user_notifications/${targetUid}/${groupInviteNotificationId(groupId)}`] =
    null;
}

async function cleanupUserData(uid) {
  const updates = {
    [`/users/${uid}`]: null,
    [`/user_public_profiles/${uid}`]: null,
    [`/user_bookings/${uid}`]: null,
    [`/user_joined_jams/${uid}`]: null,
    [`/user_notifications/${uid}`]: null,
    [`/group_invites/${uid}`]: null,
    [`/user_devices/${uid}`]: null,
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

      const groupMemberIds = new Set([
        ...extractIds(rawGroup.members),
        ...extractIds(rawGroup.member_nicknames),
      ]);
      const pendingInviteIds = new Set(extractIds(rawGroup.pending_invites));

      if (rawGroup.owner_id === uid) {
        updates[`/groups_info/${groupId}`] = null;
        updates[`/group_bookings/${groupId}`] = null;
        updates[`/group_booking_notifications/${groupId}`] = null;

        for (const memberId of groupMemberIds) {
          updates[`/users/${memberId}/gruppi/${groupId}`] = null;
        }

        for (const invitedUserId of pendingInviteIds) {
          removeGroupInviteArtifacts(groupId, invitedUserId, updates);
        }

        const groupBookings = await getValue(`group_bookings/${groupId}`);
        if (groupBookings && typeof groupBookings === "object") {
          for (const [bookingId, rawBooking] of Object.entries(groupBookings)) {
            if (!rawBooking || typeof rawBooking !== "object") {
              continue;
            }
            Object.assign(
                updates,
                await buildBookingDeletionUpdates(
                    bookingId,
                    rawBooking,
                    groupMemberIds,
                ),
            );
          }
        }
        continue;
      }

      if (groupMemberIds.has(uid)) {
        updates[`/groups_info/${groupId}/members/${uid}`] = null;
        updates[`/groups_info/${groupId}/member_nicknames/${uid}`] = null;
        updates[`/users/${uid}/gruppi/${groupId}`] = null;
      }

      if (pendingInviteIds.has(uid)) {
        updates[`/groups_info/${groupId}/pending_invites/${uid}`] = null;
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

      if (extractIds(rawJam.participants).includes(uid)) {
        const currentPresent = parseCount(rawJam.persone_presenti);
        const currentRequired = parseCount(rawJam.persone_richieste);
        updates[`/jams/${jamId}/participants/${uid}`] = null;
        updates[`/jams/${jamId}/participant_usernames/${uid}`] = null;
        updates[`/jams/${jamId}/persone_presenti`] = currentPresent > 0 ? currentPresent - 1 : 0;
        updates[`/jams/${jamId}/persone_richieste`] = currentRequired + 1;
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

exports.fanoutSupportChatAdminNotifications = functions.database
    .ref("/support_chat_messages/{chatId}/{messageId}")
    .onCreate(async (snapshot, context) => {
      const payload = snapshot.val();
      if (!payload || typeof payload !== "object") {
        return null;
      }

      if (String(payload.sender_role || "") !== "user") {
        return null;
      }

      const chatId = String(context.params.chatId || "").trim();
      if (!chatId) {
        return null;
      }

      const chat = await getValue(`/support_chats/${chatId}`);
      if (!chat || typeof chat !== "object") {
        return null;
      }

      if (String(chat.status || "open") !== "open") {
        return null;
      }

      const adminsSnapshot = await db.ref("users").orderByChild("role").equalTo("admin").get();
      if (!adminsSnapshot.exists()) {
        return null;
      }

      const updates = {};
      adminsSnapshot.forEach((child) => {
        const adminId = String(child.key || "").trim();
        if (!adminId) {
          return false;
        }

        const notificationId = db.ref(`user_notifications/${adminId}`).push().key;
        if (!notificationId) {
          return false;
        }

        updates[`/user_notifications/${adminId}/${notificationId}`] = {
          type: "support_chat_message",
          timestamp: admin.database.ServerValue.TIMESTAMP,
          read: false,
          chat_id: chatId,
          subject: String(chat.subject || "Richiesta assistenza"),
          message_preview: String(payload.text || "").trim().slice(0, 140),
          username: String(
              payload.sender_display_name || chat.user_nickname || "Utente",
          ),
          requester_id: String(chat.user_id || ""),
          creator_id: String(chat.user_id || ""),
        };
        return false;
      });

      if (!Object.keys(updates).length) {
        return null;
      }

      await db.ref().update(updates);
      return null;
    });

exports.checkRegistrationAvailability = functions
    .region("us-central1")
    .https
    .onCall(async (data) => {
      const nickname = String((data && data.nickname) || "").trim();
      const email = String((data && data.email) || "").trim();
      const excludingUid = String((data && data.excludingUid) || "").trim();

      if (!nickname || !email) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "nickname ed email sono obbligatori.",
        );
      }

      return checkRegistrationAvailabilityValues({
        nickname,
        email,
        excludingUid,
      });
    });

exports.deleteCurrentUserAccount = functions
    .region("us-central1")
    .https
    .onCall(async (_data, context) => {
      if (!context.auth || !context.auth.uid) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Utente non autenticato.",
        );
      }

      const uid = context.auth.uid;

      try {
        await admin.auth().deleteUser(uid);
      } catch (error) {
        const code = error && typeof error === "object" ? error.code : "";
        if (code !== "auth/user-not-found") {
          throw new functions.https.HttpsError(
              "internal",
              "Eliminazione account da Authentication fallita.",
          );
        }
      }

      try {
        await cleanupUserData(uid);
      } catch (error) {
        throw new functions.https.HttpsError(
            "internal",
            "Account eliminato da Authentication ma cleanup database fallito.",
        );
      }

      return {ok: true};
    });

exports.deleteBookingCascade = functions
    .region("us-central1")
    .https
    .onCall(async (data, context) => {
      if (!context.auth || !context.auth.uid) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Utente non autenticato.",
        );
      }

      const bookingId = String((data && data.bookingId) || "").trim();
      if (!bookingId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "bookingId obbligatorio.",
        );
      }

      const bookingData = await getValue(`bookings/${bookingId}`);
      if (!bookingData || typeof bookingData !== "object") {
        return {ok: true};
      }

      const uid = context.auth.uid;
      const isAdmin = (await getValue(`users/${uid}/role`)) === "admin";
      const bookingOwnerId = String(bookingData.user_id || "").trim();
      const groupId = String(bookingData.group_id || "").trim();
      const groupOwnerId = groupId ?
        String((await getValue(`groups_info/${groupId}/owner_id`)) || "").trim() :
        "";

      if (!isAdmin && bookingOwnerId !== uid && groupOwnerId !== uid) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Non hai i permessi per eliminare questa prenotazione.",
        );
      }

      const updates = await buildBookingDeletionUpdates(bookingId, bookingData);
      await db.ref().update(updates);
      return {ok: true};
    });

exports.deleteJamCascade = functions
    .region("us-central1")
    .https
    .onCall(async (data, context) => {
      if (!context.auth || !context.auth.uid) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Utente non autenticato.",
        );
      }

      const jamId = String((data && data.jamId) || "").trim();
      if (!jamId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "jamId obbligatorio.",
        );
      }

      const jamData = await getValue(`jams/${jamId}`);
      if (!jamData || typeof jamData !== "object") {
        return {ok: true};
      }

      const uid = context.auth.uid;
      const isAdmin = (await getValue(`users/${uid}/role`)) === "admin";
      const creatorId = String(jamData.creator_id || "").trim();

      if (!isAdmin && creatorId !== uid) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Non hai i permessi per eliminare questa jam.",
        );
      }

      const updates = await buildJamDeletionUpdates(jamId, jamData);
      await db.ref().update(updates);
      return {ok: true};
    });

exports.deleteGroupCascade = functions
    .region("us-central1")
    .https
    .onCall(async (data, context) => {
      if (!context.auth || !context.auth.uid) {
        throw new functions.https.HttpsError(
            "unauthenticated",
            "Utente non autenticato.",
        );
      }

      const groupId = String((data && data.groupId) || "").trim();
      if (!groupId) {
        throw new functions.https.HttpsError(
            "invalid-argument",
            "groupId obbligatorio.",
        );
      }

      const groupData = await getValue(`groups_info/${groupId}`);
      if (!groupData || typeof groupData !== "object") {
        return {ok: true};
      }

      const uid = context.auth.uid;
      const isAdmin = (await getValue(`users/${uid}/role`)) === "admin";
      const ownerId = String(groupData.owner_id || "").trim();

      if (!isAdmin && ownerId !== uid) {
        throw new functions.https.HttpsError(
            "permission-denied",
            "Non hai i permessi per eliminare questo gruppo.",
        );
      }

      const memberIds = new Set([
        ...extractIds(groupData.members),
        ...extractIds(groupData.member_nicknames),
      ]);
      const pendingInviteIds = new Set(extractIds(groupData.pending_invites));
      const updates = {
        [`/groups_info/${groupId}`]: null,
        [`/group_bookings/${groupId}`]: null,
        [`/group_booking_notifications/${groupId}`]: null,
      };

      const groupBookings = await getValue(`group_bookings/${groupId}`);
      if (groupBookings && typeof groupBookings === "object") {
        for (const [bookingId, rawBooking] of Object.entries(groupBookings)) {
          if (!rawBooking || typeof rawBooking !== "object") {
            continue;
          }

          Object.assign(
              updates,
              await buildBookingDeletionUpdates(
                  bookingId,
                  rawBooking,
                  memberIds,
              ),
          );
        }
      }

      for (const memberId of memberIds) {
        updates[`/users/${memberId}/gruppi/${groupId}`] = null;
      }

      for (const invitedUserId of pendingInviteIds) {
        removeGroupInviteArtifacts(groupId, invitedUserId, updates);
      }

      await db.ref().update(updates);
      return {ok: true};
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

exports.removeUserFromGroup = functions.region("us-central1").https.onCall(async (data, context) => {
  if (!context.auth || !context.auth.uid) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "Utente non autenticato.",
    );
  }

  const groupId = String((data && data.groupId) || "").trim();
  const targetUserId = String((data && data.targetUserId) || "").trim();
  if (!groupId || !targetUserId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "groupId e targetUserId sono obbligatori.",
    );
  }

  const callerUid = context.auth.uid;
  const group = await getValue(`groups_info/${groupId}`);
  if (!group || typeof group !== "object") {
    throw new functions.https.HttpsError("not-found", "Gruppo non trovato.");
  }

  const callerData = await getValue(`users/${callerUid}`);
  const isAdmin = callerData && typeof callerData === "object" && callerData.role === "admin";
  const ownerId = String(group.owner_id || "").trim();
  if (ownerId !== callerUid && !isAdmin) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Solo il proprietario del gruppo puo rimuovere membri.",
    );
  }

  if (targetUserId === ownerId) {
    throw new functions.https.HttpsError(
        "failed-precondition",
        "Il proprietario non puo essere rimosso dal gruppo.",
    );
  }

  const memberIds = new Set([
    ...extractIds(group.members),
    ...extractIds(group.member_nicknames),
  ]);
  if (!memberIds.has(targetUserId)) {
    throw new functions.https.HttpsError(
        "not-found",
        "Utente non presente nel gruppo.",
    );
  }

  const callerUsername = String(
      callerData?.username ||
      callerData?.nickname ||
      callerUid,
  );
  const targetUser = await getValue(`users/${targetUserId}`);
  const targetUsername = String(
      targetUser?.username ||
      targetUser?.nickname ||
      targetUserId,
  );
  const activityRef = db.ref(`groups_info/${groupId}/activity`).push();

  await db.ref().update({
    [`/groups_info/${groupId}/members/${targetUserId}`]: null,
    [`/groups_info/${groupId}/member_nicknames/${targetUserId}`]: null,
    [`/users/${targetUserId}/gruppi/${groupId}`]: null,
    [`/groups_info/${groupId}/activity/${activityRef.key}`]:
      groupActivityEntry(
          "member_removed",
          `${callerUsername} ha rimosso ${targetUsername} dal gruppo.`,
      ),
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

  if (!(await isAdminUid(context.auth.uid))) {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Solo un admin puo eseguire il cleanup degli slot.",
    );
  }

  const slots = await getValue("slots");
  if (!slots || typeof slots !== "object") {
    return {deletedCount: 0};
  }

  const todayKey = new Date().toISOString().slice(0, 10);
  const updates = {};
  let deletedCount = 0;

  for (const dateKey of Object.keys(slots)) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateKey)) {
      continue;
    }

    if (dateKey < todayKey) {
      updates[`/slots/${dateKey}`] = null;
      deletedCount += 1;
    }
  }

  if (deletedCount > 0) {
    await db.ref().update(updates);
  }

  return {deletedCount};
});
