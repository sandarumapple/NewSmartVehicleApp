// Run against the Firestore emulator only. No real users or production data.
// firebase emulators:exec --only firestore --project demo-smartvehicle \
//   'node --test functions/tests/community-notifications.test.js'
const {test} = require("node:test");
const assert = require("node:assert/strict");
const {randomUUID} = require("node:crypto");

const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error("A local FIRESTORE_EMULATOR_HOST is required; production is never used.");
}
const project = process.env.GCLOUD_PROJECT || "demo-smartvehicle";
const database = `projects/${project}/databases/(default)`;
const endpoint = `http://${host}/v1/${database}/documents`;
const owner = "notification-owner";
const actor = "notification-reactor";
const text = (value) => ({stringValue: value});
const fields = (values) => Object.fromEntries(Object.entries(values).map(([key, value]) => [
  key, typeof value === "boolean" ? {booleanValue: value} : text(value),
]));

function token(uid) {
  const now = Math.floor(Date.now() / 1000);
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
  return `${encode({alg: "none", typ: "JWT"})}.${encode({
    iss: `https://securetoken.google.com/${project}`,
    aud: project, sub: uid, user_id: uid, iat: now, exp: now + 3600, auth_time: now,
    firebase: {sign_in_provider: "custom", identities: {}},
  })}.`;
}

async function request(path, uid, body, method = "POST") {
  const response = await fetch(`${endpoint}${path}`, {
    method,
    headers: {
      Authorization: `Bearer ${uid === "admin" ? "owner" : token(uid)}`,
      "Content-Type": "application/json",
    },
    ...(body ? {body: JSON.stringify(body)} : {}),
  });
  const data = await response.json();
  return {status: response.status, data};
}

function write(path, data, timestamp = false) {
  return {
    update: {name: `${database}/documents/${path}`, fields: data},
    ...(timestamp ? {updateTransforms: [{fieldPath: "createdAt", setToServerValue: "REQUEST_TIME"}]} : {}),
  };
}

function like(postID, uid, remove = false) {
  return {transform: {
    document: `${database}/documents/communityPosts/${postID}`,
    fieldTransforms: [{
      fieldPath: "likedBy",
      [remove ? "removeAllFromArray" : "appendMissingElements"]: {values: [text(uid)]},
    }],
  }};
}

function notification(postID, type, sourceID, extra = {}) {
  return write(`users/${owner}/notifications/${randomUUID()}`, fields({
    type, actorID: actor, actorName: "Test Reactor", recipientID: owner,
    postID, sourceID, postPreview: "Test vehicle post", isRead: false, ...extra,
  }), true);
}

async function seedPost() {
  const postID = randomUUID();
  const response = await request(":commit", "admin", {writes: [write(
    `communityPosts/${postID}`, {
      ...fields({authorID: owner, text: "Test vehicle post"}),
      likedBy: {arrayValue: {values: []}},
    },
  )]});
  assert.equal(response.status, 200, JSON.stringify(response.data));
  return postID;
}

test("another account's like creates an unread notification atomically", async () => {
  const postID = await seedPost();
  const alert = notification(postID, "like", actor);
  const result = await request(":commit", actor, {writes: [like(postID, actor), alert]});
  assert.equal(result.status, 200, JSON.stringify(result.data));
  const path = alert.update.name.split("/documents")[1];
  const inbox = await request(path, owner, undefined, "GET");
  assert.equal(inbox.status, 200);
  assert.equal(inbox.data.fields.isRead.booleanValue, false);
  assert.equal(inbox.data.fields.actorID.stringValue, actor);
  const read = await request(":commit", owner, {writes: [{
    ...write(path.slice(1), {isRead: {booleanValue: true}}),
    updateMask: {fieldPaths: ["isRead"]},
  }]});
  assert.equal(read.status, 200, JSON.stringify(read.data));
});

test("unlike then re-like uses a new notification instead of a forbidden overwrite", async () => {
  const postID = await seedPost();
  const first = notification(postID, "like", actor);
  const second = notification(postID, "like", actor);
  for (const writes of [[like(postID, actor), first], [like(postID, actor, true)],
    [like(postID, actor), second]]) {
    const result = await request(":commit", actor, {writes});
    assert.equal(result.status, 200, JSON.stringify(result.data));
  }
  assert.notEqual(first.update.name, second.update.name);
  for (const alert of [first, second]) {
    const result = await request(alert.update.name.split("/documents")[1], owner, undefined, "GET");
    assert.equal(result.status, 200);
  }
});

test("a comment and its notification can be created in the same batch", async () => {
  const postID = await seedPost();
  const commentID = randomUUID();
  const comment = write(`communityPosts/${postID}/comments/${commentID}`, {
    ...fields({authorID: actor, authorName: "Test Reactor", text: "Helpful post!"}),
    payload: {bytesValue: Buffer.from("{}").toString("base64")},
  }, true);
  const result = await request(":commit", actor, {writes: [
    comment, notification(postID, "comment", commentID),
  ]});
  assert.equal(result.status, 200, JSON.stringify(result.data));
});

test("a failed notification rolls back the like as well", async () => {
  const postID = await seedPost();
  const result = await request(":commit", actor, {writes: [
    like(postID, actor), notification(postID, "like", actor, {actorID: "forged-user"}),
  ]});
  assert.equal(result.status, 403);
  const post = await request(`/communityPosts/${postID}`, owner, undefined, "GET");
  assert.deepEqual(post.data.fields.likedBy.arrayValue.values || [], []);
});

test("another user cannot read or mark someone else's notification as read", async () => {
  const postID = await seedPost();
  const alert = notification(postID, "like", actor);
  const created = await request(":commit", actor, {writes: [like(postID, actor), alert]});
  assert.equal(created.status, 200, JSON.stringify(created.data));
  const path = alert.update.name.split("/documents")[1];
  assert.equal((await request(path, actor, undefined, "GET")).status, 403);
  const edit = await request(":commit", actor, {writes: [{
    ...write(path.slice(1), {isRead: {booleanValue: true}}),
    updateMask: {fieldPaths: ["isRead"]},
  }]});
  assert.equal(edit.status, 403);
});

test("a notification without a matching reaction is denied", async () => {
  const postID = await seedPost();
  const result = await request(":commit", actor, {writes: [notification(postID, "like", actor)]});
  assert.equal(result.status, 403);
});
