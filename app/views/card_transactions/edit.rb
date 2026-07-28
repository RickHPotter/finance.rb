# frozen_string_literal: true

class Views::CardTransactions::Edit < Views::Base
  def initialize(current_user:, card_transaction:, return_to: "/card_transactions")
    @current_user = current_user
    @card_transaction = card_transaction
    @return_to = return_to
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(
        badge_text: I18n.t("gerund.edit"),
        badge_class: form_badge_class(:edit),
        skeleton_view: Views::CardTransactions::FormSubmissionSkeleton
      ) do
        render Views::CardTransactions::Form.new(current_user: @current_user, card_transaction: @card_transaction, return_to: @return_to)
      end
    end
  end
end
