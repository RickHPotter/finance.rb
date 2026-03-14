# frozen_string_literal: true

class Views::CardTransactions::FormInstallmentsSection < Views::Base
  attr_reader :form, :card_transaction

  def initialize(form:, card_transaction:)
    @form = form
    @card_transaction = card_transaction
  end

  def view_template
    div(class: "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3 pb-3",
        data: { controller: "nested-form installment-lock", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
      template(data_nested_form_target: "template") do
        form.fields_for :card_installments, CardInstallment.new, child_index: "NEW_RECORD" do |installment_fields|
          render Views::Installments::Fields.new(form: installment_fields)
        end
      end

      form.fields_for :card_installments, ordered_card_installments do |installment_fields|
        render Views::Installments::Fields.new(form: installment_fields)
      end

      div(data_nested_form_target: "target")

      button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addInstallment, action: "nested-form#add" })
    end
  end

  private

  def ordered_card_installments
    card_transaction.new_record? ? card_transaction.card_installments : card_transaction.card_installments.order(:number)
  end
end
