# frozen_string_literal: true

class Views::Shared::InteractiveBreakdownDashboard < Views::Base
  attr_reader :prefix, :kind, :allocation_target

  def initialize(prefix:, kind:, allocation_target:)
    @prefix = prefix
    @kind = kind.to_sym
    @allocation_target = allocation_target
  end

  def view_template
    section(aria: { labelledby: "#{prefix}_heading" }) do
      h3(id: "#{prefix}_heading", class: heading_class) { translate("#{kind}_title") }
      div(
        class: "mt-3 space-y-4",
        data: {
          controller: "interactive-breakdown-dashboard",
          allocation_trend_target: allocation_target,
          interactive_breakdown_dashboard_data_value: empty_payload.to_json,
          interactive_breakdown_dashboard_locale_value: I18n.locale.to_s,
          interactive_breakdown_dashboard_currency_value: "BRL",
          interactive_breakdown_dashboard_labels_value: labels.to_json
        }
      ) do
        primary_control
        selection_control(:groups, "groupOptions", actions_target: "groupActions")
        selection_control(:secondary, "secondaryOptions", actions_target: "secondaryActions")
        chart
      end
    end
  end

  private

  def primary_control
    div do
      label(for: "#{prefix}_primary", class: control_label_class) { translate(kind) }
      select(
        id: "#{prefix}_primary",
        class: control_input_class,
        data: {
          interactive_breakdown_dashboard_target: "primarySelect",
          action: "change->interactive-breakdown-dashboard#changePrimary"
        }
      )
    end
  end

  def selection_control(label, options_target, actions_target: nil)
    div(class: "space-y-2") do
      p(class: control_label_class) { translate(label_key(label)) }
      div(class: "flex flex-wrap gap-2", data: { interactive_breakdown_dashboard_target: actions_target }) if actions_target
      div(class: "flex flex-wrap gap-2", data: { interactive_breakdown_dashboard_target: options_target })
    end
  end

  def chart
    div(class: "rounded-2xl border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-950") do
      div(class: "h-80") do
        canvas(
          class: "hidden h-full w-full",
          role: :img,
          aria: { label: translate("#{kind}_chart_label") },
          data: { interactive_breakdown_dashboard_target: "chartCanvas" }
        )
        p(
          class: "flex h-full items-center justify-center text-center text-sm text-slate-500 dark:text-slate-400",
          data: { interactive_breakdown_dashboard_target: "emptyState" }
        ) { translate(:empty) }
      end
    end
  end

  def empty_payload
    { primary_kind: kind, secondary_kind: secondary_kind, granularity: "month", periods: [], items: [] }
  end

  def labels
    %i[select_all unselect_all].index_with { |key| translate(key) }
  end

  def label_key(label)
    return "#{kind}_groups" if label == :groups

    secondary_kind
  end

  def secondary_kind
    kind == :category ? :entity : :category
  end

  def translate(key)
    I18n.t("reports.interactive_breakdown.#{key}")
  end

  def heading_class
    "text-xs font-black uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400"
  end

  def control_label_class
    "mb-1 block text-2xs font-black uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400"
  end

  def control_input_class
    "w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm text-slate-950 shadow-sm outline-hidden transition " \
      "focus:border-sky-400 focus:ring-2 focus:ring-sky-400/30 dark:border-slate-700 dark:bg-slate-950 dark:text-slate-100 " \
      "dark:scheme-dark dark:focus:border-sky-500"
  end
end
