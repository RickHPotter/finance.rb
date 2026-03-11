# frozen_string_literal: true

class Views::CardTransactions::Index < Views::Base
  include Views::CardTransactions
  include Phlex::Rails::Helpers::LinkTo

  include CacheHelper

  attr_reader :index_context, :current_user, :user_card, :search, :url, :mobile

  def initialize(index_context: {}, search: false, mobile: false)
    @index_context = index_context
    @current_user = index_context[:current_user]
    @user_card = index_context[:user_card]
    @search = search
    @mobile = mobile
  end

  def view_template
    @url = search ? search_card_transactions_path : card_transactions_path

    turbo_frame_tag :center_container do
      div class: "w-full" do
        div class: "min-w-full" do
          turbo_frame_tag :card_transactions do
            div class: "min-h-screen", data: { controller: "datatable" } do
              div class: "mb-8 flex sm:flex-row gap-4 items-start sm:items-center justify-between bg-white p-4 rounded-lg shadow-sm" do
                render IndexSearchForm.new(url:, index_context:, mobile:)
              end

              render MonthYearContainer.new(index_context: index_context.slice(:search_term, :category_id, :entity_id,
                                                                               :from_ct_price, :to_ct_price, :from_price, :to_price,
                                                                               :from_installments_count, :to_installments_count,
                                                                               :user_card, :active_month_years, :order_by))
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
                new_card_transaction_path(user_card_id: user_card&.id, format: :turbo_stream),
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
