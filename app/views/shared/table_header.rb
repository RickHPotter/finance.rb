# frozen_string_literal: true

class Views::Shared::TableHeader < Views::Base
  attr_reader :grid_class, :rows

  def initialize(grid_class:, rows:)
    @grid_class = grid_class
    @rows = rows
  end

  def view_template
    div(class: "rounded-t-lg border-b border-slate-400 bg-slate-200") do
      rows.each_with_index do |cells, index|
        div(class: row_class(index)) do
          cells.each do |cell|
            div(class: cell.fetch(:class)) do
              render_label(cell)
            end
          end
        end
      end
    end
  end

  private

  def row_class(index)
    divider = index < rows.size - 1 ? "border-b border-slate-300" : ""

    "#{grid_class} gap-x-3 px-3 py-3 text-black font-graduate #{divider}".squish
  end

  def render_label(cell)
    return if cell[:label].blank?

    span(class: label_class(cell[:align] || :left)) { cell[:label] }
  end

  def label_class(align)
    alignment =
      case align
      when :center then "text-center mx-auto"
      when :right then "text-right ml-auto"
      else ""
      end

    "block text-[11px] font-semibold uppercase tracking-[0.22em] text-slate-600 #{alignment}".squish
  end
end
