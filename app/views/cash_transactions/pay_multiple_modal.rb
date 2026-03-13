# frozen_string_literal: true

class Views::CashTransactions::PayMultipleModal < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper

  attr_reader :index_context, :modal_id

  def initialize(index_context:, modal_id: "cashInstallmentsModal")
    @index_context = index_context
    @modal_id = modal_id
  end

  def view_template
    ModalShell(id: modal_id, title: model_attribute(CashInstallment, :confirm_payment)) do
      form_with(model: CashInstallment.new, url: pay_multiple_cash_installments_path, method: :post) do |form|
        hidden_field_tag :ids, "", data: { bulk_ids_input: true }
        hidden_field_tag :index_context_json, index_context.to_json

        div(class: "mx-auto pb-4 text-center") do
          bold_label(form, :payment_date)

          TextField \
            form, :date,
            type: "datetime-local",
            svg: :calendar,
            class: "font-graduate",
            max: Time.zone.now.end_of_day.strftime("%Y-%m-%dT%H:%M"),
            value: Time.zone.now.strftime("%Y-%m-%dT%H:%M")
        end

        div(class: "grid grid-cols-2 gap-4 justify-between text-md") do
          form.submit I18n.t("confirmation.confirm"),
                      class: "bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-4 rounded",
                      data: { modal_hide: modal_id }

          button(
            class: "ml-2 bg-gray-500 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded",
            type: :button,
            data: { modal_hide: modal_id }
          ) do
            I18n.t("confirmation.cancel")
          end
        end
      end
    end
  end
end
