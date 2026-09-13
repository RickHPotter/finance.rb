# frozen_string_literal: true

class Views::Ledgers::EmptyState < Views::Base
  def view_template
    div(class: "rounded-xl border border-dashed border-slate-300 bg-slate-50 px-4 py-10 text-center dark:border-slate-700 dark:bg-slate-950") do
      p(class: "font-semibold text-slate-700 dark:text-slate-200") { I18n.t("ledgers.empty.title") }
      p(class: "mt-1 text-sm text-slate-500 dark:text-slate-400") { I18n.t("ledgers.empty.description") }
    end
  end
end
