# frozen_string_literal: true

class Views::CashTransactions::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Views::CashTransactions

  include CacheHelper
  include TranslateHelper

  attr_reader :index_context, :current_user, :mobile

  def initialize(index_context: {}, mobile: false)
    @index_context = index_context
    @current_user = index_context[:current_user]
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      div class: "w-full" do
        div class: "min-w-full" do
          turbo_frame_tag :cash_transactions do
            div class: "min-h-screen", data: { controller: "datatable" } do
              div class: "mb-8 flex sm:flex-row gap-4 items-start sm:items-center justify-between bg-white p-4 rounded-lg shadow-sm" do
                render IndexSearchForm.new(url: cash_transactions_path, index_context:, mobile:)
              end

              render PayMultipleModal.new(index_context:)
              render TransferMultipleModal.new(index_context:)
              render MonthYearContainer.new(index_context: index_context.slice(:search_term, :category_id, :entity_id,
                                                                               :from_ct_price, :to_ct_price, :from_price, :to_price,
                                                                               :from_installments_count, :to_installments_count, :paid, :pending,
                                                                               :from_date, :to_date,
                                                                               :user_bank_account_id, :active_month_years, :skip_budgets))

              div(
                class: "hidden fixed inset-x-3 bottom-20 md:bottom-4 md:inset-x-auto md:right-4 z-50",
                data: { datatable_target: :bulkBar }
              ) do
                div(class: "pointer-events-auto rounded-2xl border border-slate-300 bg-white/95 backdrop-blur shadow-2xl px-4 py-3") do
                  div(class: "flex flex-col md:flex-row md:items-center gap-3 md:gap-4") do
                    div(class: "text-sm font-semibold text-slate-800 whitespace-nowrap") do
                      span(data: { datatable_target: :selectedCount }) { "0" }
                      plain " "
                      plain action_message(:selected)
                    end

                    div(class: "flex gap-2") do
                      Button(
                        title: model_attribute(CashInstallment, :pay),
                        class: "flex-1 md:flex-none",
                        data: { action: "click->datatable#prepareBulkAction", modal_target: "cashInstallmentsModal", modal_toggle: "cashInstallmentsModal" }
                      ) do
                        model_attribute(CashInstallment, :pay)
                      end

                      Button(
                        title: model_attribute(CashInstallment, :transfer),
                        class: "flex-1 md:flex-none",
                        data: { action: "click->datatable#prepareBulkAction", modal_target: "transferMultipleModal", modal_toggle: "transferMultipleModal" }
                      ) do
                        model_attribute(CashInstallment, :transfer)
                      end
                    end
                  end
                end
              end
            end

            link_to(
              "#",
              class: "flex items-center justify-center md:hidden fixed bottom-0 right-2 m-2 bg-gray-300 text-black rounded-full shadow-lg z-50",
              onclick: "event.preventDefault(); const e = new KeyboardEvent('keyup', {key: 'n', bubbles: true}); document.dispatchEvent(e);"
            ) do
              cached_icon :bigger_bottom
            end

            link_to(
              new_cash_transaction_path(format: :turbo_stream),
              class: "flex items-center justify-center md:hidden fixed bottom-14 right-2 m-2 bg-blue-600 text-white rounded-full shadow-lg z-50",
              data: { turbo_frame: :_top }
            ) do
              cached_icon :bigger_plus
            end

            link_to(
              "#",
              class: "flex items-center justify-center md:hidden fixed bottom-28 right-2 m-2 bg-gray-300 text-black rounded-full shadow-lg z-50",
              onclick: "event.preventDefault(); const e = new KeyboardEvent('keyup', {key: 't', bubbles: true}); document.dispatchEvent(e);"
            ) do
              cached_icon :bigger_top
            end
          end
        end
      end
    end
  end
end
