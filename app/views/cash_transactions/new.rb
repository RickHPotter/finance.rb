# frozen_string_literal: true

class Views::CashTransactions::New < Views::Base
  def initialize(current_user:, cash_transaction:, chain_context: nil)
    @current_user = current_user
    @cash_transaction = cash_transaction
    @chain_context = chain_context
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "bg-white p-4 shadow-md rounded-lg") do
        span(class: badge_class) { badge_text }

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
    base = "rounded-sm border border-1 px-3 shadow-md"
    return "#{base} border-orange-400 bg-orange-200" if @cash_transaction.duplicate
    return "#{base} border-cyan-500 bg-cyan-200" if @chain_context&.dig(:record_ids)&.any?

    "#{base} border-sky-400 bg-sky-200"
  end
end
