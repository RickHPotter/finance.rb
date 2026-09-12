# frozen_string_literal: true

class Views::Entities::LedgerShares < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  attr_reader :entity, :ledger_context, :shares, :created_share_url

  def initialize(entity:, ledger_context:, shares:, created_share_url: nil)
    @entity = entity
    @ledger_context = ledger_context
    @shares = shares
    @created_share_url = created_share_url
  end

  def view_template
    div(id: "entity_ledger_shares", class: "space-y-4") do
      one_time_link if created_share_url
      introduction
      creation_form
      share_list
    end
  end

  private

  def one_time_link
    div(
      class: "rounded-xl border border-emerald-300 bg-emerald-50 p-4 dark:border-emerald-800 dark:bg-emerald-950/40",
      data: { controller: "ledger-share-copy" }
    ) do
      p(class: "font-bold text-emerald-900 dark:text-emerald-200") { I18n.t("ledger_shares.one_time.title") }
      p(class: "mt-1 text-xs text-emerald-800 dark:text-emerald-300") { I18n.t("ledger_shares.one_time.description") }
      div(class: "mt-3 flex flex-col gap-2 sm:flex-row") do
        input(
          id: "created_ledger_share_url",
          type: :text,
          value: created_share_url,
          readonly: true,
          class: "min-w-0 flex-1 rounded-lg border border-emerald-300 bg-white px-3 py-2 font-mono text-xs text-slate-900 " \
                 "dark:border-emerald-700 dark:bg-slate-950 dark:text-slate-100",
          data: { ledger_share_copy_target: "source" }
        )
        button(
          type: :button,
          class: "rounded-lg bg-emerald-700 px-4 py-2 text-sm font-bold text-white hover:bg-emerald-600",
          data: { action: "ledger-share-copy#copy" }
        ) { I18n.t("ledger_shares.actions.copy") }
      end
      p(class: "mt-2 hidden text-xs font-semibold text-emerald-800 dark:text-emerald-300", data: { ledger_share_copy_target: "feedback" }) do
        I18n.t("ledger_shares.one_time.copied")
      end
    end
  end

  def introduction
    div(class: "text-left") do
      p(class: "text-sm text-slate-600 dark:text-slate-300") { I18n.t("ledger_shares.description", context: ledger_context.name) }
      p(class: "mt-1 text-xs text-amber-700 dark:text-amber-300") { I18n.t("ledger_shares.security_note") }
    end
  end

  def creation_form
    form_with(url: entity_ledger_shares_path(entity), scope: :ledger_share, method: :post, class: "rounded-xl bg-slate-100 p-3 dark:bg-slate-950") do |form|
      div(class: "grid gap-3 sm:grid-cols-[minmax(0,1fr)_auto] sm:items-end") do
        div do
          label(for: "ledger_share_expires_at", class: "mb-1 block text-xs font-bold text-slate-600 dark:text-slate-300") do
            I18n.t("ledger_shares.expires_at")
          end
          render Views::Shared::DatetimeInput.new(
            form:,
            field: :expires_at,
            value: nil,
            id: "ledger_share_expires_at",
            compact: true,
            min_datetime: Time.current,
            min_datetime_message: I18n.t("ledger_shares.errors.future_expiry")
          )
          p(class: "mt-1 text-xs text-slate-500 dark:text-slate-400") { I18n.t("ledger_shares.expiry_hint") }
        end
        Button(type: :submit, variant: :primary, class: "w-full sm:w-auto") { I18n.t("ledger_shares.actions.create") }
      end
    end
  end

  def share_list
    if shares.any?
      div(class: "grid gap-3") { shares.each { |ledger_share| share_row(ledger_share) } }
    else
      p(class: "rounded-xl border border-dashed border-slate-300 px-4 py-6 text-center text-sm text-slate-500 dark:border-slate-700 dark:text-slate-400") do
        I18n.t("ledger_shares.empty")
      end
    end
  end

  def share_row(ledger_share)
    state = ledger_share.lifecycle_state
    article(class: "rounded-xl border border-slate-200 bg-white p-4 text-left dark:border-slate-700 dark:bg-slate-900") do
      div(class: "flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between") do
        div(class: "min-w-0") do
          span(class: state_badge_class(state)) { I18n.t("ledger_shares.states.#{state}") }
          div(class: "mt-3 grid gap-x-6 gap-y-2 text-sm sm:grid-cols-2 xl:grid-cols-4") do
            detail(I18n.t("ledger_shares.fields.created_at"), localized_time(ledger_share.created_at))
            detail(I18n.t("ledger_shares.fields.expires_at"), localized_time(ledger_share.expires_at, fallback: I18n.t("ledger_shares.never")))
            detail(I18n.t("ledger_shares.fields.last_accessed_at"), localized_time(ledger_share.last_accessed_at))
            detail(I18n.t("ledger_shares.fields.access_count"), ledger_share.access_count.to_s)
          end
        end
        lifecycle_actions(ledger_share) if state == :active
      end
    end
  end

  def detail(label, value)
    div do
      p(class: "text-xs font-semibold uppercase tracking-wide text-slate-500 dark:text-slate-400") { label }
      p(class: "mt-0.5 font-medium text-slate-900 dark:text-slate-100") { value }
    end
  end

  def lifecycle_actions(ledger_share)
    div(class: "flex shrink-0 flex-wrap gap-2") do
      form_with(
        url: rotate_entity_ledger_share_path(entity, ledger_share.public_id),
        method: :patch,
        data: { turbo_confirm: I18n.t("ledger_shares.confirmations.rotate") }
      ) do
        Button(type: :submit, variant: :outline) do
          I18n.t("ledger_shares.actions.rotate")
        end
      end
      form_with(
        url: entity_ledger_share_path(entity, ledger_share.public_id),
        method: :delete,
        data: { turbo_confirm: I18n.t("ledger_shares.confirmations.revoke") }
      ) do
        Button(type: :submit, variant: :destructive) do
          I18n.t("ledger_shares.actions.revoke")
        end
      end
    end
  end

  def state_badge_class(state)
    base = "inline-flex rounded-full px-2.5 py-1 text-xs font-bold uppercase tracking-wide"
    colour = case state
             when :active then "bg-emerald-100 text-emerald-800 dark:bg-emerald-950 dark:text-emerald-300"
             when :expired then "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-300"
             else "bg-slate-200 text-slate-700 dark:bg-slate-800 dark:text-slate-300"
             end
    "#{base} #{colour}"
  end

  def localized_time(value, fallback: I18n.t("ledger_shares.not_yet"))
    value ? I18n.l(value, format: :short) : fallback
  end
end
