# frozen_string_literal: true

class Views::Transactions::CompositeBadge < Views::Base
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
    return unless transaction.composite?

    Popover(options: { placement: "bottom-start" }, class: "relative inline-flex shrink-0 z-40") do
      PopoverTrigger(class: "inline-flex items-center") do
        button(
          type: :button,
          class: badge_classes,
          title: I18n.t("transactions.composite.breakdown_title"),
          data: {
            action: "click->datatable#stopPropagation mousedown->datatable#stopPropagation"
          }
        ) do
          cached_icon(:category)
          span { I18n.t("transactions.composite.badge", count: line_items.size) }
        end
      end

      PopoverContent(class: "z-60 opacity-100! p-0 w-72 rounded-xl border border-slate-700/80 bg-slate-900 shadow-2xl text-slate-100 overflow-hidden") do
        div(class: "flex items-center justify-between bg-slate-800/60 px-3 py-2 border-b border-slate-700/60") do
          p(class: "text-2xs font-bold uppercase tracking-wider text-slate-400") do
            I18n.t("transactions.composite.breakdown_title")
          end
          span(class: "rounded-full bg-purple-500/20 px-2 py-0.5 text-2xs font-semibold text-purple-300 border border-purple-500/30") do
            "#{line_items.size}×"
          end
        end

        div(class: "max-h-56 overflow-y-auto divide-y divide-slate-700/40") do
          line_items.each do |item|
            render_item(item)
          end
        end

        div(class: "flex items-center justify-between bg-slate-800/40 px-3 py-2 border-t border-slate-700/60 text-xs font-bold") do
          span(class: "text-slate-400") { I18n.t("transactions.composite.parent_total") }
          span(class: "font-mono text-slate-100") { money(transaction.price) }
        end
      end
    end
  end

  private

  def badge_classes
    "inline-flex items-center gap-1 rounded-sm px-1.5 py-0.5 text-2xs font-bold uppercase tracking-wide " \
      "bg-purple-500/20 text-purple-300 border border-purple-500/40 hover:bg-purple-500/30 transition-colors cursor-pointer"
  end

  def render_item(item)
    category = item.categories.first
    entity = item.entities.first

    div(class: "flex items-start justify-between gap-3 px-3 py-2 text-xs") do
      div(class: "min-w-0 flex-1 space-y-1") do
        p(class: "font-semibold text-slate-200 truncate") { item.description }
        div(class: "flex flex-wrap items-center gap-1") do
          CategoryBadge(category:, class: "text-2xs") if category.present?
          if entity.present?
            span(class: "inline-flex items-center gap-1 text-2xs text-slate-400") do
              image_tag(asset_path("avatars/#{entity.avatar_name}"), class: "h-3.5 w-3.5 rounded-full") if entity.avatar_name.present?
              plain entity.entity_name
            end
          end
        end
      end

      span(class: "font-mono font-bold text-slate-100 shrink-0 pt-0.5") { money(item.price) }
    end
  end

  def line_items
    @line_items ||= transaction.line_items.includes(:categories, :entities).to_a
  end

  def money(value)
    from_cent_based_to_float(value, "R$")
  end
end
