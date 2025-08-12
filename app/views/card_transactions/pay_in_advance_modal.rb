# frozen_string_literal: true

class Views::CardTransactions::PayInAdvanceModal < Views::Base
  include Phlex::Rails::Helpers::FormWith

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper

  attr_reader :month, :year, :user_card_id, :min_date, :max_date

  def initialize(month:, year:, user_card_id:, min_date:, max_date:)
    @month = month
    @year = year
    @user_card_id = user_card_id
    @min_date = min_date
    @max_date = max_date
  end

  def view_template
    modal_id = "cardTransactionModal_#{user_card_id}_#{month}_#{year}"
    if min_date.present? && max_date.present? && Time.zone.now.between?(Time.zone.parse(min_date), Time.zone.parse(max_date))
      Time.zone.now.strftime("%Y-%m-%dT%H:%M")
    else
      max_date
    end => default_date

    div(
      id: modal_id,
      class: "hidden overflow-y-auto overflow-x-hidden fixed top-0 right-0 left-0 z-50 justify-center items-center w-full md:inset-0 h-[calc(100%-1rem)]",
      tabindex: "-1"
    ) do
      div(class: "bg-white p-6 rounded-lg shadow-lg") do
        div(class: "flex") do
          h1(class: "text-2xl mb-4 flex-1 text-start") { model_attribute(CardTransaction, :confirm_payment) }

          button(
            type: :button,
            class: "text-gray-400 bg-transparent hover:bg-gray-200 hover:text-gray-900 rounded-lg text-sm w-8 h-8 ms-auto inline-flex justify-center items-center",
            data: { modal_hide: modal_id }
          ) do
            cached_icon(:little_x)

            span(class: "sr-only") do
              "Close modal"
            end
          end
        end
        form_with(
          model: CardTransaction.new,
          url: pay_in_advance_card_transactions_path,
          data: { controller: "price-mask", action: "submit->price-mask#removeMasks" }
        ) do |form|
          TextField form, :month, class: :hidden, value: month
          TextField form, :year, class: :hidden, value: year
          TextField form, :user_card_id, class: :hidden, value: user_card_id

          div(class: "mx-auto pb-4 text-center") do
            bold_label(form, :date)

            TextField \
              form, :date,
              type: "datetime-local",
              svg: :calendar,
              class: "font-graduate",
              min: min_date,
              max: max_date,
              value: default_date
          end

          div(class: "mx-auto pb-4 text-center") do
            bold_label(form, :price)

            TextField \
              form, :price,
              svg: :money,
              id: :transaction_price,
              class: "font-graduate",
              data: { price_mask_target: :input, action: "input->price-mask#applyMask" }
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
end
