# frozen_string_literal: true

class Views::EntityTransactions::ExchangeStateSheet < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include CacheHelper

  attr_reader :entity_transaction, :trigger_text, :trigger_class

  def initialize(entity_transaction:, trigger_text:, trigger_class: nil)
    @entity_transaction = entity_transaction
    @trigger_text = trigger_text
    @trigger_class = trigger_class || default_trigger_class
  end

  def view_template
    return if exchanges.empty?

    div(data: { controller: "exchange-state-sheet" }) do
      Sheet do
        SheetTrigger do
          button(type: :button, class: trigger_class, data: { action: "click->exchange-state-sheet#elevate" }) do
            span(class: "inline-flex items-center gap-1") do
              span(class: "inline-flex shrink-0 items-center justify-center [&_svg]:size-3.5") do
                cached_icon(bound_type_icon_name)
              end

              span { trigger_text }
            end
          end
        end

        SheetContent(
          side: :middle,
          no_blur: true,
          class: "z-80 w-full md:w-1/3 max-h-[90vh] flex flex-col bg-white shadow-2xl",
          data: { action: "close->exchange-state-sheet#lower" }
        ) do
          SheetHeader do
            SheetTitle { entity_name }
            SheetDescription do
              div(class: "flex flex-wrap items-center gap-2 text-xs") do
                span(
                  class: "inline-flex items-center gap-1 rounded-full border border-zinc-300 bg-zinc-100 px-2 py-1 " \
                         "font-semibold uppercase tracking-wide text-zinc-700"
                ) do
                  span(class: "inline-flex shrink-0 items-center justify-center [&_svg]:size-3.5") { cached_icon(bound_type_icon_name) }
                  plain bound_type_label
                end

                span(class: "font-semibold text-zinc-700") { from_cent_based_to_float(entity_transaction.price_to_be_returned, "R$") }
                span { "#{exchanges.count}x" }
                span { transactable_description }
              end
            end
          end

          SheetMiddle(class: "overflow-y-auto flex-1") do
            div(class: "space-y-3") do
              exchanges.each do |exchange|
                render_exchange_row(exchange)
              end
            end
          end
        end
      end
    end
  end

  private

  def exchanges
    @exchanges ||= entity_transaction.exchanges.includes(:cash_transaction).order(:number, :date)
  end

  def entity_name
    entity_transaction.entity&.entity_name || model_attribute(EntityTransaction, :entity)
  end

  def transactable_description
    entity_transaction.transactable&.description.to_s
  end

  def bound_type_label
    I18n.t("activerecord.attributes.exchange.#{exchanges.first.bound_type}")
  end

  def bound_type_icon_name
    exchanges.first.card_bound? ? :credit_card : :refresh
  end

  def render_exchange_row(exchange)
    div(class: "rounded-lg border border-zinc-200 bg-white p-3 shadow-sm") do
      div(class: "flex items-center justify-between gap-3") do
        div(class: "flex items-center gap-2") do
          span(class: "rounded-full border border-zinc-300 bg-zinc-100 px-2 py-1 text-xs font-bold text-zinc-700") do
            "##{exchange.number}"
          end

          span(class: "text-sm font-semibold text-zinc-700") { exchange.month_year }
        end

        span(class: "text-sm font-semibold text-zinc-900") { from_cent_based_to_float(exchange.price, "R$") }
      end

      div(class: "mt-2 flex items-center justify-between gap-3 text-xs") do
        span { I18n.l(exchange.date, format: :short) }
        span(class: exchange.mirrored_paid? ? "font-semibold text-green-700" : "font-semibold text-orange-700") do
          exchange.mirrored_paid? ? I18n.t("filters.paid_state.paid") : I18n.t("filters.paid_state.pending")
        end
      end

      if exchange.cash_transaction.present?
        div(class: "mt-3") do
          link_to cash_transaction_path(exchange.cash_transaction),
                  class: "text-xs font-semibold underline underline-offset-[3px] text-zinc-700",
                  data: { turbo_frame: "_top", turbo_prefetch: false } do
            "Cash ##{exchange.cash_transaction_id} · #{exchange.cash_transaction.description}"
          end
        end
      end
    end
  end

  def default_trigger_class
    "text-left text-xs leading-tight text-zinc-900 underline underline-offset-[3px] hover:text-zinc-700"
  end
end
