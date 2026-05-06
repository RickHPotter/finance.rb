# frozen_string_literal: true

class DuePaymentsNotifier
  def call
    users_to_notify.find_each do |user|
      installments = reminder_installments_for(user)
      next if installments.values_at(:overdue, :due_today).all?(&:empty?)

      I18n.locale = user.locale
      send_email_digest(user:, installments:)
      send_push_notifications(user:, installments:)
    end

    I18n.locale = I18n.default_locale
  end

  def payload_send(title:, body:, url:, push_subscription:, urgency: "normal")
    WebPush.payload_send(
      message: { title:, body:, url: }.to_json,
      endpoint: push_subscription.endpoint,
      p256dh: push_subscription.p256dh,
      auth: push_subscription.auth,
      vapid: {
        subject: "mailto:30fevfun@gmail.com",
        public_key: Rails.application.credentials.dig(:vapid, :public_key),
        private_key: Rails.application.credentials.dig(:vapid, :private_key)
      },
      urgency:
    )
  end

  private

  def users_to_notify
    first_user = User.order(:id).first
    return User.none if first_user.blank?

    User.where(id: first_user.id)
  end

  def reminder_installments_for(user)
    today = Time.zone.today
    tomorrow = today + 1.day
    scope = user.main_context.cash_installments.includes(cash_transaction: :user_bank_account).where(paid: false).order(:date, :id)

    {
      overdue: scope.where(date: ...today.beginning_of_day).to_a,
      due_today: scope.where(date: today.all_day).to_a,
      due_tomorrow: scope.where(date: tomorrow.all_day).to_a
    }
  end

  def send_email_digest(user:, installments:)
    PaymentReminderMailer.daily_digest(
      user:,
      overdue: installments[:overdue],
      due_today: installments[:due_today],
      due_tomorrow: installments[:due_tomorrow]
    ).deliver_now
  rescue StandardError => e
    Rails.logger.error("Payment reminder email failed for user #{user.id}: #{e.message}")
  end

  def send_push_notifications(user:, installments:)
    overdue = installments[:overdue]
    due_today = installments[:due_today]
    return if overdue.empty? && due_today.empty?

    title = I18n.t("push_subscriptions.due_payment_notifier.title")
    url = Rails.application.routes.url_helpers.root_url(host: Rails.env.production? ? "30fev.com" : "localhost")

    user.push_subscriptions.each do |push_subscription|
      if overdue.any?
        body = I18n.t("push_subscriptions.due_payment_notifier.overdue_body", count: overdue.size)
        payload_send(title:, body:, url:, push_subscription:, urgency: "high")
      end

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
end
