# frozen_string_literal: true

class Views::Investments::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include CacheHelper

  attr_reader :index_context, :current_user,
              :default_year, :years, :active_month_years, :search_term

  def initialize(index_context: {})
    @index_context = index_context
    @current_user = index_context[:current_user]
    @default_year = index_context[:default_year]
    @years = index_context[:years]
    @active_month_years = index_context[:active_month_years]
    @search_term = index_context[:search_term]
  end

  def view_template
    turbo_frame_tag :center_container do
      div class: "w-full" do
        div class: "min-w-full pt-2" do
          turbo_frame_tag :card_transactions do
            div class: "min-h-screen", data: { controller: "datatable" } do
              div class: "mb-6 flex sm:flex-row gap-4 items-start sm:items-center justify-between bg-white p-4 rounded-lg shadow-sm" do
                render Views::Investments::IndexSearchForm.new(index_context:)
              end

              div class: "flex justify-end p-4" do
                span(id: :totalPriceSum)
              end

              render Views::Investments::MonthYearContainer.new(
                url_lambda: ->(args = {}) { month_year_investments_path(args) },
                index_context: index_context.slice(:search_term, :user_bank_account_ids, :active_month_years)
              )
            end

            link_to new_investment_path(format: :turbo_stream),
                    style: "margin: 30px",
                    class: "block md:hidden fixed bottom-0 right-0 bg-blue-600 text-white rounded-full shadow-lg flex items-center justify-center z-50
                           active:scale-95 transition-transform",
                    data: { turbo_frame: :center_container } do
              cached_icon :bigger_plus
            end
          end
        end
      end
    end
  end
end
