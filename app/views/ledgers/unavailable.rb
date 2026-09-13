# frozen_string_literal: true

class Views::Ledgers::Unavailable < Views::Base
  def view_template
    section(class: "mx-auto mt-16 max-w-lg rounded-2xl border border-slate-200 bg-white px-6 py-12 text-center shadow-sm dark:border-slate-800 dark:bg-slate-900") do
      h1(class: "text-xl font-bold text-slate-950 dark:text-white") { I18n.t("ledgers.unavailable.title") }
      p(class: "mt-2 text-sm text-slate-600 dark:text-slate-300") { I18n.t("ledgers.unavailable.description") }
    end
  end
end
