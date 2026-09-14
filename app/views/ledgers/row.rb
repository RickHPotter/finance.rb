# frozen_string_literal: true

class Views::Ledgers::Row < Views::Base
  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::ImageTag
  include TranslateHelper

  attr_reader :row

  def initialize(row:)
    @row = row
  end

  def view_template
    article(
      id: row.key,
      class: [ "rounded-xl border border-slate-200 bg-white shadow-sm dark:border-slate-800 dark:bg-slate-900", row.row_classes ].compact.join(" "),
      style: row.row_style
    ) do
      div(class: row_grid_classes) do
        description
        datum(I18n.t("ledgers.row.card"), row.user_card_name) if row.kind == :card
        datum(I18n.t("ledgers.row.date"), formatted_date)
        datum(I18n.t("ledgers.row.installment"), "#{row.number}/#{row.installments_count}")
        amount_and_state
      end
      allocations if row.internal?
    end
  end

  private

  def row_grid_classes
    columns = row.kind == :card ? "md:grid-cols-[minmax(0,1fr)_auto_auto_auto_auto]" : "md:grid-cols-[minmax(0,1fr)_auto_auto_auto]"
    "grid gap-3 p-4 #{columns}"
  end

  def description
    div(class: "min-w-0 text-left") do
      p(class: "text-xs font-semibold uppercase tracking-wide #{information_text_class}") { I18n.t("ledgers.row.description") }
      p(class: "mt-1 truncate font-semibold #{primary_text_class}") { row.description }
    end
  end

  def datum(label, value)
    div(class: "text-left md:text-right") do
      p(class: "text-xs font-semibold uppercase tracking-wide #{information_text_class}") { label }
      p(class: "mt-1 whitespace-nowrap text-sm #{primary_text_class}") { value }
    end
  end

  def amount_and_state
    div(class: "flex items-end justify-between gap-4 md:flex-col md:items-end md:justify-start") do
      span(class: "whitespace-nowrap font-bold #{primary_text_class}") { from_cent_based_to_float(row.amount, "R$") }
      span(class: state_class) { I18n.t(row.paid ? "ledgers.row.paid" : "ledgers.row.pending") }
    end
  end

  def allocations
    div(class: "flex flex-wrap items-center gap-2 border-t border-slate-100 px-4 py-3 dark:border-slate-800") do
      row.categories.each { |category| CategoryBadge(category:, class: "px-2 py-1 text-xs") }
      row.entities.each do |entity|
        span(class: "inline-flex items-center gap-1 rounded-full bg-slate-100 px-2 py-1 text-xs text-slate-700 dark:bg-slate-800 dark:text-slate-200") do
          image_tag(asset_path("avatars/#{entity.avatar_name}"), alt: "", class: "size-5 rounded-full bg-white object-cover")
          plain(entity.name)
        end
      end
    end
  end

  def formatted_date
    I18n.l(row.date, format: row.kind == :card ? "%B %Y" : :short)
  end

  def state_class
    base = "rounded-full px-2 py-0.5 text-xs font-semibold"
    colour = if row.paid
               "bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300"
             else
               "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300"
             end
    "#{base} #{colour}"
  end

  def primary_text_class
    return "text-current" if row.row_style.present?

    "text-slate-950 dark:text-white"
  end

  def information_text_class
    return "text-current opacity-70" if row.row_style.present?

    "text-slate-500 dark:text-slate-400"
  end
end
