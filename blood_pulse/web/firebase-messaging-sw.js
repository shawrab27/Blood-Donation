importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js");

// Default Firebase config for background push messaging worker
firebase.initializeApp({
  apiKey: "AIzaSyBloodPulseWebClientPlaceholder",
  projectId: "bloodpulse-app",
  messagingSenderId: "1056586036128",
  appId: "1:1056586036128:web:bloodpulse"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message: ', payload);
  const notificationTitle = (payload.notification && payload.notification.title) ||
    (payload.data && payload.data.title) ||
    'BloodPulse Alert';
  const notificationOptions = {
    body: (payload.notification && payload.notification.body) ||
      (payload.data && payload.data.body) ||
      'New blood request notification.',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data || {}
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      if (clientList.length > 0) {
        let client = clientList[0];
        for (let i = 0; i < clientList.length; i++) {
          if (clientList[i].focused) {
            client = clientList[i];
          }
        }
        return client.focus();
      }
      return clients.openWindow('/');
    })
  );
});
