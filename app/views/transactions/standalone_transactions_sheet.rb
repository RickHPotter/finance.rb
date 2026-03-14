# frozen_string_literal: true

class Views::Transactions::StandaloneTransactionsSheet < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include ColoursHelper

  attr_reader :transactions, :transaction_class

  def initialize(transactions:, transaction_class:)
    @transactions = transactions
    @transaction_class = transaction_class
  end

  def view_template
    div(class: "space-y-4") do
      div(class: "mb-5 mt-1") do
        span(class: "rounded-full border border-slate-300 bg-slate-100 px-4 py-1 text-sm font-bold uppercase tracking-wide text-slate-700") do
          I18n.t("activerecord.attributes.exchange.standalone")
        end
      end

      sorted_transactions.each do |transaction|
        div(class: "mb-8", data: { standalone_transaction_id: transaction.id }) do
          fieldset(class: "grid grid-cols-1 border border-slate-200 rounded-lg px-2 mb-4") do
            render Views::Shared::MonthYearHeader.new(
              month_year_str: transaction_range_label(transaction),
              total_amount: transaction.price,
              mobile: true
            )

            render_transaction_card(transaction)
          end
        end
      end
    end
  end

  private

  def sorted_transactions
    transactions.sort_by { |transaction| transaction_range(transaction).first }.reverse
  end

  def render_transaction_card(transaction)
    div(
      class: "rounded-lg shadow-sm overflow-hidden my-2 border-2 border-slate-200",
      style: "background-clip: padding-box; #{row_style(transaction)}"
    ) do
      div(class: "p-4") do
        div(class: "flex items-center justify-between gap-4 w-full text-sm font-semibold") do
          div(class: "flex-1 flex items-center justify-between gap-1 min-w-0") do
            link_to transaction.description,
                    edit_href(transaction),
                    class: "truncate text-md underline underline-offset-[3px]",
                    title: transaction.comment,
                    data: { turbo_frame: "_top", turbo_prefetch: false }

            span(class: "flex-shrink p-1 rounded-sm bg-white text-black border border-black #{'opacity-40' if transaction.installments_count == 1}") do
              pretty_installments(1, transaction.installments_count)
            end
          end
        end

        div(class: "flex items-center justify-between py-2") do
          span(class: "text-xs text-start flex-1") { I18n.l(transaction.date, format: :short) }

          div(class: "whitespace-nowrap") do
            from_cent_based_to_float(transaction.price, "R$")
          end
        end

        div(class: "flex flex-wrap items-center gap-1") do
          categories_for(transaction).each do |category|
            span(class: "px-2 py-1 flex items-center justify-center rounded-sm bg-transparent border border-black text-xs") do
              category.name
            end
          end

          render_mobile_entities(transaction)
        end
      end
    end
  end

  def render_mobile_entities(transaction)
    items = entity_popover_items(transaction)

    render Views::Entities::Popover.new(
      items:,
      mobile: true,
      target_ids: entity_transactions_for(transaction).map(&:entity_id),
      trigger_label: pluralise_model(Entity, items.count).upcase,
      variant: entity_variant
    )
  end

  def entity_popover_items(transaction)
    avatar_name = avatar_name_for(transaction)

    entity_transactions_for(transaction).map do |entity_transaction|
      entity = entity_transaction.entity

      {
        name: entity.entity_name,
        avatar_name: avatar_name || entity.avatar_name
      }
    end
  end

  def avatar_name_for(transaction)
    return unless transaction.is_a?(CashTransaction)
    return "others/card.png" if transaction.card_advance? || transaction.card_payment?
    return "others/bank.png" if transaction.investment?

    nil
  end

  def entity_variant
    transaction_class.name == "CardTransaction" ? :card : :cash
  end

  def transaction_range_label(transaction)
    start_date, end_date = transaction_range(transaction)
    start_label = I18n.l(start_date, format: "%B %Y")
    end_label = I18n.l(end_date, format: "%B %Y")

    return start_label if start_date == end_date

    "#{start_label} - #{end_label}"
  end

  def transaction_range(transaction)
    installments = transaction.installments
    return [ transaction.date.to_date.beginning_of_month, transaction.date.to_date.beginning_of_month ] if installments.blank?

    month_dates = installments.map { |installment| Date.new(installment.year, installment.month, 1) }
    month_dates.minmax
  end

  def row_style(transaction)
    solid_or_gradient_style(categories_for(transaction))
  end

  def categories_for(transaction)
    transaction.category_transactions.sort_by(&:id).filter_map(&:category)
  end

  def entity_transactions_for(transaction)
    transaction.entity_transactions.sort_by { |entity_transaction| entity_transaction.entity&.entity_name.to_s }
  end

  def edit_href(transaction)
    case transaction_class.name
    when "CardTransaction"
      edit_card_transaction_path(transaction)
    else
      edit_cash_transaction_path(transaction)
    end
  end
end
