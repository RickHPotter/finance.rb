# frozen_string_literal: true

class Views::Shared::IndexToolbar < Views::Base
  attr_reader :summary, :sort_options, :current_sort, :current_direction

  def initialize(summary:, sort_options:, current_sort:, current_direction:)
    @summary = summary
    @sort_options = sort_options
    @current_sort = current_sort
    @current_direction = current_direction
  end

  def view_template
    div(class: toolbar_class) do
      render Views::Shared::SortToolbar.new(
        title: I18n.t(:order),
        options: sort_options,
        current_sort:,
        current_direction:
      )

      render Views::Shared::FilterSummary.new(summary:) if summary[:active]
    end
  end

  private

  def toolbar_class
    return "mt-1" unless summary[:active]

    "mt-1 grid gap-3 lg:grid-cols-[minmax(0,1.6fr)_minmax(24rem,1fr)]"
  end
end
