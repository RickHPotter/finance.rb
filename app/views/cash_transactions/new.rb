# frozen_string_literal: true

class Views::CashTransactions::New < Views::Base
  def initialize(current_user:, cash_transaction:, chain_context: nil)
    @current_user = current_user
    @cash_transaction = cash_transaction
    @chain_context = chain_context
  end

  def view_template
    turbo_frame_tag :center_container do
      render Views::Shared::FormShell.new(
        badge_text:,
        badge_class:,
        skeleton_view: Views::CashTransactions::FormSubmissionSkeleton
      ) do
        render Views::CashTransactions::Form.new(current_user: @current_user, cash_transaction: @cash_transaction, chain_context: @chain_context)
      end
    end
  end

  private

  def badge_text
    if @chain_context&.dig(:record_ids)&.any?
      I18n.t(@cash_transaction.duplicate ? "gerund.chain_duplicate" : "gerund.chain_create")
    elsif @cash_transaction.duplicate
      I18n.t("gerund.duplicate")
    else
      I18n.t("gerund.new")
    end
  end

  def badge_class
    return form_badge_class(:duplicate) if @cash_transaction.duplicate

    form_badge_class(:new)
  end
end
