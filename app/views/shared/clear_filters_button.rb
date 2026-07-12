# frozen_string_literal: true

class Views::Shared::ClearFiltersButton < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :href

  def initialize(href:)
    @href = href
  end

  def view_template
    link_to(
      I18n.t("filters.summary.clear"),
      href,
      class: button_class,
      data: { turbo_frame: "_top", turbo_prefetch: false }
    )
  end

  private

  def button_class
    "inline-flex h-10 items-center justify-center rounded-md border border-sky-400 bg-white px-4 py-2 text-[11px] " \
      "font-semibold uppercase tracking-[0.14em] text-sky-800 transition hover:border-sky-600 hover:text-sky-950 " \
      "dark:border-slate-700 dark:bg-slate-800 dark:text-slate-200 dark:hover:border-sky-500/60 dark:hover:bg-slate-700 dark:hover:text-slate-100"
  end
end
