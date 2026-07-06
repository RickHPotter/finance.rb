# frozen_string_literal: true

class Views::Subscriptions::CardTransactionFields < Views::Base
  include CacheHelper
  include TranslateHelper

  attr_reader :form, :user_cards, :card_transaction

  def initialize(form:, user_cards:)
    @form = form
    @user_cards = user_cards
    @card_transaction = form.object
  end

  def view_template
    div(
      class: wrapper_class,
      data: {
        new_record: card_transaction.new_record?,
        transaction_type: :card,
        sort_month_year:,
        sort_date:,
        sort_description: card_transaction.description.to_s.downcase
      }
    ) do
      form.hidden_field :date
      form.hidden_field :month
      form.hidden_field :year
      form.hidden_field :user_card_id
      form.hidden_field :price, data: { subscription_transactions_target: "transactionPriceInput" }

      div(class: "flex items-start justify-between gap-3") do
        div(class: "min-w-0 flex-1") do
          p(class: "text-xs font-semibold uppercase tracking-wide text-orange-700 dark:text-orange-300", data: { role: "ref-month-year-display" }) { ref_month_year }
          p(class: "text-sm font-semibold text-slate-900 dark:text-slate-100", data: { role: "date-display" }) { formatted_date }
        end

        div(class: "min-w-0 flex-1") do
          p(class: "truncate text-sm text-slate-600 dark:text-slate-300", data: { role: "card-display" }) { card_name }
          p(class: "text-sm font-semibold text-slate-800 dark:text-slate-100", data: { role: "price-display" }) { formatted_price }
        end

        div(class: "flex items-center gap-1") do
          button(
            type: :button,
            class: action_button_class,
            title: action_message(:edit),
            aria: { label: action_message(:edit) },
            data: { action: "subscription-transactions#editRow" }
          ) { cached_icon(:pencil) }

          button(
            type: :button,
            class: destructive_action_button_class,
            title: action_message(:destroy),
            aria: { label: action_message(:destroy) },
            data: { action: "subscription-transactions#removeRow nested-form#remove" }
          ) { cached_icon(:destroy) }
        end
      end

      form.hidden_field :id if card_transaction.persisted?
      form.hidden_field :_destroy
    end
  end

  private

  def wrapper_class
    [
      "nested-form-wrapper rounded-lg border border-orange-200 bg-orange-50 p-2 dark:border-orange-500/40 dark:bg-orange-950/30",
      ("hidden" if card_transaction.marked_for_destruction?)
    ].compact.join(" ")
  end

  def action_button_class
    "inline-flex size-6 items-center justify-center rounded-sm border border-sky-200 bg-sky-50 text-sky-700 " \
      "shadow-sm transition hover:border-sky-600 hover:bg-sky-600 hover:text-white dark:border-slate-600 dark:bg-slate-900 " \
      "dark:text-sky-300 dark:hover:border-sky-500 dark:hover:bg-slate-800 [&_svg]:size-4"
  end

  def destructive_action_button_class
    "#{action_button_class} border-red-200 text-red-700 hover:border-red-600 hover:bg-red-600 hover:text-white [&_svg]:!text-current"
  end

  def card_name
    user_cards.find { |(_, id)| id == card_transaction.user_card_id }&.first || model_attribute(CardTransaction, :user_card_id)
  end

  def formatted_date
    card_transaction.date.present? ? I18n.l(card_transaction.date.to_date, format: :long).upcase : "-"
  end

  def formatted_price
    from_cent_based_to_float(card_transaction.price.to_i, "R$")
  end

  def ref_month_year
    card_transaction.month.present? ? card_transaction.month_year : "-"
  end

  def sort_month_year
    [ card_transaction.year.to_i.to_s.rjust(4, "0"), card_transaction.month.to_i.to_s.rjust(2, "0") ].join("-")
  end

  def sort_date
    card_transaction.date&.to_date&.strftime("%Y-%m-%d")
  end
end
