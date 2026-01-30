// Firebase Messaging Service Worker for BODA CONNECT
// This file handles background push notifications on web

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize the Firebase app in the service worker
firebase.initializeApp({
  apiKey: 'AIzaSyCIsAMA5W5oeSs7gxbdciIWJnkC0dRqHgs',
  authDomain: 'boda-connect-49eb9.firebaseapp.com',
  projectId: 'boda-connect-49eb9',
  storageBucket: 'boda-connect-49eb9.firebasestorage.app',
  messagingSenderId: '801918014868',
  appId: '1:801918014868:web:ddd61c7943f7e19b306b81',
});

// Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);

  const notificationTitle = payload.notification?.title || 'BODA CONNECT';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: payload.data?.type || 'notification',
    data: payload.data,
    // Actions based on notification type
    actions: getNotificationActions(payload.data?.type),
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification clicked:', event);

  event.notification.close();

  const data = event.notification.data || {};
  let targetUrl = '/';

  // Navigate based on notification type
  switch (data.type) {
    case 'new_booking':
    case 'booking_confirmed':
    case 'booking_cancelled':
    case 'booking_update':
      targetUrl = data.bookingId
        ? `/supplier-order-detail?bookingId=${data.bookingId}`
        : '/supplier-orders';
      break;

    case 'new_message':
    case 'chat_message':
      targetUrl = data.senderId
        ? `/chat-detail?userId=${data.senderId}&userName=${encodeURIComponent(data.senderName || 'User')}`
        : '/chat-list';
      break;

    case 'new_proposal':
    case 'proposal_accepted':
    case 'proposal_rejected':
      targetUrl = data.senderId
        ? `/chat-detail?userId=${data.senderId}`
        : '/chat-list';
      break;

    case 'new_review':
    case 'review_received':
      targetUrl = '/supplier-reviews';
      break;

    case 'payment_received':
    case 'payment_confirmed':
      targetUrl = '/supplier-revenue';
      break;

    default:
      targetUrl = '/notifications';
  }

  // Open the app or focus existing window
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      // Check if there's already a window open
      for (const client of clientList) {
        if (client.url.includes(self.registration.scope) && 'focus' in client) {
          client.postMessage({ type: 'NOTIFICATION_CLICK', url: targetUrl });
          return client.focus();
        }
      }
      // If no window is open, open a new one
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});

// Get notification actions based on type
function getNotificationActions(type) {
  switch (type) {
    case 'new_booking':
      return [
        { action: 'view', title: 'Ver Reserva' },
        { action: 'dismiss', title: 'Dispensar' },
      ];
    case 'new_message':
    case 'chat_message':
      return [
        { action: 'reply', title: 'Responder' },
        { action: 'dismiss', title: 'Dispensar' },
      ];
    default:
      return [];
  }
}

console.log('[firebase-messaging-sw.js] Service worker loaded');
