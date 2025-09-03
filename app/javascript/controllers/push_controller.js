import { Controller } from "@hotwired/stimulus"

// Stimulus controller for push notifications
export default class extends Controller {
  async subscribe() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window)) {
      alert("Push notifications are not supported in this browser.");
      return;
    }

    const permission = await Notification.requestPermission()
    if (permission !== "granted") {
      alert("You must allow notifications to enable this feature.");
      return;
    }

    const registration = await navigator.serviceWorker.ready

    // Convert VAPID key
    const vapidPublicKey = window.vapid_public_key
    const convertedKey = this.urlBase64ToUint8Array(vapidPublicKey)

    try {
      const subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: convertedKey
      })

      // Send subscription to Rails backend
      await fetch("/subscriptions", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ subscription })
      })

      alert("✅ Notifications enabled!")
    } catch (err) {
      console.error("Push subscription failed:", err)
      alert("❌ Could not subscribe to notifications.")
    }
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = window.atob(base64)
    return Uint8Array.from([...rawData].map((c) => c.charCodeAt(0)))
  }
}
