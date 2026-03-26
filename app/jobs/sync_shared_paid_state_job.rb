# frozen_string_literal: true

class SyncSharedPaidStateJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(cash_installment_id:, force_notify: false)
    installment = CashInstallment.find_by(id: cash_installment_id)
    return if installment.blank?
    return unless installment.send(:shared_paid_state_transaction?)

    Logic::SharedPaidStateSyncService.new(installment:, force_notify:).call
  end
end
