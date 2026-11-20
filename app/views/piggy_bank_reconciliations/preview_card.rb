# frozen_string_literal: true

class Views::PiggyBankReconciliations::PreviewCard < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include TranslateHelper
  include ComponentsHelper

  attr_reader :return_cash_transaction, :plan

  def initialize(return_cash_transaction:, plan:)
    @return_cash_transaction = return_cash_transaction
    @plan = plan
  end

  def view_template
    div(
      id: "piggy_bank_reconciliation_preview",
      class: "mt-6 space-y-4 rounded-2xl border border-slate-200 bg-slate-50/70 p-4 " \
             "dark:border-slate-700 dark:bg-slate-950/70 sm:p-6"
    ) do
      header_section
      comparison_grid
      noop_callout if plan.noop?
      apply_form
    end
  end

  private

  def header_section
    div(class: "flex items-center justify-between gap-3 border-b border-slate-200 pb-3 dark:border-slate-800") do
      h3(class: "text-xs font-black uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400") do
        I18n.t("piggy_bank_reconciliations.preview.title")
      end
      status_badge
    end
  end

  def status_badge
    if plan.noop?
      span(class: "inline-flex items-center rounded-full border border-amber-300 bg-amber-100 px-3 py-1 " \
                  "text-xs font-bold uppercase tracking-[0.14em] text-amber-900 " \
                  "dark:border-amber-700/60 dark:bg-amber-950/60 dark:text-amber-300") do
        I18n.t("piggy_bank_reconciliations.preview.noop_badge")
      end
    else
      span(class: "inline-flex items-center rounded-full border border-emerald-300 bg-emerald-100 px-3 py-1 " \
                  "text-xs font-bold uppercase tracking-[0.14em] text-emerald-900 " \
                  "dark:border-emerald-700/60 dark:bg-emerald-950/60 dark:text-emerald-300") do
        I18n.t("piggy_bank_reconciliations.preview.ready_badge")
      end
    end
  end

  def comparison_grid
    div(class: "grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3") do
      metric_card(
        I18n.t("piggy_bank_reconciliations.preview.recorded_remaining"),
        money(plan.recorded_remaining_cents)
      )
      metric_card(
        I18n.t("piggy_bank_reconciliations.preview.observed_net"),
        money(plan.observed_net_cents)
      )
      metric_card(
        I18n.t("piggy_bank_reconciliations.preview.calculated_delta"),
        delta_display_string,
        emphasis: true,
        text_color_class: delta_color_class
      )
      metric_card(
        I18n.t("piggy_bank_reconciliations.preview.untouched_paid"),
        money(plan.paid_cents)
      )
      metric_card(
        I18n.t("piggy_bank_reconciliations.preview.resulting_lifetime"),
        money(plan.resulting_lifetime_cents)
      )
      metric_card(
        I18n.t("piggy_bank_reconciliations.preview.installment_date"),
        installment_date_label
      )
    end
  end

  def installment_date_label
    return I18n.t("piggy_bank_reconciliations.preview.installment_date_not_set") if plan.installment_date.blank?

    I18n.l(plan.installment_date.to_date, format: :long)
  end

  def metric_card(label, value, emphasis: false, text_color_class: nil)
    div(class: "rounded-xl border border-slate-200 bg-white p-3 dark:border-slate-800 dark:bg-slate-900 sm:p-4") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400") { label }
      p(class: "#{emphasis ? 'text-xl sm:text-2xl font-black' : 'text-base sm:text-lg font-bold'} " \
               "#{text_color_class || 'text-slate-950 dark:text-slate-100'} mt-1") do
        value.to_s
      end
    end
  end

  def delta_display_string
    return money(0) if plan.delta_cents.zero?

    sign = plan.delta_cents.positive? ? "+" : "-"
    "#{sign} #{money(plan.delta_cents.abs)}"
  end

  def delta_color_class
    if plan.delta_cents.positive?
      "text-emerald-600 dark:text-emerald-400"
    elsif plan.delta_cents.negative?
      "text-rose-600 dark:text-rose-400"
    else
      "text-slate-600 dark:text-slate-400"
    end
  end

  def noop_callout
    div(class: "rounded-xl border border-amber-200 bg-amber-50/80 p-3 text-sm text-amber-900 " \
               "dark:border-amber-900/60 dark:bg-amber-950/40 dark:text-amber-300") do
      I18n.t("piggy_bank_reconciliations.preview.noop_message")
    end
  end

  # The apply button submits the reconciliation form itself, so whatever the user typed after
  # the preview was calculated is the value that gets applied. The digest travels on the
  # action URL because the form has no room for it.
  def apply_form
    button_label = plan.noop? ? I18n.t("piggy_bank_reconciliations.form.apply_noop_button") : I18n.t("piggy_bank_reconciliations.form.apply_button")

    div(class: "pt-2") do
      Button(
        type: :submit,
        form: Views::PiggyBankReconciliations::New::FORM_ID,
        formaction: apply_path,
        data: { turbo_frame: "_top" },
        id: "apply_piggy_bank_reconciliation",
        class: "#{submit_button_class(:new)} w-full sm:w-auto cursor-pointer"
      ) do
        button_label
      end
    end
  end

  def apply_path
    cash_transaction_piggy_bank_reconciliation_path(return_cash_transaction, digest: plan.digest)
  end

  def money(value) = from_cent_based_to_float(value, "R$")
end
