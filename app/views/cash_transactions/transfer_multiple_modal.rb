# frozen_string_literal: true

class Views::CashTransactions::TransferMultipleModal < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::SelectTag
  include Phlex::Rails::Helpers::OptionsForSelect

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper

  attr_reader :index_context, :modal_id

  def initialize(index_context:, modal_id: "transferMultipleModal")
    @index_context = index_context
    @modal_id = modal_id
  end

  def view_template
    ModalShell(id: modal_id, title: model_attribute(CashInstallment, :transfer_multiple)) do
      form_with(model: CashInstallment.new, url: transfer_multiple_cash_installments_path, method: :post) do |form|
        hidden_field_tag :ids, "", data: { bulk_ids_input: true }
        hidden_field_tag :index_context_json, index_context.to_json

        div(class: "mx-auto pb-4 text-center") do
          bold_label(form, :reference)

          options = (0..12).map do |i|
            date = Time.zone.now + i.months
            [ date.strftime("%b %y").upcase, date.strftime("%Y-%m") ]
          end

          div(class: "relative w-full") do
            select_tag(:reference_date, class: "border rounded w-full py-1") do
              options_for_select(options)
            end
          end
        end

        div(class: "mx-auto pb-4 text-center") do
          bold_label(form, :date)

          TextField \
            form, :date,
            type: "datetime-local",
            svg: :calendar,
            class: "font-graduate",
            value: Time.zone.now.strftime("%Y-%m-%dT%H:%M")
        end

        div(class: "grid grid-cols-2 gap-4 justify-between text-md") do
          form.submit I18n.t("confirmation.confirm"),
                      class: "bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded",
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
