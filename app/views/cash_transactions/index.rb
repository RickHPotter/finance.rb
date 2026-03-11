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
                class: "hidden fixed inset-x-3 bottom-20 md:bottom-6 md:left-1/2 md:right-auto md:inset-x-auto md:-translate-x-1/2 z-50",
                data: { datatable_target: :bulkBar }
              ) do
                div(class: "pointer-events-auto rounded-2xl border border-slate-300 bg-white/95 backdrop-blur shadow-2xl px-5 py-4 md:px-6 md:py-4") do
                  div(class: "flex flex-col md:flex-row md:items-center md:justify-center gap-3 md:gap-5") do
                    div(class: "text-base font-semibold text-slate-800 whitespace-nowrap text-center md:text-left") do
                      span(data: { datatable_target: :selectedCount }) { "0" }
                      plain " "
                      plain action_message(:selected)
                    end

                    div(class: "flex gap-2 md:gap-3") do
                      Button(
                        title: model_attribute(CashInstallment, :pay),
                        class: "flex-1 md:flex-none md:min-w-32",
                        data: { action: "click->datatable#prepareBulkAction", modal_target: "cashInstallmentsModal", modal_toggle: "cashInstallmentsModal" }
                      ) do
                        model_attribute(CashInstallment, :pay)
                      end

                      Button(
                        title: model_attribute(CashInstallment, :transfer),
                        class: "flex-1 md:flex-none md:min-w-32",
                        data: { action: "click->datatable#prepareBulkAction", modal_target: "transferMultipleModal", modal_toggle: "transferMultipleModal" }
                      ) do
                        model_attribute(CashInstallment, :transfer)
                      end
                    end
                  end
                end
              end
            end

            div(class: "md:hidden") do
              link_to(
                "#",
                class: "opacity-0 translate-y-2 pointer-events-none flex items-center justify-center fixed bottom-24 right-3 h-12 w-12 bg-gray-300/95 text-black rounded-full shadow-lg z-50 transition-all duration-200",
                style: "display: flex; visibility: hidden;",
                data: { mobile_scroll_nav: "bottom" }
              ) do
                cached_icon :bigger_bottom
              end

              link_to(
                new_cash_transaction_path(format: :turbo_stream),
                class: "flex items-center justify-center fixed bottom-4 right-3 h-14 w-14 bg-blue-600 text-white rounded-full shadow-lg z-50",
                data: { turbo_frame: :_top, mobile_scroll_nav: "plus" }
              ) do
                cached_icon :bigger_plus
              end

              link_to(
                "#",
                class: "opacity-0 translate-y-2 pointer-events-none flex items-center justify-center fixed bottom-24 right-3 h-12 w-12 bg-gray-300/95 text-black rounded-full shadow-lg z-50 transition-all duration-200",
                style: "display: flex; visibility: hidden;",
                data: { mobile_scroll_nav: "top" }
              ) do
                cached_icon :bigger_top
              end
            end
          end
        end
      end
    end
  end
end
