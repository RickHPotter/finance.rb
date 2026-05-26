# frozen_string_literal: true

class Views::CashTransactions::Edit < Views::Base
  def initialize(current_user:, cash_transaction:)
    @current_user = current_user
    @cash_transaction = cash_transaction
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(
        badge_text: I18n.t("gerund.edit"),
        badge_class: form_badge_class(:edit),
        skeleton_view: Views::CashTransactions::FormSubmissionSkeleton
      ) do
        render Views::CashTransactions::Form.new(current_user: @current_user, cash_transaction: @cash_transaction)
      end
    end
  end
end
