# frozen_string_literal: true

class Views::Shared::AllocationTrend < Views::Base
  attr_reader :url, :query_state, :prefix, :translation_scope, :supplementary_sections

  def initialize(url:, query_state:, prefix:, translation_scope: "reports.allocation_trend", supplementary_sections: [])
    @url = url
    @query_state = query_state
    @prefix = prefix
    @translation_scope = translation_scope
    @supplementary_sections = supplementary_sections.map(&:to_sym)
  end

  def view_template
    div(
      id: prefix,
      class: "min-h-96 space-y-4",
      aria: { busy: "true" },
      data: {
        controller: "allocation-trend",
        allocation_trend_url_value: url,
        allocation_trend_locale_value: I18n.locale.to_s,
        allocation_trend_currency_value: "BRL",
        allocation_trend_labels_value: labels.to_json
      }
    ) do
      controls
      loading_state
      error_state
      empty_state
      report_content
    end
  end

  private

  def controls
    div(class: "grid gap-3 rounded-2xl border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-900 sm:grid-cols-2 xl:grid-cols-5") do
      date_control(:from_date, query_state.from_date)
      date_control(:to_date, query_state.to_date)
      select_control(:granularity, Reports::QueryState::GRANULARITIES, query_state.granularity)
      select_control(:paid_state, Reports::QueryState::PAID_STATES, query_state.paid_state)
      select_control(:direction, Reports::QueryState::DIRECTIONS, query_state.direction)
    end
  end

  def date_control(name, value)
    id = "#{prefix}_#{name}"

    div do
      label(for: id, class: control_label_class) { translate("controls.#{name}") }
      input(
        id:,
        type: :date,
        value: value.iso8601,
        class: control_input_class,
        data: {
          allocation_trend_target: camelize_target(name),
          action: "change->allocation-trend#changeFilters"
        }
      )
    end
  end

  def select_control(name, values, selected)
    id = "#{prefix}_#{name}"

    div do
      label(for: id, class: control_label_class) { translate("controls.#{name}") }
      select(
        id:,
        class: control_input_class,
        data: {
          allocation_trend_target: camelize_target(name),
          action: "change->allocation-trend#changeFilters"
        }
      ) do
        values.each do |value|
          option(value:, selected: value == selected) { translate("options.#{name}.#{value}") }
        end
      end
    end
  end

  def loading_state
    div(
      class: "flex min-h-64 items-center justify-center rounded-2xl border border-dashed border-slate-300 bg-white/70 px-4 text-sm text-slate-500 " \
             "dark:border-slate-700 dark:bg-slate-900/70 dark:text-slate-400",
      role: :status,
      data: { allocation_trend_target: "loadingState" }
    ) { translate(:loading) }
  end

  def error_state
    div(
      class: "hidden min-h-64 flex-col items-center justify-center gap-3 rounded-2xl border border-rose-200 bg-rose-50 px-4 text-center " \
             "dark:border-rose-900/60 dark:bg-rose-950/30",
      role: :alert,
      data: { allocation_trend_target: "errorState" }
    ) do
      p(class: "text-sm font-semibold text-rose-700 dark:text-rose-300", data: { allocation_trend_target: "errorMessage" }) do
        translate(:error)
      end
      button(
        type: :button,
        class: "rounded-lg border border-rose-300 bg-white px-3 py-2 text-sm font-semibold text-rose-700 hover:bg-rose-100 " \
               "dark:border-rose-800 dark:bg-slate-900 dark:text-rose-300 dark:hover:bg-rose-950/50",
        data: { action: "allocation-trend#retry" }
      ) { translate(:retry) }
    end
  end

  def empty_state
    div(
      class: "hidden min-h-64 items-center justify-center rounded-2xl border border-dashed border-slate-300 bg-white/70 px-4 text-center text-sm text-slate-500 " \
             "dark:border-slate-700 dark:bg-slate-900/70 dark:text-slate-400",
      data: { allocation_trend_target: "emptyState" }
    ) { translate(:empty) }
  end

  def report_content
    div(class: "hidden space-y-5", data: { allocation_trend_target: "content" }) do
      div(class: "grid gap-3 sm:grid-cols-3") do
        summary_card(:income, "text-emerald-700 dark:text-emerald-300")
        summary_card(:outcome, "text-rose-700 dark:text-rose-300")
        summary_card(:net, "text-slate-950 dark:text-slate-100")
      end

      supplementary_report_sections

      div(class: "rounded-2xl border border-slate-200 bg-white p-3 dark:border-slate-700 dark:bg-slate-950") do
        h3(class: "text-xs font-black uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") do
          translate(:timeline)
        end
        div(class: "mt-3 h-80") do
          canvas(
            role: :img,
            aria: { label: translate(:chart_label) },
            data: { allocation_trend_target: "chartCanvas" }
          )
        end
      end

      report_list(:buckets, "bucketList")
      report_list(:breakdowns, "breakdownList")
      report_list(:details_heading, "detailList") if supplementary_sections.include?(:details)
    end
  end

  def summary_card(name, tone)
    div(class: "rounded-2xl border border-slate-200 bg-white px-4 py-3 dark:border-slate-700 dark:bg-slate-900") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") do
        translate(name)
      end
      p(class: "mt-2 text-xl font-bold #{tone}", data: { allocation_trend_target: "summary#{name.to_s.camelize}" }) { "--" }
    end
  end

  def supplementary_report_sections
    report_list(:payment_states_heading, "paymentStateList") if supplementary_sections.include?(:payment_states)
    interactive_breakdown_sections if supplementary_sections.include?(:interactive_breakdowns)

    return unless supplementary_sections.include?(:balance_context)

    section(aria: { labelledby: "#{prefix}_balance_context_heading" }) do
      h3(id: "#{prefix}_balance_context_heading", class: "text-xs font-black uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") do
        translate(:balance_context_heading)
      end
      div(class: "mt-3 grid gap-3 sm:grid-cols-3", data: { allocation_trend_target: "balanceContext" })
    end
  end

  def interactive_breakdown_sections
    div(class: "grid gap-5 xl:grid-cols-2") do
      render Views::Shared::InteractiveBreakdownDashboard.new(
        prefix: "#{prefix}_interactive_category",
        kind: :category,
        allocation_target: "interactiveCategory"
      )
      render Views::Shared::InteractiveBreakdownDashboard.new(
        prefix: "#{prefix}_interactive_entity",
        kind: :entity,
        allocation_target: "interactiveEntity"
      )
    end
  end

  def report_list(title_key, target)
    section(aria: { labelledby: "#{prefix}_#{title_key}" }) do
      h3(id: "#{prefix}_#{title_key}", class: "text-xs font-black uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") do
        translate(title_key)
      end
      ol(class: "mt-3 grid gap-3", data: { allocation_trend_target: target })
    end
  end

  def labels
    labels = %i[
      income outcome net cash card no_sources error current_account_balance first_recorded latest_recorded no_recorded_balance recorded_on
    ].index_with { |key| translate(key, default: key.to_s.humanize) }
    detail_labels = %i[
      purchase_date installment_date billing_period closing_date due_date installment paid pending advance generated_payment invoice unavailable view_source
    ].index_with { |key| translate("details.#{key}", default: key.to_s.humanize) }

    labels.merge(detail_labels).merge(
      chunk: translate(:chunk),
      locale: I18n.locale.to_s
    )
  end

  def translate(key, **)
    I18n.t("#{translation_scope}.#{key}", **)
  end

  def camelize_target(name)
    name.to_s.camelize(:lower)
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
