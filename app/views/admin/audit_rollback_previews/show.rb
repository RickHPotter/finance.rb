# frozen_string_literal: true

class Views::Admin::AuditRollbackPreviews::Show < Views::Base
  LINK_CLASS = "inline-flex min-h-10 items-center justify-center rounded-md border border-slate-300 px-4 py-2 text-sm font-semibold " \
               "text-slate-700 hover:bg-slate-100 dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800"

  include Phlex::Rails::Helpers::LinkTo

  attr_reader :preview

  def initialize(preview:)
    @preview = preview
  end

  def view_template
    turbo_frame_tag :center_container do
      main(class: "mx-auto w-full max-w-7xl px-3 py-4 sm:px-5") do
        header_section
        preview_summary
        global_issues
        preview_rows
        input(type: :hidden, id: "audit_rollback_apply_token", value: preview.apply_token)
      end
    end
  end

  private

  def header_section
    header(class: "flex flex-col gap-4 border-b border-slate-200 pb-5 sm:flex-row sm:items-end sm:justify-between dark:border-slate-700") do
      div(class: "min-w-0") do
        p(class: "text-xs font-semibold uppercase text-sky-700 dark:text-sky-300") { I18n.t("audit.rollback.preview") }
        h1(class: "mt-1 wrap-break-word font-mono text-lg font-bold text-slate-950 sm:text-xl dark:text-slate-100") { preview.operation.id }
      end
      link_to(I18n.t("navigation.back"), audit_operation_path(preview.operation), class: LINK_CLASS)
    end
  end

  def preview_summary
    section(class: "grid gap-3 border-b border-slate-200 py-5 sm:grid-cols-2 xl:grid-cols-4 dark:border-slate-700") do
      summary_value(I18n.t("audit.rollback.fields.state"), I18n.t("audit.rollback.states.#{preview.state}"))
      summary_value(I18n.t("audit.rollback.fields.records"), preview.rows.size)
      summary_value(I18n.t("audit.rollback.fields.owners"), preview.affected_owner_ids.join(", "))
      summary_value(I18n.t("audit.rollback.fields.contexts"), preview.affected_context_ids.join(", "))
      summary_value(I18n.t("audit.fields.actor_id"), preview.operation.actor_id || I18n.t("audit.values.empty"))
      summary_value(I18n.t("audit.fields.source"), I18n.t("audit.sources.#{preview.operation.source}"))
      summary_value(I18n.t("audit.rollback.fields.confirmation"), I18n.t("audit.values.#{preview.confirmation_required?}"))
      div(class: "min-w-0") do
        p(class: "text-xs font-semibold uppercase text-slate-500 dark:text-slate-400") { I18n.t("audit.rollback.fields.digest") }
        code(class: "mt-1 block wrap-break-word text-xs text-slate-700 dark:text-slate-300", id: "audit_rollback_preview_digest") { preview.digest }
      end
      operation_metadata
    end
  end

  def summary_value(label, value)
    div(class: "min-w-0") do
      p(class: "text-xs font-semibold uppercase text-slate-500 dark:text-slate-400") { label }
      p(class: "mt-1 wrap-break-word text-sm font-semibold text-slate-950 dark:text-slate-100") { value.to_s.presence || I18n.t("audit.values.empty") }
    end
  end

  def global_issues
    issue_list(preview.global_issues, tone: :unsupported) if preview.global_issues.present?
  end

  def operation_metadata
    details(class: "sm:col-span-2 xl:col-span-4") do
      summary(class: "cursor-pointer text-sm font-semibold text-slate-600 dark:text-slate-300") { I18n.t("audit.raw.operation_metadata") }
      pre(class: "mt-3 max-h-80 overflow-auto rounded-md bg-slate-950 p-3 text-xs text-emerald-200") do
        JSON.pretty_generate(preview.operation.metadata)
      end
    end
  end

  def preview_rows
    div(class: "space-y-4 py-5") do
      preview.rows.each { |row| preview_row(row) }
    end
  end

  def preview_row(row)
    presenter = Audit::VersionPresenter.new(row.transition.versions.first)
    article(id: "audit_rollback_row_#{row.record_type}_#{row.item_id}",
            class: "rounded-lg border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-900") do
      row_header(row, presenter)
      issue_list(row.support_issues, tone: :unsupported) if row.support_issues.present?
      issue_list(row.prohibitions, tone: :prohibited) if row.prohibitions.present?
      issue_list(row.conflicts, tone: :conflict) if row.conflicts.present?
      issue_list(row.requirements, tone: :requirement) if row.requirements.present?
      comparison_table(row, presenter)
      dependency_list(row)
      recalculation_list(row)
      raw_states(row)
    end
  end

  def row_header(row, presenter)
    div(class: "flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between") do
      div do
        h2(class: "font-semibold text-slate-950 dark:text-slate-100") { "#{presenter.model_name} ##{row.item_id}" }
        p(class: "mt-1 text-xs text-slate-500 dark:text-slate-400") do
          "#{I18n.t('audit.fields.owner')}: ##{row.owner_id} | #{I18n.t('audit.fields.context')}: ##{row.context_id}"
        end
      end
      div(class: "flex flex-wrap gap-2") do
        badge(I18n.t("audit.rollback.actions.#{row.action}"), :action)
        row.event_sequence.each { |event| badge(I18n.t("audit.events.#{event}"), :event) }
      end
    end
  end

  def badge(label, tone)
    classes = if tone == :action
                "border-sky-300 bg-sky-50 text-sky-900 dark:border-sky-800 dark:bg-sky-950 dark:text-sky-200"
              else
                "border-slate-300 text-slate-700 dark:border-slate-700 dark:text-slate-200"
              end
    span(class: "rounded-full border px-2 py-1 text-xs font-bold uppercase #{classes}") { label }
  end

  def issue_list(issues, tone:)
    colors = {
      unsupported: "border-slate-300 bg-slate-50 text-slate-800 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-200",
      prohibited: "border-rose-300 bg-rose-50 text-rose-900 dark:border-rose-900 dark:bg-rose-950 dark:text-rose-200",
      conflict: "border-amber-300 bg-amber-50 text-amber-900 dark:border-amber-900 dark:bg-amber-950 dark:text-amber-200",
      requirement: "border-sky-300 bg-sky-50 text-sky-900 dark:border-sky-900 dark:bg-sky-950 dark:text-sky-200"
    }
    ul(class: "mt-3 space-y-1 rounded-md border p-3 text-sm #{colors.fetch(tone)}") do
      issues.each do |issue|
        li do
          plain I18n.t("audit.rollback.issues.#{issue.code}")
          plain " (#{issue.details.values.flatten.join(', ')})" if issue.details.present?
        end
      end
    end
  end

  def comparison_table(row, presenter)
    attributes = changed_comparison_attributes(row)
    return if attributes.empty?

    div(class: "mt-4 overflow-x-auto") do
      table(class: "w-full min-w-[44rem] text-left text-sm") do
        thead(class: "border-b border-slate-200 text-xs uppercase text-slate-500 dark:border-slate-700 dark:text-slate-400") do
          tr do
            th(class: "px-2 py-2 font-semibold") { I18n.t("audit.fields.attribute") }
            th(class: "px-2 py-2 font-semibold") { I18n.t("audit.rollback.fields.before") }
            th(class: "px-2 py-2 font-semibold") { I18n.t("audit.rollback.fields.expected_after") }
            th(class: "px-2 py-2 font-semibold") { I18n.t("audit.rollback.fields.current") }
          end
        end
        tbody(class: "divide-y divide-slate-100 dark:divide-slate-800") do
          attributes.each { |attribute| comparison_row(row, presenter, attribute) }
        end
      end
    end
  end

  def changed_comparison_attributes(row)
    row.comparison_attributes.select do |attribute|
      [ row.before_state&.[](attribute), row.expected_after_state&.[](attribute), row.current_state&.[](attribute) ].uniq.size > 1
    end
  end

  def comparison_row(row, presenter, attribute)
    tr do
      th(class: "px-2 py-2 font-medium text-slate-700 dark:text-slate-200") { presenter.attribute_label(attribute) }
      td(class: value_cell_class) { presenter.format_value(attribute, row.before_state&.[](attribute)) }
      td(class: value_cell_class) { presenter.format_value(attribute, row.expected_after_state&.[](attribute)) }
      td(class: value_cell_class) { presenter.format_value(attribute, row.current_state&.[](attribute)) }
    end
  end

  def value_cell_class
    "max-w-72 wrap-break-word px-2 py-2 font-mono text-xs text-slate-600 dark:text-slate-300"
  end

  def dependency_list(row)
    return if row.dependencies.empty?

    section(class: "mt-4") do
      h3(class: "text-xs font-semibold uppercase text-slate-500 dark:text-slate-400") { I18n.t("audit.rollback.fields.dependencies") }
      ul(class: "mt-2 flex flex-wrap gap-2") do
        row.dependencies.each do |dependency|
          state = dependency.included ? I18n.t("audit.rollback.dependencies.included") : I18n.t("audit.rollback.dependencies.external")
          li(class: "rounded-md border border-slate-200 px-2 py-1 text-xs text-slate-600 dark:border-slate-700 dark:text-slate-300") do
            "#{dependency.record_type} ##{dependency.item_id} | #{state}"
          end
        end
      end
    end
  end

  def recalculation_list(row)
    return if row.recalculations.empty?

    p(class: "mt-4 text-xs text-slate-500 dark:text-slate-400") do
      "#{I18n.t('audit.rollback.fields.recalculations')}: #{row.recalculations.map { |key| I18n.t("audit.rollback.recalculations.#{key}") }.join(' | ')}"
    end
  end

  def raw_states(row)
    details(class: "mt-4 border-t border-slate-100 pt-3 dark:border-slate-800") do
      summary(class: "cursor-pointer text-sm font-semibold text-slate-600 dark:text-slate-300") { I18n.t("audit.rollback.fields.raw_states") }
      pre(class: "mt-3 max-h-96 overflow-auto rounded-md bg-slate-950 p-3 text-xs text-emerald-200") do
        JSON.pretty_generate(before: row.before_state, expected_after: row.expected_after_state, current: row.current_state)
      end
    end
  end
end
