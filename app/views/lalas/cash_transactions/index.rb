# frozen_string_literal: true

class Views::Lalas::CashTransactions::Index < Views::Base
  include Views::Lalas::CashTransactions

  include CacheHelper

  attr_reader :index_context, :current_user

  def initialize(index_context: {})
    @index_context = index_context
    @current_user = index_context[:current_user]
  end

  def view_template
    turbo_frame_tag :center_container do
      div class: "w-full" do
        div class: "min-w-full" do
          turbo_frame_tag :cash_transactions do
            div class: "min-h-screen", data: { controller: "datatable" } do
              div class: "mb-8 flex sm:flex-row gap-4 items-start sm:items-center justify-between bg-white p-4 rounded-lg shadow-sm" do
                render IndexSearchForm.new(index_context:)
              end

              render MonthYearContainer.new(index_context: index_context.slice(:search_term, :category_id, :entity_id,
                                                                               :user_bank_account_id, :paid, :pending,
                                                                               :active_month_years, :skip_budgets))
            end
          end
        end
      end
    end
  end
end
