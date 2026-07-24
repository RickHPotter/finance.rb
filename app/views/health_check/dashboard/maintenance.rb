# frozen_string_literal: true

class Views::HealthCheck::Dashboard::Maintenance < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  def view_template
    section(aria: { labelledby: "health_check_maintenance_title" }, class: "py-6") do
      h2(id: "health_check_maintenance_title", class: "text-lg font-bold text-slate-950 dark:text-slate-100") do
        I18n.t("health_check.maintenance.title")
      end
      p(class: "mt-1 max-w-3xl text-sm text-slate-600 dark:text-slate-400") { I18n.t("health_check.maintenance.description") }

      article(class: "mt-4 rounded-lg border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-900") do
        h3(class: "font-bold text-slate-950 dark:text-slate-100") { I18n.t("health_check.maintenance.naming.title") }
        p(class: "mt-1 text-sm text-slate-600 dark:text-slate-400") { I18n.t("health_check.maintenance.naming.description") }
        link_to(
          I18n.t("health_check.maintenance.naming.action"),
          preview_naming_convention_path,
          class: naming_link_class,
          data: { turbo_frame: "naming_convention_content", turbo_prefetch: false }
        )
        turbo_frame_tag "naming_convention_content", class: "mt-4 block"
      end
    end
  end

  private

  def naming_link_class
    "mt-3 inline-flex min-h-10 items-center justify-center rounded-md border border-sky-300 bg-sky-50 px-4 py-2 text-sm font-semibold text-sky-800 " \
      "hover:bg-sky-100 dark:border-sky-800 dark:bg-sky-950/40 dark:text-sky-200 dark:hover:bg-sky-900/50"
  end
end
