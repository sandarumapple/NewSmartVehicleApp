const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore} = require("firebase-admin/firestore");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

exports.sendCommunityNotification = onDocumentCreated(
  {
    document: "users/{userId}/notifications/{notificationId}",
    region: "asia-south1",
  },
  async (event) => {
    const notification = event.data?.data();
    if (!notification) return;

    const userId = event.params.userId;
    const devices = await getFirestore()
      .collection("users")
      .doc(userId)
      .collection("devices")
      .get();
    const registrations = devices.docs
      .map((document) => ({
        reference: document.ref,
        token: document.get("installationID"),
      }))
      .filter((device) => typeof device.token === "string" && device.token.length > 0);
    if (registrations.length === 0) return;

    const unread = await getFirestore()
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .where("isRead", "==", false)
      .count()
      .get();
    const isComment = notification.type === "comment";
    const response = await getMessaging().sendEachForMulticast({
      tokens: registrations.map((device) => device.token),
      notification: {
        title: isComment ? "New comment" : "New like",
        body: isComment
          ? `${notification.actorName} commented on your post.`
          : `${notification.actorName} liked your post.`,
      },
      data: {
        type: notification.type,
        postID: notification.postID,
        notificationID: event.params.notificationId,
        recipientID: userId,
      },
      apns: {
        headers: {"apns-collapse-id": event.params.notificationId},
        payload: {aps: {sound: "default", badge: unread.data().count}},
      },
    });

    const invalidCodes = new Set([
      "messaging/registration-token-not-registered",
      "messaging/invalid-registration-token",
    ]);
    const removals = response.responses.flatMap((result, index) =>
      !result.success && invalidCodes.has(result.error?.code)
        ? [registrations[index].reference.delete()]
        : []
    );
    await Promise.all(removals);
  }
);
