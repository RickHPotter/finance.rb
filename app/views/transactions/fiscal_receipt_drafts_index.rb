# frozen_string_literal: true

class Views::Transactions::FiscalReceiptDraftsIndex < Views::Base
  register_value_helper :current_user

  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::TurboStreamFrom

  attr_reader :drafts, :user_card

  def initialize(drafts:, user_card: nil)
    @drafts = drafts
    @user_card = user_card
  end

  def view_template
    turbo_stream_from [ current_user, :fiscal_receipt_drafts ] if current_user

    turbo_frame_tag :center_container do
      div(class: "w-full rounded-lg bg-white p-4 shadow-sm dark:border dark:border-slate-800 dark:bg-slate-900 dark:text-slate-100 dark:shadow-none") do
        div(class: "mb-4 flex flex-col gap-3 border-b border-stone-200 pb-3 dark:border-slate-700 sm:flex-row sm:items-center sm:justify-between") do
          div(class: "min-w-0") do
            div(class: "flex flex-wrap items-center gap-x-2 gap-y-1") do
              h1(class: "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700 dark:text-slate-300") do
                I18n.t("fiscal_import.inbox")
              end
              span(class: "text-xs text-stone-500 dark:text-slate-400") do
                I18n.t("fiscal_import.saved_count", count: drafts.size)
              end
            end
            p(class: "mt-1 text-sm text-slate-600 dark:text-slate-400") { I18n.t("fiscal_import.inbox_description") }
          end
          link_to I18n.t("fiscal_import.back_to_transactions"), user_card ? card_transactions_path(user_card_id: user_card.id) : cash_transactions_path,
                  class: "inline-flex shrink-0 items-center justify-center rounded-md bg-sky-700 px-3 py-2 text-sm font-semibold " \
                         "text-white transition hover:bg-sky-800",
                  data: { turbo_frame: "_top" }
        end

        if drafts.empty?
          div(class: "rounded-lg border border-dashed border-slate-300 px-4 py-8 text-center dark:border-slate-700") do
            h2(class: "text-base font-semibold text-slate-900 dark:text-slate-100") { I18n.t("fiscal_import.empty_title") }
            p(class: "mx-auto mt-1 max-w-lg text-sm text-slate-600 dark:text-slate-300") do
              I18n.t("fiscal_import.empty_inbox")
            end
          end
        else
          div(id: "fiscal_receipt_drafts_grid", class: "grid gap-3 lg:grid-cols-2") do
            drafts.each { |draft| render Views::Transactions::FiscalReceiptDraftCard.new(draft:, user_card:) }
          end
        end
      end
    end
  end
end
