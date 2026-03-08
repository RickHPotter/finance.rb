# frozen_string_literal: true

class Views::V1::CashTransactions::TransferMultipleModal < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::SelectTag
  include Phlex::Rails::Helpers::OptionsForSelect

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper

  attr_reader :cash_installments

  def initialize(cash_installments:)
    @cash_installments = cash_installments
  end

  def view_template
    div(
      id: "transferMultipleModal",
      class: "hidden overflow-y-auto overflow-x-hidden fixed top-0 right-0 left-0 z-50 justify-center items-center w-full md:inset-0 h-[calc(100%-1rem)]",
      tabindex: "-1"
    ) do
      div(class: "bg-white p-6 rounded-lg shadow-lg") do
        div(class: "flex") do
          h1(class: "text-2xl mb-4 flex-1 text-start") { model_attribute(CashInstallment, :transfer_multiple) }

          button(
            type: :button,
            class: "text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm w-8 h-8 ms-auto inline-flex justify-center items-center",
            data: { modal_hide: "transferMultipleModal" }
          ) do
            cached_icon(:little_x)
            span(class: "sr-only") { "Close modal" }
          end
        end

        form_with(model: CashInstallment.new, url: v1_transfer_multiple_cash_installments_path(ids: cash_installments.pluck(:id)), method: :post) do |form|
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
                        data: { modal_hide: "transferMultipleModal" }

            button(
              class: "ml-2 bg-gray-500 hover:bg-gray-700 text-white font-bold py-2 px-4 rounded",
              type: :button,
              data: { modal_hide: "transferMultipleModal" }
            ) do
              I18n.t("confirmation.cancel")
            end
          end
        end
      end
    end
  end
end
