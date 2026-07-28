# frozen_string_literal: true

class Views::HealthCheck::NamingConventions::Show < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo
  include TranslateHelper

  attr_reader :preview, :result

  def initialize(preview: nil, result: nil)
    raise ArgumentError, "provide one naming convention state" if preview.present? == result.present?

    @preview = preview
    @result = result
  end

  def view_template
    turbo_frame_tag "healthcheck_naming_convention_content" do
      div(class: "text-black dark:text-slate-100", data: tabs_data) do
        result_banner if result.present?
        p(class: "text-sm text-gray-700 dark:text-slate-300") { summary_text }
        changes
        actions
      end
    end
  end

  private

  def results
    preview&.results || result.results
  end

  def dry_run?
    preview.present?
  end

  def changed_results
    @changed_results ||= results.select { |entry| entry[:changes].present? }
  end

  def grouped_results
    @grouped_results ||= changed_results.group_by { |entry| entry[:convention] }
  end

  def tab_names
    grouped_results.keys
  end

  def tabs_data
    {
      controller: "lazy-tabs",
      lazy_tabs_current_value: tab_names.first
    }
  end

  def result_banner
    section(id: "healthcheck_naming_convention_result", class: result_banner_class) do
      h4(class: "font-bold") { I18n.t("health_check.naming_conventions.result.states.#{result.status}.title") }
      p(class: "mt-1 text-sm") { result_description }
      operation_link if result.operation_id.present?
    end
  end

  def operation_link
    link_to(
      I18n.t("health_check.naming_conventions.result.audit"),
      audit_operation_path(result.operation_id),
      class: "mt-3 inline-flex min-h-10 items-center rounded-md border border-current/30 px-3 py-2 text-sm font-bold",
      data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: false }
    )
  end

  def result_description
    return I18n.t("health_check.naming_conventions.did_update", count: result.changed_count) if result.applied? && result.changed_count.positive?
    return I18n.t("health_check.naming_conventions.no_changes_applied") if result.applied?

    I18n.t(
      "health_check.naming_conventions.result.reasons.#{result.reason_code}",
      default: I18n.t("health_check.naming_conventions.result.reasons.unexpected_failure")
    )
  end

  def result_banner_class
    base = "mb-4 rounded-md border p-4"
    return "#{base} border-emerald-300 bg-emerald-50 text-emerald-950 dark:border-emerald-800 dark:bg-emerald-950/30 dark:text-emerald-100" if result.applied?
    return "#{base} border-amber-300 bg-amber-50 text-amber-950 dark:border-amber-800 dark:bg-amber-950/30 dark:text-amber-100" if result.rejected?

    "#{base} border-rose-300 bg-rose-50 text-rose-950 dark:border-rose-800 dark:bg-rose-950/30 dark:text-rose-100"
  end

  def summary_text
    if changed_results.empty?
      dry_run? ? I18n.t("health_check.naming_conventions.no_changes_found") : I18n.t("health_check.naming_conventions.no_changes_applied")
    elsif dry_run?
      I18n.t("health_check.naming_conventions.will_update", count: changed_results.count)
    else
      I18n.t("health_check.naming_conventions.did_update", count: changed_results.count)
    end
  end

  def changes
    return if changed_results.empty?

    tabs
    panels
  end

  def tabs
    div(class: "mt-3 flex flex-wrap gap-2", role: "tablist") do
      grouped_results.each_key do |name|
        button(
          type: :button,
          role: :tab,
          class: "rounded-full bg-gray-200 px-3 py-1 text-sm font-semibold text-gray-700 transition-colors dark:bg-slate-800 dark:text-slate-200",
          data: { action: "click->lazy-tabs#select", lazy_tabs_target: "tab", lazy_tabs_name: name }
        ) { "#{convention_label(name)} (#{grouped_results[name].count})" }
      end
    end
  end

  def panels
    div(class: "mt-3 h-[min(26rem,55vh)] overflow-hidden rounded-lg border border-gray-400 bg-gray-200 dark:border-slate-700 dark:bg-slate-950") do
      grouped_results.each do |name, convention_results|
        div(
          class: "h-full overflow-y-auto hidden",
          role: :tabpanel,
          data: { lazy_tabs_target: "panel", lazy_tabs_name: name }
        ) do
          name == :exchange_return ? render_exchange_return_results(convention_results) : render_standard_results(convention_results)
        end
      end
    end
  end

  def actions
    div(class: "mt-3 flex flex-col gap-2 sm:flex-row sm:justify-between") do
      preview_form
      apply_form if dry_run? && changed_results.any?
    end
  end

  def preview_form
    form_with(
      url: preview_healthcheck_naming_convention_path,
      method: :post,
      data: { turbo_frame: "healthcheck_naming_convention_content" }
    ) do |form|
      form.submit(
        dry_run? ? I18n.t("health_check.naming_conventions.refresh_preview") : I18n.t("health_check.naming_conventions.preview_again"),
        class: secondary_button_class
      )
    end
  end

  def apply_form
    form_with(
      url: healthcheck_naming_convention_path,
      method: :patch,
      class: "rounded-md border border-rose-300 bg-rose-50 p-3 dark:border-rose-800 dark:bg-rose-950/30",
      data: { turbo_frame: "healthcheck_naming_convention_content" }
    ) do |form|
      form.hidden_field(:apply_token, value: preview.apply_token, id: "healthcheck_naming_convention_apply_token")
      label(class: "flex items-start gap-2 text-sm font-semibold text-rose-950 dark:text-rose-100") do
        form.check_box(:naming_confirmation, { class: "mt-0.5 size-4" }, "1", "0")
        span { I18n.t("health_check.naming_conventions.confirmation") }
      end
      form.submit(I18n.t("health_check.naming_conventions.apply"), class: "#{primary_button_class} mt-3")
    end
  end

  def record_label(entry)
    model_name = entry.dig(:record, :type).to_s.safe_constantize&.model_name&.human || entry.dig(:record, :type)
    "#{model_name} ##{entry.dig(:record, :id)}"
  end

  def render_standard_results(convention_results)
    ul(class: "divide-y divide-gray-200 dark:divide-slate-800") do
      convention_results.each do |entry|
        li(class: "px-3 py-2 text-sm") { render_result_diff(entry) }
      end
    end
  end

  def render_exchange_return_results(convention_results)
    grouped_exchange_results(convention_results).each_value do |exchange_results|
      exchange_metadata = exchange_results.first[:metadata] || {}
      card_transaction = exchange_metadata[:card_transaction] || {}

      div(class: "border-b border-gray-400 last:border-b-0 dark:border-slate-700") do
        div(class: "sticky top-0 z-10 border-b border-gray-400 bg-white/95 px-3 py-2 backdrop-blur-sm dark:border-slate-700 dark:bg-slate-900/95") do
          div(class: "text-sm font-semibold text-gray-900 dark:text-slate-100") do
            plain "#{I18n.t('health_check.naming_conventions.group.card_transaction')} ##{card_transaction[:id] || '-'}"
            plain " · #{card_transaction[:description]}" if card_transaction[:description].present?
          end
          div(class: "mt-1 text-xs text-gray-600 dark:text-slate-400") do
            plain "#{I18n.t('health_check.naming_conventions.group.installments_count')}: #{card_transaction[:installments_count] || '-'}"
            plain " · #{I18n.t('health_check.naming_conventions.group.exchanges_count')}: #{card_transaction[:exchanges_count] || '-'}"
            plain " · #{I18n.t('health_check.naming_conventions.group.entity')}: #{card_transaction[:entity_name] || '-'}"
          end
        end

        ul(class: "divide-y divide-gray-200 dark:divide-slate-800") do
          exchange_results.each do |entry|
            li(class: "px-3 py-2 text-sm") { render_result_diff(entry) }
          end
        end
      end
    end
  end

  def grouped_exchange_results(convention_results)
    convention_results.group_by { |entry| entry.dig(:metadata, :group_key) || "ungrouped" }
  end

  def render_result_diff(entry)
    div(class: "font-semibold text-gray-900 dark:text-slate-100") { record_label(entry) }
    div(class: "mt-1 text-red-700 line-through wrap-break-word dark:text-red-300") { entry.dig(:previous_attributes, :description) }
    div(class: "mt-1 text-green-700 wrap-break-word dark:text-emerald-300") { entry.dig(:changes, :description) }
  end

  def convention_label(name)
    I18n.t("health_check.naming_conventions.conventions.#{name}")
  end

  def primary_button_class
    "cursor-pointer rounded bg-green-600 px-4 py-2 font-bold text-white hover:bg-green-700"
  end

  def secondary_button_class
    "cursor-pointer rounded bg-gray-500 px-4 py-2 font-bold text-white hover:bg-gray-700"
  end
end
