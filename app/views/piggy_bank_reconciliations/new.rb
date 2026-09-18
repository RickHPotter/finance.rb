# frozen_string_literal: true

class Views::PiggyBankReconciliations::New < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::LinkTo
  include TranslateHelper
  include ComponentsHelper

  attr_reader :return_cash_transaction, :observed_on, :observed_net, :description, :plan, :return_to

  def initialize(return_cash_transaction:, observed_on: nil, observed_net: nil, description: nil, plan: nil, return_to: nil)
    @return_cash_transaction = return_cash_transaction
    @observed_on = observed_on || Time.zone.today
    @observed_net = observed_net
    @description = description
    @plan = plan
    @return_to = return_to
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: shell_class) do
        header_section
        context_summary_section
        form_section

        div(id: "piggy_bank_reconciliation_preview") do
          if plan.present?
            render Views::PiggyBankReconciliations::PreviewCard.new(
              return_cash_transaction:,
              plan:,
              description:,
              return_to:
            )
          end
        end
      end
    end
  end

  private

  def header_section
    div(class: "border-b border-slate-200 pb-4 dark:border-slate-800") do
      p(class: "text-xs font-semibold uppercase tracking-[0.18em] text-emerald-700 dark:text-emerald-400") do
        I18n.t("piggy_bank_reconciliations.form.eyebrow")
      end
      h1(class: "mt-1 text-2xl font-black tracking-tight text-slate-950 dark:text-slate-100 sm:text-3xl") do
        I18n.t("piggy_bank_reconciliations.form.title")
      end
      p(class: "mt-1 text-sm text-slate-600 dark:text-slate-400") do
        plain "#{I18n.t('piggy_bank_reconciliations.form.subtitle')}: "
        strong(class: "text-slate-900 dark:text-slate-200") { return_cash_transaction.description }
      end
    end
  end

  def context_summary_section
    section(class: "mt-4 rounded-2xl border border-slate-200 bg-slate-50/60 p-4 dark:border-slate-800 dark:bg-slate-950/50") do
      h2(class: "mb-3 text-2xs font-bold uppercase tracking-[0.18em] text-slate-500 dark:text-slate-400") do
        I18n.t("piggy_bank_reconciliations.form.context_title")
      end

      div(class: "grid grid-cols-2 gap-3 xl:grid-cols-4") do
        context_stat(I18n.t("piggy_bank_reconciliations.form.recorded_lifetime"), money(return_cash_transaction.price))
        context_stat(I18n.t("piggy_bank_reconciliations.form.paid_return"), money(paid_cents))
        context_stat(I18n.t("piggy_bank_reconciliations.form.recorded_remaining"), money(recorded_remaining_cents), emphasis: true)
        context_stat(I18n.t("piggy_bank_reconciliations.form.contributions_count"), return_cash_transaction.piggy_bank_return_links.size.to_s)
      end
    end
  end

  def form_section
    section(class: "mt-4 rounded-2xl border border-slate-200 bg-white p-4 dark:border-slate-800 dark:bg-slate-900 sm:p-6") do
      form_with(
        url: preview_cash_transaction_piggy_bank_reconciliation_path(return_cash_transaction),
        method: :post,
        id: "piggy_bank_reconciliation_form",
        class: "space-y-4",
        data: { controller: "price-mask" }
      ) do |f|
        hidden_field_tag :return_to, return_to if return_to.present?

        div(class: "grid grid-cols-1 gap-4 lg:grid-cols-2") do
          div do
            label(for: "piggy_bank_reconciliation_observed_on", class: label_class) do
              I18n.t("piggy_bank_reconciliations.form.observed_on_label")
            end
            render Views::Shared::DatetimeInput.new(
              form: f,
              field: :observed_on,
              value: observed_on,
              id: "piggy_bank_reconciliation_observed_on",
              show_time: false,
              calendar: mobile?
            )
          end

          div do
            label(for: "piggy_bank_reconciliation_observed_net", class: label_class) do
              I18n.t("piggy_bank_reconciliations.form.observed_net_label")
            end
            TextFieldTag(
              :observed_net,
              type: :text,
              inputmode: :numeric,
              svg: :money,
              id: "piggy_bank_reconciliation_observed_net",
              class: "font-graduate dark:font-mono",
              value: observed_net_display_value,
              autocomplete: :off,
              data: { price_mask_target: :input, action: "input->price-mask#applyMask" }
            )
            p(class: "mt-1 text-xs text-slate-500 dark:text-slate-400") do
              I18n.t("piggy_bank_reconciliations.form.observed_net_hint")
            end
          end
        end

        div do
          label(for: "piggy_bank_reconciliation_description", class: label_class) do
            I18n.t("piggy_bank_reconciliations.form.description_label")
          end
          TextFieldTag(
            :description,
            type: :text,
            id: "piggy_bank_reconciliation_description",
            placeholder: I18n.t("piggy_bank_reconciliations.form.description_placeholder"),
            value: description,
            autocomplete: :off
          )
        end

        div(class: "flex flex-wrap items-center gap-3 pt-2") do
          f.submit(
            I18n.t("piggy_bank_reconciliations.form.preview_button"),
            id: "preview_piggy_bank_reconciliation",
            class: "#{submit_button_class(:edit)} cursor-pointer"
          )
          link_to(
            I18n.t("piggy_bank_reconciliations.form.cancel"),
            cancel_path,
            class: "#{secondary_submit_row_button_class('w-auto')} inline-flex items-center justify-center rounded-md px-4 py-2 text-sm font-semibold",
            data: { turbo_frame: "_top" }
          )
        end
      end
    end
  end

  def context_stat(label, value, emphasis: false)
    div(class: "rounded-xl border border-slate-200 bg-white p-3 dark:border-slate-800 dark:bg-slate-900") do
      p(class: "text-2xs font-semibold uppercase tracking-[0.16em] text-slate-500 dark:text-slate-400") { label }
      stat_class = if emphasis
                     "text-lg sm:text-xl font-black text-emerald-600 dark:text-emerald-400"
                   else
                     "text-sm sm:text-base font-bold text-slate-950 dark:text-slate-100"
                   end
      p(class: "#{stat_class} mt-1") do
        value.to_s
      end
    end
  end

  def paid_cents
    return_cash_transaction.cash_installments.select(&:paid?).sum(&:price)
  end

  def recorded_remaining_cents
    return_cash_transaction.cash_installments.reject(&:paid?).sum(&:price)
  end

  def observed_net_display_value
    return nil if observed_net.blank?
    return money(observed_net) if observed_net.is_a?(Integer)

    observed_net.to_s
  end

  def cancel_path
    return_to.presence || cash_transaction_path(return_cash_transaction)
  end

  def shell_class
    "min-h-[calc(100svh-12rem)] rounded-2xl border border-slate-200 bg-white p-3 shadow-sm " \
      "dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100 dark:shadow-none sm:rounded-3xl sm:p-6"
  end

  def money(value) = from_cent_based_to_float(value, "R$")
end
