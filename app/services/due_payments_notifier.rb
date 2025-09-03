# frozen_string_literal: true

class DuePaymentsNotifier
  def call
    title = I18n.t("subscriptions.due_payment_notifier.title")
    url = Rails.application.routes.url_helpers.root_url(host: Rails.env.production? ? "30fev.fun" : "localhost")

    User.find_each do |user|
      due_today = user.cash_installments.due_today.count
      next if due_today.zero?

      user.subscriptions.each do |subscription|
        send(title:, body: I18n.t("subscriptions.due_payment_notifier.body", count: due_today), url:, subscription:)
      rescue WebPush::ExpiredSubscription, WebPush::PushServiceError => e
        puts "Subscription invalid: #{e.message}"
        subscription.destroy
      rescue StandardError => e
        Rails.logger.error("Push failed: #{e.message}")
      end
    end
  end

  def send(title:, body:, url:, subscription:)
    WebPush.payload_send(
      message: { title:, body:, url: }.to_json,
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
      vapid: {
        subject: "mailto:30fevfun@gmail.com",
        public_key: Rails.application.credentials.dig(:vapid, :public_key),
        private_key: Rails.application.credentials.dig(:vapid, :private_key)
      }
    )
  end
end
