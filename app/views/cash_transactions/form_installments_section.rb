# frozen_string_literal: true

class Views::CashTransactions::FormInstallmentsSection < Views::Base
  attr_reader :form, :cash_transaction

  def initialize(form:, cash_transaction:)
    @form = form
    @cash_transaction = cash_transaction
  end

  def view_template
    div(class: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 pb-3",
        data: { controller: "nested-form installment-lock", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
      template(data_nested_form_target: "template") do
        form.fields_for :cash_installments, CashInstallment.new, child_index: "NEW_RECORD" do |installment_fields|
          render Views::Installments::Fields.new(form: installment_fields)
        end
      end

      form.fields_for :cash_installments, ordered_cash_installments do |installment_fields|
        render Views::Installments::Fields.new(form: installment_fields)
      end

      div(data_nested_form_target: "target")

      button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addInstallment, action: "nested-form#add" })
    end
  end

  private

  def ordered_cash_installments
    if cash_transaction.new_record?
      cash_transaction.cash_installments
    elsif cash_transaction.edit_phase
      cash_transaction.cash_installments.sort_by(&:number)
    else
      cash_transaction.cash_installments.order(:number)
    end
  end
end
