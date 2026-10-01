# frozen_string_literal: true

class Views::Transactions::ShowLineItemsSection < Views::Base
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::ImageTag
  include TranslateHelper
  include CacheHelper
  include ComponentsHelper

  attr_reader :transaction

  def initialize(transaction:)
    @transaction = transaction
  end

  def view_template
    section_card(I18n.t("transactions.composite.breakdown")) do
      if mobile?
        render_mobile_cards
      else
        render_desktop_table
      end
    end
  end

  private

  def section_card(title, &)
    section(
      class: "rounded-2xl border border-slate-200 bg-slate-50/80 p-3 dark:border-slate-700 dark:bg-slate-950/70 sm:rounded-3xl sm:p-4",
      data: { controller: "show-section-card", show_section_card_open_value: true }
    ) do
      button(
        type: :button,
        class: "flex w-full items-center justify-between gap-3 text-left",
        data: { action: "show-section-card#toggle", show_section_card_target: "button" }
      ) do
        h2(class: "text-xs font-black uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400") { title }
        span(class: "text-lg font-semibold leading-none text-slate-500 dark:text-slate-400", data: { show_section_card_target: "icon" }) { "−" }
      end

      div(class: "mt-4", data: { show_section_card_target: "content" }, &)
    end
  end

  def render_desktop_table
    div(class: "overflow-hidden rounded-xl border border-slate-200 dark:border-slate-700/80") do
      div(class: "grid grid-cols-12 bg-slate-950/90 px-4 py-2.5 text-2xs font-bold uppercase tracking-[0.16em] text-slate-400") do
        span(class: "col-span-4") { I18n.t("activerecord.attributes.line_item.description") }
        span(class: "col-span-3") { I18n.t("activerecord.attributes.line_item.category_id") }
        span(class: "col-span-2") { I18n.t("activerecord.attributes.line_item.entity_id") }
        span(class: "col-span-2 text-right") { I18n.t("activerecord.attributes.line_item.price") }
        span(class: "col-span-1 text-right") { I18n.t("transactions.composite.percentage") }
      end

      line_items.each do |item|
        render_desktop_row(item)
      end
    end
  end

  def render_desktop_row(item)
    category = item.categories.first
    entity = item.entities.first

    div(class: "grid grid-cols-12 items-center border-t border-slate-200 px-4 py-2.5 text-sm dark:border-slate-800 bg-white dark:bg-slate-900") do
      div(class: "col-span-4 min-w-0 pr-2") do
        p(class: "font-semibold text-slate-950 dark:text-slate-100 truncate") { item.description }
        p(class: "text-xs text-slate-500 dark:text-slate-400 truncate") { item.comment } if item.comment.present?
      end

      div(class: "col-span-3 min-w-0 pr-2") do
        if category.present?
          CategoryBadge(category:, class: "truncate max-w-full text-xs")
        else
          span(class: "text-slate-400 text-xs") { "-" }
        end
      end

      div(class: "col-span-2 min-w-0 pr-2") do
        if entity.present?
          render_entity_chip(entity)
        else
          span(class: "text-slate-400 text-xs") { "-" }
        end
      end

      span(class: "col-span-2 text-right font-mono font-bold text-slate-950 dark:text-slate-100") do
        money(item.price)
      end

      span(class: "col-span-1 text-right font-mono text-xs text-slate-500 dark:text-slate-400") do
        percentage_of_total(item)
      end
    end
  end

  def render_mobile_cards
    div(class: "space-y-3") do
      line_items.each do |item|
        render_mobile_card(item)
      end
    end
  end

  def render_mobile_card(item)
    category = item.categories.first
    entity = item.entities.first

    div(class: "rounded-xl border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-900") do
      div(class: "flex items-start justify-between gap-2") do
        div(class: "min-w-0 flex-1") do
          p(class: "font-semibold text-slate-950 dark:text-slate-100 truncate text-sm") { item.description }
          p(class: "text-xs text-slate-500 dark:text-slate-400 truncate mt-0.5") { item.comment } if item.comment.present?
        end

        div(class: "shrink-0 text-right") do
          p(class: "font-mono font-bold text-slate-950 dark:text-slate-100 text-sm") { money(item.price) }
          p(class: "font-mono text-2xs text-slate-500 dark:text-slate-400") { percentage_of_total(item) }
        end
      end

      div(class: "mt-2.5 flex flex-wrap items-center gap-2 border-t border-slate-100 pt-2.5 dark:border-slate-800") do
        CategoryBadge(category:, class: "text-xs") if category.present?
        render_entity_chip(entity) if entity.present?
      end
    end
  end

  def render_entity_chip(entity)
    div(class: "inline-flex items-center gap-1.5 rounded-full border border-slate-300 bg-slate-100/80 px-2 py-0.5 text-xs text-slate-800 " \
               "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200") do
      image_tag(asset_path("avatars/#{entity.avatar_name}"), class: "h-4 w-4 rounded-full") if entity.avatar_name.present?
      span(class: "truncate") { entity.entity_name }
    end
  end

  def line_items
    @line_items ||= transaction.line_items.includes(:categories, :entities).to_a
  end

  def percentage_of_total(item)
    return "0.0%" if transaction.price.to_i.zero?

    pct = (item.price.to_f / transaction.price * 100).round(1)
    "#{pct}%"
  end

  def money(value)
    from_cent_based_to_float(value, "R$")
  end
end
