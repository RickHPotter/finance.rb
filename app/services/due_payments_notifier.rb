# frozen_string_literal: true

class DuePaymentsNotifier
  def call
    title = I18n.t("subscriptions.due_payment_notifier.title")
    url = Rails.application.routes.url_helpers.root_url(host: Rails.env.production? ? "30fev.fun" : "localhost")

    User.find_each do |user|
      due_today = user.cash_installments.due_today
      next if due_today.none?

      user.subscriptions.each do |subscription|
        due_today.each do |cash_installment|
          body = "#{I18n.t('subscriptions.due_payment_notifier.body', count: 1)} - #{cash_installment.cash_transaction.description}"
          payload_send(title:, body:, url:, subscription:)
        end
      rescue WebPush::ExpiredSubscription, WebPush::PushServiceError => e
        puts "Subscription invalid: #{e.message}"
        subscription.destroy
      rescue StandardError => e
        Rails.logger.error("Push failed: #{e.message}")
      end
    end
  end

  def payload_send(title:, body:, url:, subscription:)
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
