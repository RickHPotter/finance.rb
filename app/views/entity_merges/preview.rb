# frozen_string_literal: true

class Views::EntityMerges::Preview < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :source, :plan, :destinations, :return_to

  def initialize(source:, plan:, destinations:, return_to: nil, frame_only: false)
    @source      = source
    @plan        = plan
    @destinations = destinations
    @return_to   = return_to
    @frame_only  = frame_only
  end

  def view_template
    return preview_frame if @frame_only

    main(class: "w-full px-2 py-2 sm:px-3") { preview_frame }
  end

  private

  def preview_frame
    turbo_frame_tag("entity_merge_preview_#{source.id}") do
      section(class: "rounded-lg border border-slate-200 bg-white p-4 text-slate-900 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-100") do
        header_section
        destination_form
        plan_summary if plan.present?
      end
    end
  end

  def header_section
    p(class: "text-xs font-semibold uppercase tracking-[0.18em] text-sky-700 dark:text-sky-300") do
      I18n.t("entity_merges.preview.eyebrow", default: "Entity Merge")
    end
    h1(class: "mt-1 text-xl font-bold") do
      I18n.t("entity_merges.preview.title", default: "Merge Entity")
    end
    p(class: "mt-1 text-sm text-slate-500 dark:text-slate-400") do
      plain "Source: "
      strong { source.name }
    end
  end

  def destination_form
    form_with(
      url: merge_preview_entity_path(source),
      method: :post,
      class: "mt-4"
    ) do |f|
      div(class: "flex flex-col gap-3 sm:flex-row sm:items-end") do
        div(class: "flex-1") do
          label(for: "entity_merge_destination_id", class: label_class) do
            I18n.t("entity_merges.preview.destination_label", default: "Destination Entity")
          end
          f.select(
            :"entity_merge[destination_id]",
            destinations.map { |e| [ e.name, e.id ] },
            { prompt: I18n.t("entity_merges.preview.choose_destination", default: "Choose destination..."),
              selected: plan&.destination&.id },
            { id: "entity_merge_destination_id", class: select_class }
          )
        end
        f.hidden_field :"entity_merge[return_to]", value: return_to
        f.hidden_field :"entity_merge[mode]", value: plan&.mode || :strict
        button(type: "submit", class: preview_button_class) do
          I18n.t("entity_merges.preview.submit_preview", default: "Preview Merge")
        end
      end
    end
  end

  def plan_summary
    div(class: "mt-4 space-y-3") do
      outcome_badge
      counts_grid
      conflict_reasons if plan.conflict_rows.any?
      apply_forms
      cancel_link
    end
  end

  def outcome_badge
    outcome_label = I18n.t("entity_merges.preview.outcome.#{plan.outcome}", default: plan.outcome.to_s.humanize)
    badge_class   = plan.apply_available? ? eligible_badge_class : ineligible_badge_class
    span(class: badge_class) { outcome_label }
  end

  def counts_grid
    dl(class: "mt-2 grid grid-cols-2 gap-2 sm:grid-cols-5") do
      count_metric("transfer",             plan.transfer_rows.size)
      count_metric("collapse",             plan.collapse_rows.size)
      count_metric("conflict",             plan.conflict_rows.size)
      count_metric("transaction_reassign", plan.transaction_reassign_count)
      count_metric("budget_reassign",      plan.budget_reassign_count)
    end
  end

  def count_metric(key, value)
    div(class: "rounded-md bg-slate-50 p-2 dark:bg-slate-800") do
      dt(class: "text-2xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") do
        I18n.t("entity_merges.preview.counts.#{key}", default: key.humanize)
      end
      dd(class: "mt-1 text-lg font-bold") { value.to_s }
    end
  end

  def conflict_reasons
    div(class: "mt-3 rounded-md bg-red-50 p-3 dark:bg-red-900/30") do
      h3(class: "text-sm font-medium text-red-800 dark:text-red-200") do
        I18n.t("entity_merges.preview.conflicts_title", default: "Conflicts detected:")
      end
      ul(class: "mt-2 list-disc pl-5 text-sm text-red-700 dark:text-red-300") do
        reasons = plan.conflict_rows.map(&:reason_code).tally
        reasons.each do |reason, count|
          li do
            plain I18n.t("entity_merges.reasons.#{reason}", default: reason.to_s.humanize)
            plain " (#{count})"
          end
        end
      end
    end
  end

  def apply_forms
    return if plan.outcome == :conflict

    div(class: "mt-3 flex flex-col gap-2 sm:flex-row") do
      strict_apply_form if plan.conflict_rows.empty?

      eligible_only_apply_form if plan.eligible_only_available?
    end
  end

  def strict_apply_form
    form_with(url: merge_entity_path(source), method: :post, class: "flex-1", data: { turbo_frame: "_top" }) do |f|
      f.hidden_field :merge_token,  value: EntityMerges::PreviewToken.generate(plan)
      f.hidden_field :return_to,    value: return_to
      f.hidden_field :mode,         value: "strict"
      button(
        type: "submit",
        id: "apply_entity_merge_#{source.id}",
        class: apply_button_class
      ) do
        I18n.t("entity_merges.preview.submit_apply_strict", default: "Merge and destroy")
      end
    end
  end

  def eligible_only_apply_form
    if plan.mode == :eligible_only
      form_with(url: merge_entity_path(source), method: :post, class: "flex-1", data: { turbo_frame: "_top" }) do |f|
        f.hidden_field :merge_token,  value: EntityMerges::PreviewToken.generate(plan)
        f.hidden_field :return_to,    value: return_to
        f.hidden_field :mode,         value: "eligible_only"
        button(
          type: "submit",
          id: "apply_entity_merge_eligible_#{source.id}",
          class: apply_eligible_button_class
        ) do
          I18n.t("entity_merges.preview.confirm_apply_eligible", default: "Confirm partial transfer")
        end
      end
    else
      form_with(url: merge_preview_entity_path(source), method: :post, class: "flex-1") do |f|
        f.hidden_field :"entity_merge[destination_id]", value: plan.destination.id
        f.hidden_field :"entity_merge[return_to]", value: return_to
        f.hidden_field :"entity_merge[mode]", value: "eligible_only"

        button(
          type: "submit",
          class: switch_mode_button_class
        ) do
          I18n.t("entity_merges.preview.submit_apply_eligible", default: "Transfer eligible only")
        end
      end
    end
  end

  def cancel_link
    link_to(
      I18n.t("entity_merges.preview.cancel", default: "Cancel"),
      return_to || entities_path,
      class: "mt-2 inline-block text-sm text-slate-500 hover:underline dark:text-slate-400",
      data: { turbo_frame: "_top" }
    )
  end

  # -- style helpers ----------------------------------------------------------

  def label_class
    "block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1"
  end

  def select_class
    "block w-full rounded-md border border-slate-300 bg-white px-3 py-2 text-sm " \
      "shadow-sm focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500 " \
      "dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100"
  end

  def preview_button_class
    "rounded-md bg-sky-600 px-4 py-2 text-sm font-semibold text-white shadow-sm " \
      "hover:bg-sky-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-sky-600"
  end

  def apply_button_class
    "w-full rounded-md bg-rose-600 px-4 py-2 text-sm font-semibold text-white shadow-sm " \
      "hover:bg-rose-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-rose-600"
  end

  def apply_eligible_button_class
    "w-full rounded-md bg-emerald-600 px-4 py-2 text-sm font-semibold text-white shadow-sm " \
      "hover:bg-emerald-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-emerald-600"
  end

  def switch_mode_button_class
    "w-full rounded-md bg-white px-4 py-2 text-sm font-semibold text-slate-700 shadow-sm ring-1 ring-inset ring-slate-300 " \
      "hover:bg-slate-50 dark:bg-slate-800 dark:text-slate-300 dark:ring-slate-600 dark:hover:bg-slate-700"
  end

  def eligible_badge_class
    "inline-flex items-center rounded-full bg-emerald-100 px-2 py-0.5 text-xs font-medium " \
      "text-emerald-800 dark:bg-emerald-900 dark:text-emerald-200"
  end

  def ineligible_badge_class
    "inline-flex items-center rounded-full bg-amber-100 px-2 py-0.5 text-xs font-medium " \
      "text-amber-800 dark:bg-amber-900 dark:text-amber-200"
  end
end
