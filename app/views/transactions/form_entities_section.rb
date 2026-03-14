# frozen_string_literal: true

class Views::Transactions::FormEntitiesSection < Views::Base
  attr_reader :form, :transaction

  def initialize(form:, transaction:)
    @form = form
    @transaction = transaction
  end

  def view_template
    div(id: "entities_nested", class: "flex gap-2 overflow-x-auto pb-3",
        data: { controller: "nested-form", nested_form_wrapper_selector_value: ".nested-form-wrapper" }) do
      template(data_nested_form_target: "template") do
        form.fields_for :entity_transactions, EntityTransaction.new, child_index: "NEW_RECORD" do |entity_transaction_fields|
          render Views::EntityTransactions::Fields.new(form: entity_transaction_fields)
        end
      end

      form.fields_for :entity_transactions, entity_transactions_association do |entity_transaction_fields|
        render Views::EntityTransactions::Fields.new(form: entity_transaction_fields)
      end

      div(data_nested_form_target: "target")

      button(type: :button, class: :hidden, tabindex: -1, data: { reactive_form_target: :addEntity, action: "nested-form#add" })
    end
  end

  private

  def entity_transactions_association
    transaction.entity_transactions.includes(:entity, :exchanges) if transaction.entity_transactions.count > 1
  end
end
