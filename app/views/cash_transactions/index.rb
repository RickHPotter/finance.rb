# frozen_string_literal: true

class Views::CashTransactions::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Views::CashTransactions

  include CacheHelper

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

              render MonthYearContainer.new(index_context: index_context.slice(:search_term, :category_id, :entity_id,
                                                                               :from_ct_price, :to_ct_price, :from_price, :to_price,
                                                                               :from_installments_count, :to_installments_count, :paid, :pending,
                                                                               :from_date, :to_date,
                                                                               :user_bank_account_id, :active_month_years, :skip_budgets))
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
