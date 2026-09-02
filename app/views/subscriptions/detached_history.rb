# frozen_string_literal: true

class Views::Subscriptions::DetachedHistory < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  attr_reader :subscription, :entries

  def initialize(subscription:, entries:)
    @subscription = subscription
    @entries = entries
  end

  def view_template
    section(
      id: "subscription_detached_transactions",
      class: section_class,
      data: { controller: "show-section-card", show_section_card_open_value: true }
    ) do
      section_header

      div(class: "mt-4", data: { show_section_card_target: "content" }) do
        if entries.empty?
          empty_state
        elsif mobile?
          div(class: "space-y-3") { entries.each { |entry| mobile_entry(entry) } }
        else
          desktop_entries
        end
      end
    end
  end

  private

  def section_header
    button(
      type: :button,
      class: "flex w-full items-center justify-between gap-3 text-left",
      data: { action: "show-section-card#toggle", show_section_card_target: "button" }
    ) do
      h2(class: "text-xs font-black uppercase tracking-[0.2em] text-slate-500 dark:text-slate-400") do
        I18n.t("dashboards.subscriptions.detached_history")
      end
      span(class: "text-lg font-semibold leading-none text-slate-500 dark:text-slate-400", data: { show_section_card_target: "icon" }) { "−" }
    end
  end

  def desktop_entries
    div(class: "overflow-hidden rounded-2xl border border-slate-200 dark:border-slate-700") do
      div(class: "grid grid-cols-12 bg-slate-950 px-4 py-3 text-2xs font-bold uppercase tracking-[0.18em] text-white") do
        span(class: "col-span-2") { I18n.t("dashboards.subscriptions.type") }
        span(class: "col-span-4") { model_attribute(CashTransaction, :description) }
        span(class: "col-span-2") { I18n.t("dashboards.subscriptions.detached_state") }
        span(class: "col-span-2") { model_attribute(CashTransaction, :date) }
        span(class: "col-span-2 text-right") { model_attribute(CashTransaction, :price) }
      end

      entries.each { |entry| desktop_entry(entry) }
    end
  end

  def desktop_entry(entry)
    attributes = {
      id: entry_id(entry),
      class: "grid grid-cols-12 items-center border-t border-slate-200 bg-white px-4 py-3 text-sm no-underline " \
             "dark:border-slate-700 dark:bg-slate-950"
    }

    if entry.live?
      link_to(entry_path(entry), **attributes, data: { turbo_frame: "_top", turbo_prefetch: false }) { entry_content(entry) }
    else
      div(**attributes) { entry_content(entry, audit_link: true) }
    end
  end

  def entry_content(entry, audit_link: false)
    span(class: "col-span-2 font-bold text-slate-700 dark:text-slate-300") { type_label(entry) }
    if audit_link
      link_to(
        entry_description(entry),
        audit_path(entry),
        class: "col-span-4 truncate font-semibold text-sky-700 no-underline hover:underline dark:text-sky-300",
        data: { turbo_frame: "_top", turbo_prefetch: false }
      )
    else
      span(class: "col-span-4 truncate font-semibold text-slate-950 dark:text-slate-100") { entry_description(entry) }
    end
    span(class: "col-span-2") { state_badge(entry) }
    span(class: "col-span-2 text-slate-700 dark:text-slate-300") { display_date(entry) }
    span(class: "col-span-2 text-right font-bold text-slate-950 dark:text-slate-100") { display_price(entry) }
  end

  def mobile_entry(entry)
    attributes = {
      id: entry_id(entry),
      class: "block rounded-xl border border-slate-200 bg-white p-3 text-left no-underline dark:border-slate-700 dark:bg-slate-950"
    }

    if entry.live?
      link_to(entry_path(entry), **attributes, data: { turbo_frame: "_top", turbo_prefetch: false }) { mobile_entry_content(entry) }
    else
      div(**attributes) { mobile_entry_content(entry) }
    end
  end

  def mobile_entry_content(entry)
    div(class: "flex items-start justify-between gap-3") do
      div(class: "min-w-0") do
        p(class: "truncate font-bold text-slate-950 dark:text-slate-100") { entry_description(entry) }
        p(class: "mt-1 text-xs text-slate-500 dark:text-slate-400") { type_label(entry) }
      end
      state_badge(entry)
    end
    div(class: "mt-3 flex items-center justify-between gap-2 text-xs text-slate-600 dark:text-slate-300") do
      span { display_date(entry) }
      span(class: "font-bold text-slate-950 dark:text-slate-100") { display_price(entry) }
    end
    return unless entry.destroyed?

    link_to(
      I18n.t("dashboards.subscriptions.view_audit"),
      audit_path(entry),
      class: "mt-3 block text-xs text-sky-700 dark:text-sky-300",
      data: { turbo_frame: "_top", turbo_prefetch: false }
    )
  end

  def state_badge(entry)
    key = entry.destroyed? ? "destroyed" : "detached"
    span(class: state_badge_class(entry)) { I18n.t("dashboards.subscriptions.detached_states.#{key}") }
  end

  def empty_state
    div(class: "rounded-2xl border border-dashed border-slate-300 bg-white px-4 py-6 text-center text-sm text-slate-500 " \
               "dark:border-slate-600 dark:bg-slate-950 dark:text-slate-400") do
      I18n.t("dashboards.subscriptions.empty.detached")
    end
  end

  def entry_path(entry)
    return cash_transaction_path(entry.record, return_to: subscription_path(subscription)) if entry.record_type == "CashTransaction"

    card_transaction_path(entry.record, return_to: subscription_path(subscription))
  end

  def audit_path(entry) = record_audit_versions_path(item_type: entry.record_type, item_id: entry.item_id)

  def entry_id(entry) = "#{entry.destroyed? ? 'destroyed' : 'detached'}_subscription_#{entry.record_type}_#{entry.item_id}"

  def entry_description(entry) = entry.description.presence || "#{entry.record_type} ##{entry.item_id}"

  def display_date(entry) = entry.date.present? ? I18n.l(entry.date, format: :short) : "−"

  def display_price(entry) = entry.price.present? ? from_cent_based_to_float(entry.price, "R$") : "−"

  def type_label(entry)
    key = entry.record_type == "CashTransaction" ? "cash" : "card"
    I18n.t("dashboards.subscriptions.types.#{key}")
  end

  def state_badge_class(entry)
    base = "inline-flex rounded-full px-2 py-1 text-xs font-bold"
    return "#{base} bg-slate-200 text-slate-700 dark:bg-slate-800 dark:text-slate-200" if entry.destroyed?

    "#{base} bg-violet-100 text-violet-800 dark:bg-violet-950 dark:text-violet-200"
  end

  def section_class
    "rounded-2xl border border-slate-200 bg-slate-50/80 p-3 dark:border-slate-700 dark:bg-slate-900/70 sm:rounded-3xl sm:p-4"
  end
end
