# frozen_string_literal: true

class Views::CardTransactions::Index < Views::Base
  include Views::CardTransactions
  include Phlex::Rails::Helpers::LinkTo

  include CacheHelper

  attr_reader :index_context, :current_user, :user_card, :search, :url

  def initialize(index_context: {}, search: false)
    @index_context = index_context
    @current_user = index_context[:current_user]
    @user_card = index_context[:user_card]
    @search = search
  end

  def view_template
    @url = search ? search_card_transactions_path : card_transactions_path

    turbo_frame_tag :center_container do
      div class: "w-full" do
        div class: "min-w-full pt-2" do
          turbo_frame_tag :card_transactions do
            div class: "min-h-screen", data: { controller: "datatable" } do
              div class: "mb-6 flex sm:flex-row gap-4 items-start sm:items-center justify-between bg-white p-4 rounded-lg shadow-sm" do
                render IndexSearchForm.new(url:, index_context:)
              end

              div class: "flex justify-end p-4" do
                span(id: :totalPriceSum)
              end

              render MonthYearContainer.new(index_context: index_context.slice(:search_term, :category_id, :entity_id,
                                                                               :from_ct_price, :to_ct_price, :from_price, :to_price,
                                                                               :from_installments_count, :to_installments_count,
                                                                               :user_card, :active_month_years))
            end

            link_to new_card_transaction_path(user_card_id: user_card&.id, format: :turbo_stream),
                    style: "margin: 30px",
                    class: "flex md:hidden fixed bottom-0 right-0 bg-blue-600 text-white rounded-full shadow-lg items-center justify-center z-50
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
