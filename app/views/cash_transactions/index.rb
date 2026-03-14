# frozen_string_literal: true

class Views::CashTransactions::Index < Views::Base
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

              BulkActionBar(
                selected_label: action_message(:selected),
                actions: [
                  {
                    title: model_attribute(CashInstallment, :pay),
                    label: model_attribute(CashInstallment, :pay),
                    data: { action: "click->datatable#prepareBulkAction", modal_target: "cashInstallmentsModal", modal_toggle: "cashInstallmentsModal" }
                  },
                  {
                    title: model_attribute(CashInstallment, :transfer),
                    label: model_attribute(CashInstallment, :transfer),
                    data: { action: "click->datatable#prepareBulkAction", modal_target: "transferMultipleModal", modal_toggle: "transferMultipleModal" }
                  }
                ]
              )
            end

            render Views::Shared::MobileFloatingNav.new(new_href: new_cash_transaction_path(format: :turbo_stream))
          end
        end
      end
    end
  end
end
