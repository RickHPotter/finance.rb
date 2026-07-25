# frozen_string_literal: true

class Views::HealthCheck::Repairs::Show < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :entry, :result, :workspace_scope

  def initialize(entry:, result:, workspace_scope:)
    @entry = entry
    @result = result
    @workspace_scope = workspace_scope
  end

  def view_template
    turbo_frame_tag "center_container" do
      main(class: "w-full px-2 py-2 sm:px-3") do
        section(id: "health_check_repair_result", class: result_panel_class) do
          p(class: "text-xs font-semibold uppercase tracking-[0.18em]") { I18n.t("health_check.repairs.result.eyebrow") }
          h1(class: "mt-2 text-2xl font-bold") { I18n.t("health_check.repairs.result.states.#{result.status}.title") }
          p(class: "mt-2 text-sm") { result_description }

          operation_details if result.operation_id.present?
          action_links
        end
      end
    end
  end

  private

  def operation_details
    dl(class: "mt-3 grid gap-2 rounded-md border border-current/20 p-3 sm:grid-cols-2") do
      metadata(I18n.t("health_check.repairs.result.operation"), result.operation_id)
      metadata(I18n.t("health_check.repairs.result.changed"), result.changed_count)
      metadata(I18n.t("health_check.repairs.result.rerun"), rerun_label)
      metadata(I18n.t("health_check.repairs.result.duplicate"), I18n.t("health_check.repairs.result.boolean.#{result.duplicate?}"))
    end
  end

  def action_links
    div(class: "mt-3 flex flex-wrap gap-2") do
      link_to(
        I18n.t("health_check.repairs.result.back"),
        healthcheck_check_path(entry.key, **workspace_scope_query),
        class: secondary_button_class,
        data: { turbo_frame: "center_container", turbo_prefetch: false }
      )
      if result.operation_id.present?
        link_to(
          I18n.t("health_check.repairs.result.audit"),
          audit_operation_path(result.operation_id),
          class: primary_button_class,
          data: { turbo_frame: "_top", turbo_prefetch: false }
        )
      end
    end
  end

  def metadata(label, value)
    div(class: "min-w-0") do
      dt(class: "text-2xs font-semibold uppercase tracking-[0.1em] opacity-70") { label }
      dd(class: "mt-1 wrap-break-word text-sm font-semibold") { value.to_s }
    end
  end

  def result_description
    if result.applied?
      I18n.t("health_check.repairs.result.states.applied.description")
    else
      I18n.t(
        "health_check.repairs.result.reasons.#{result.reason_code}",
        default: I18n.t("health_check.repairs.result.reasons.unexpected_failure")
      )
    end
  end

  def rerun_label
    return I18n.t("health_check.repairs.result.rerun_unavailable") if result.rerun_reason.blank?

    I18n.t("health_check.repairs.result.rerun_#{result.rerun_reason}")
  end

  def workspace_scope_query
    return {} if workspace_scope.all_connections?

    { connected_user_id: workspace_scope.connected_user.id }
  end

  def result_panel_class
    base = "rounded-lg border p-3"
    return "#{base} border-emerald-300 bg-emerald-50 text-emerald-950 dark:border-emerald-800 dark:bg-emerald-950/30 dark:text-emerald-100" if result.applied?
    return "#{base} border-amber-300 bg-amber-50 text-amber-950 dark:border-amber-800 dark:bg-amber-950/30 dark:text-amber-100" if result.rejected?

    "#{base} border-rose-300 bg-rose-50 text-rose-950 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-100"
  end

  def primary_button_class
    "inline-flex min-h-10 items-center justify-center rounded-md bg-sky-700 px-4 py-2 text-sm font-bold text-white hover:bg-sky-800"
  end

  def secondary_button_class
    "inline-flex min-h-10 items-center justify-center rounded-md border border-current/30 px-4 py-2 text-sm font-bold hover:bg-black/5 dark:hover:bg-white/5"
  end
end
