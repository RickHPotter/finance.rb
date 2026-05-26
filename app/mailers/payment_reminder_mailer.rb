# frozen_string_literal: true

class PaymentReminderMailer < ApplicationMailer
  helper ActionView::Helpers::NumberHelper

  def daily_digest(user:, overdue:, due_today:, due_tomorrow:, date: Time.zone.today)
    @user = user
    @date = date
    @overdue = overdue
    @due_today = due_today
    @due_tomorrow = due_tomorrow
    @installments = {
      overdue: @overdue,
      due_today: @due_today,
      due_tomorrow: @due_tomorrow
    }

    I18n.with_locale(user.locale.presence || I18n.default_locale) do
      mail(to: user.email, subject: I18n.t("payment_reminder_mailer.daily_digest.subject", date: I18n.l(@date, format: :long)))
    end
  end
end
