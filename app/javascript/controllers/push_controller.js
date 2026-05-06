import { Controller } from "@hotwired/stimulus"

// Stimulus controller for push notifications
export default class extends Controller {
  connect() {
    this.syncExistingSubscription()
  }

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
      const push_subscription = await this.findOrCreateSubscription(registration, convertedKey)
      await this.saveSubscription(push_subscription)

      alert("✅ Notifications enabled!")
    } catch (err) {
      console.error("Push subscription failed:", err)
      alert("❌ Could not subscribe to notifications.")
    }
  }

  async syncExistingSubscription() {
    if (!("serviceWorker" in navigator) || !("PushManager" in window) || Notification.permission !== "granted") return

    try {
      const registration = await navigator.serviceWorker.ready
      const push_subscription = await registration.pushManager.getSubscription()
      if (!push_subscription) return

      await this.saveSubscription(push_subscription)
    } catch (err) {
      console.error("Push subscription sync failed:", err)
    }
  }

  async findOrCreateSubscription(registration, convertedKey) {
    const existingSubscription = await registration.pushManager.getSubscription()
    if (existingSubscription) return existingSubscription

    return registration.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: convertedKey
    })
  }

  async saveSubscription(push_subscription) {
    const response = await fetch("/push_subscriptions", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "same-origin",
      body: JSON.stringify({ push_subscription })
    })

    if (!response.ok) throw new Error(`Push subscription save failed with ${response.status}`)
  }

  urlBase64ToUint8Array(base64String) {
    const padding = "=".repeat((4 - (base64String.length % 4)) % 4)
    const base64 = (base64String + padding).replace(/-/g, "+").replace(/_/g, "/")
    const rawData = window.atob(base64)
    return Uint8Array.from([...rawData].map((c) => c.charCodeAt(0)))
  }
}
