# frozen_string_literal: true

class Views::Transactions::CompositeBadge < Views::Base
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::ImageTag
  include TranslateHelper
  include CacheHelper
  include ComponentsHelper

  attr_reader :transaction, :installment

  def initialize(transaction:, installment: nil)
    @transaction = transaction
    @installment = installment
  end

  def view_template
    return unless transaction.composite?

    Popover(options: { placement: "bottom-start" }, class: "relative inline-flex shrink-0 z-40") do
      PopoverTrigger(class: "inline-flex items-center") do
        button(
          type: :button,
          class: trigger_button_classes,
          title: I18n.t("transactions.composite.breakdown_title"),
          data: {
            action: "click->datatable#stopPropagation mousedown->datatable#stopPropagation"
          }
        ) do
          cached_icon(:category)
        end
      end

      PopoverContent(class: popover_content_classes) do
        header_section
        table_header
        table_body
      end
    end
  end

  private

  def trigger_button_classes
    "inline-flex items-center justify-center text-inherit hover:opacity-75 " \
      "transition-opacity cursor-pointer shrink-0 [&_svg]:size-4 [&_svg]:stroke-[2.5]"
  end

  def popover_content_classes
    "z-60 opacity-100! p-0 w-[24rem] sm:w-[28rem] rounded-xl border " \
      "border-slate-200 bg-white text-slate-900 shadow-2xl " \
      "dark:border-slate-700/80 dark:bg-slate-900 dark:text-slate-100 overflow-hidden"
  end

  def header_section
    div(class: "flex items-center justify-between bg-slate-50 px-3 py-2 border-b border-slate-200 dark:bg-slate-800/60 dark:border-slate-700/60") do
      div(class: "flex items-center gap-1.5 [&_svg]:size-4 text-slate-600 dark:text-slate-400") do
        cached_icon(:category)
        p(class: "text-2xs font-bold uppercase tracking-wider") do
          I18n.t("transactions.composite.breakdown_title")
        end
      end
      span(class: "rounded-full bg-purple-500/10 px-2 py-0.5 text-2xs font-semibold text-purple-700 border border-purple-300 " \
                  "dark:bg-purple-500/20 dark:text-purple-300 dark:border-purple-500/30") do
        "#{line_items.size} #{I18n.t('activerecord.models.line_item.other').downcase}"
      end
    end
  end

  def table_header
    div(class: "grid grid-cols-12 bg-slate-100/80 px-3 py-1.5 text-2xs font-bold uppercase tracking-wider " \
               "text-slate-500 border-b border-slate-200 dark:bg-slate-800/40 dark:border-slate-700/60 dark:text-slate-400") do
      span(class: "col-span-5 text-left") { I18n.t("activerecord.attributes.line_item.description") }
      span(class: "col-span-3 text-left") { I18n.t("activerecord.attributes.line_item.category_id") }
      span(class: "col-span-2 text-left") { I18n.t("activerecord.attributes.line_item.entity_id") }
      span(class: "col-span-2 text-right") { I18n.t("activerecord.attributes.line_item.price") }
    end
  end

  def table_body
    div(class: "max-h-60 overflow-y-auto divide-y divide-slate-100 dark:divide-slate-800/60") do
      line_items.each do |item|
        render_item(item)
      end
    end
  end

  def render_item(item)
    category = item.categories.first
    entity = item.entities.first

    div(class: "grid grid-cols-12 items-center gap-1 px-3 py-2 text-xs hover:bg-slate-50/80 dark:hover:bg-slate-800/40 transition-colors") do
      div(class: "col-span-5 min-w-0 pr-1 text-left") do
        p(class: "font-semibold text-slate-800 dark:text-slate-200 truncate text-xs") { item.description }
        p(class: "text-2xs text-slate-400 truncate") { item.comment } if item.comment.present?
      end

      div(class: "col-span-3 min-w-0 pr-1 text-left") do
        if category.present?
          CategoryBadge(category:, class: "text-2xs truncate max-w-full")
        else
          span(class: "text-slate-400 text-2xs") { "-" }
        end
      end

      div(class: "col-span-2 min-w-0 pr-1 text-left") do
        if entity.present?
          span(class: "inline-flex items-center gap-1 text-2xs text-slate-600 dark:text-slate-400 truncate") do
            image_tag(asset_path("avatars/#{entity.avatar_name}"), class: "size-3.5 rounded-full shrink-0") if entity.avatar_name.present?
            span(class: "truncate") { entity.entity_name }
          end
        else
          span(class: "text-slate-400 text-2xs") { "-" }
        end
      end

      div(
        class: "col-span-2 text-right font-mono font-bold text-slate-800 dark:text-slate-100 text-xs shrink-0 whitespace-nowrap",
        title: item_price_title(item)
      ) do
        money(item_display_price(item))
      end
    end
  end

  def multi_installment?
    installment.present? && installments_count > 1
  end

  def installments_count
    if transaction.is_a?(CardTransaction)
      transaction.card_installments_count.to_i
    else
      transaction.cash_installments_count.to_i
    end
  end

  def item_display_price(item)
    if multi_installment?
      (item.price.to_d / installments_count).round
    else
      item.price
    end
  end

  def item_price_title(item)
    if multi_installment?
      "#{I18n.t('transactions.composite.parent_total')} #{money(item.price)}"
    else
      money(item.price)
    end
  end

  def line_items
    @line_items ||= transaction.line_items.includes(:categories, :entities).to_a
  end

  def money(value)
    from_cent_based_to_float(value, "R$")
  end
end
