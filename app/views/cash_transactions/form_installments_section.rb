# frozen_string_literal: true

class Views::CashTransactions::FormInstallmentsSection < Views::Base
  attr_reader :form, :cash_transaction

  def initialize(form:, cash_transaction:)
    @form = form
    @cash_transaction = cash_transaction
  end

  def view_template
    render Views::Installments::Section.new(
      form:,
      association_name: :cash_installments,
      installments: ordered_cash_installments,
      record_class: CashInstallment
    )
  end

  private

  def ordered_cash_installments
    if cash_transaction.new_record?
      cash_transaction.cash_installments
    elsif cash_transaction.edit_phase || cash_transaction.errors.any?
      cash_transaction.cash_installments.sort_by(&:number)
    else
      cash_transaction.cash_installments.order(:number)
    end
  end
end
