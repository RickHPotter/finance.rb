# frozen_string_literal: true

class DuePaymentsNotifier
  def call
    User.find_each do |user|
      due_today = user.cash_installments.due_today
      next if due_today.none?

      I18n.locale = user.locale

      title = I18n.t("push_subscriptions.due_payment_notifier.title")
      url = Rails.application.routes.url_helpers.root_url(host: Rails.env.production? ? "30fev.com" : "localhost")

      user.push_subscriptions.each do |push_subscription|
        due_today.each do |cash_installment|
          body = "#{I18n.t('push_subscriptions.due_payment_notifier.body', count: 1)} - #{cash_installment.cash_transaction.description}"
          payload_send(title:, body:, url:, push_subscription:)
        end
      rescue WebPush::ExpiredSubscription, WebPush::PushServiceError => e
        puts "PushSubscription invalid: #{e.message}"
        push_subscription.destroy
      rescue StandardError => e
        Rails.logger.error("Push failed: #{e.message}")
      end
    end

    I18n.locale = I18n.default_locale
  end

  def payload_send(title:, body:, url:, push_subscription:)
    WebPush.payload_send(
      message: { title:, body:, url: }.to_json,
      endpoint: push_subscription.endpoint,
      p256dh: push_subscription.p256dh,
      auth: push_subscription.auth,
      vapid: {
        subject: "mailto:30fevfun@gmail.com",
        public_key: Rails.application.credentials.dig(:vapid, :public_key),
        private_key: Rails.application.credentials.dig(:vapid, :private_key)
      }
    )
  end
end
