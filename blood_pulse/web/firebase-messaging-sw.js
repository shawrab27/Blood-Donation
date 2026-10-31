importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

// Canonical Firebase config for BloodPulse Web Push
firebase.initializeApp({
  apiKey: "AIzaSyCShzXhwOg-dzviWjcXMylDyWREU-HrVcU",
  authDomain: "bloodpulse-283dc.firebaseapp.com",
  projectId: "bloodpulse-283dc",
  storageBucket: "bloodpulse-283dc.firebasestorage.app",
  messagingSenderId: "404989190662",
  appId: "1:404989190662:web:d93054d0554ce384e25987",
  measurementId: "G-YF60Y0LHDB"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message: ', payload);
  // Prevent duplicate: When payload.notification exists, the Web Push standard
  // already automatically displays the native banner. Showing it again causes duplicate alerts.
  if (payload.notification && payload.notification.title) {
    return;
  }
  const notificationTitle = (payload.data && payload.data.title) || 'BloodPulse Alert';
  const reqId = (payload.data && (payload.data.request_id || payload.data.requestId));
  const tag = reqId ? ('bloodpulse_req_' + reqId) : notificationTitle;
  const notificationOptions = {
    body: (payload.data && payload.data.body) || 'New blood request notification.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: tag, // Deduplicate alerts with the same tag
    data: payload.data || {}
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const data = (event.notification && event.notification.data) || {};
  let targetUrl = '/feed';
  if (data.requestId || data.request_id) {
    targetUrl = '/journeys/' + (data.requestId || data.request_id);
  } else if (data.chatId || data.chat_id || data.chatRoomId) {
    targetUrl = '/chat?roomId=' + (data.chatId || data.chat_id || data.chatRoomId);
  }
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (let i = 0; i < clientList.length; i++) {
        let client = clientList[i];
        if (client.url && 'focus' in client) {
          if ('navigate' in client) client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
