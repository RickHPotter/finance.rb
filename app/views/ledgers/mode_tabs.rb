# frozen_string_literal: true

class Views::Ledgers::ModeTabs < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :kind, :cash_path, :card_path

  def initialize(kind:, cash_path:, card_path:)
    @kind = kind
    @cash_path = cash_path
    @card_path = card_path
  end

  def view_template
    nav(class: "mb-4 flex gap-2", aria: { label: I18n.t("ledgers.navigation.label") }) do
      tab(I18n.t("ledgers.navigation.cash"), cash_path, :cash)
      tab(I18n.t("ledgers.navigation.card"), card_path, :card)
    end
  end

  private

  def tab(label, path, tab_kind)
    active = kind == tab_kind
    link_to(
      label,
      path,
      class: "rounded-lg border px-4 py-2 text-sm font-semibold transition-colors #{tab_class(active)}",
      aria: { current: ("page" if active) },
      data: { turbo_frame: "_top", turbo_action: "replace" }
    )
  end

  def tab_class(active)
    return "border-sky-600 bg-sky-600 text-white dark:border-sky-400 dark:bg-sky-400 dark:text-slate-950" if active

    "border-slate-300 bg-white text-slate-700 hover:bg-slate-100 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
  end
end
