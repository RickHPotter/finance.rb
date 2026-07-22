# frozen_string_literal: true

class Views::Audit::VersionList < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :versions, :current_user

  def initialize(versions:, current_user:)
    @versions = versions
    @current_user = current_user
  end

  def view_template
    if versions.empty?
      p(class: "py-10 text-center text-sm text-slate-500 dark:text-slate-400") { I18n.t("audit.empty.versions") }
      return
    end

    div(class: "space-y-3") do
      versions.each { |version| version_row(version) }
    end
  end

  private

  def version_row(version)
    presenter = Audit::VersionPresenter.new(version)

    article(id: "audit_version_#{version.id}", class: "rounded-lg border border-slate-200 bg-white p-4 dark:border-slate-700 dark:bg-slate-900") do
      div(class: "flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between") do
        div(class: "min-w-0") do
          div(class: "flex flex-wrap items-center gap-2") do
            event_badge(version.event)
            mutation_badge(version.mutation_source)
            span(class: "font-semibold text-slate-950 dark:text-slate-100") { "#{presenter.model_name} ##{version.item_id}" }
          end
          p(class: "mt-2 text-xs text-slate-500 dark:text-slate-400") { I18n.l(version.created_at, format: :short) }
        end

        div(class: "flex flex-wrap gap-2") do
          link_to(I18n.t("audit.actions.operation"), audit_operation_path(version.operation_id),
                  class: compact_link_class, data: { turbo_frame: "_top", turbo_prefetch: false })
          link_to(I18n.t("audit.actions.record_history"), record_audit_versions_path(item_type: record_route_type(version), item_id: version.item_id),
                  class: compact_link_class, data: { turbo_frame: "_top", turbo_prefetch: false })
        end
      end

      metadata_line(version)
      changes_table(presenter)
      raw_disclosure(presenter)
    end
  end

  def metadata_line(version)
    values = []
    values << "#{I18n.t('audit.fields.owner')}: ##{version.owner_id}" if current_user.admin?
    values << "#{I18n.t('audit.fields.context')}: ##{version.context_id}" if version.context_id.present?
    values << "#{I18n.t('audit.fields.version')}: ##{version.id}"

    p(class: "mt-3 text-xs text-slate-500 dark:text-slate-400") { values.join(" | ") }
  end

  def changes_table(presenter)
    if presenter.changes.empty?
      p(class: "mt-4 text-sm text-slate-500 dark:text-slate-400") { I18n.t("audit.empty.changes") }
      return
    end

    div(class: "mt-4 overflow-x-auto") do
      table(class: "w-full min-w-[36rem] text-left text-sm") do
        thead(class: "border-b border-slate-200 text-xs uppercase text-slate-500 dark:border-slate-700 dark:text-slate-400") do
          tr do
            th(class: "px-2 py-2 font-semibold") { I18n.t("audit.fields.attribute") }
            th(class: "px-2 py-2 font-semibold") { I18n.t("audit.fields.before") }
            th(class: "px-2 py-2 font-semibold") { I18n.t("audit.fields.after") }
          end
        end
        tbody(class: "divide-y divide-slate-100 dark:divide-slate-800") do
          presenter.changes.each do |change|
            tr do
              th(class: "px-2 py-2 font-medium text-slate-700 dark:text-slate-200") { change.label }
              td(class: "max-w-80 wrap-break-word px-2 py-2 font-mono text-xs text-slate-600 dark:text-slate-400") { change.before }
              td(class: "max-w-80 wrap-break-word px-2 py-2 font-mono text-xs text-slate-950 dark:text-slate-100") { change.after }
            end
          end
        end
      end
    end
  end

  def raw_disclosure(presenter)
    details(class: "mt-4 border-t border-slate-100 pt-3 dark:border-slate-800") do
      summary(class: "cursor-pointer text-sm font-semibold text-slate-600 dark:text-slate-300") { I18n.t("audit.raw.title") }
      pre(class: "mt-3 max-h-96 overflow-auto rounded-md bg-slate-950 p-3 text-xs text-emerald-200") do
        JSON.pretty_generate(presenter.raw_payload)
      end
    end
  end

  def event_badge(event)
    classes = {
      "create" => "bg-emerald-100 text-emerald-900",
      "update" => "bg-amber-100 text-amber-900",
      "destroy" => "bg-rose-100 text-rose-900"
    }.fetch(event, "bg-slate-100 text-slate-900")
    span(class: "rounded-full px-2 py-1 text-xs font-bold uppercase #{classes}") { I18n.t("audit.events.#{event}") }
  end

  def mutation_badge(source)
    span(class: "rounded-full border border-slate-300 px-2 py-1 text-xs font-semibold text-slate-600 dark:border-slate-700 dark:text-slate-300") do
      I18n.t("audit.sources.#{source}", default: source.humanize)
    end
  end

  def record_route_type(version)
    version.item_subtype.presence || version.item_type
  end

  def compact_link_class
    "inline-flex min-h-9 items-center rounded-md border border-slate-300 px-3 py-1 text-xs font-semibold text-slate-700 hover:bg-slate-100 " \
      "dark:border-slate-700 dark:text-slate-200 dark:hover:bg-slate-800"
  end
end
