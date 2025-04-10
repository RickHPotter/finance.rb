# frozen_string_literal: true

module Views
  module Investments
    class Index < Views::Base
      attr_reader :current_user, :investments

      def initialize(current_user:, investments:)
        @current_user = current_user
        @investments = investments
      end

      def view_template
        turbo_frame_tag :center_container do
          div class: "w-full" do
            div class: "min-w-full pt-2" do
              turbo_frame_tag :investments do
                div class: "min-h-screen", data: { controller: "datatable" } do
                  div class: "mb-6 flex sm:flex-row gap-4 items-start sm:items-center justify-between bg-white p-4 rounded-lg shadow-sm" do
                    render IndexSearchForm.new(default_year: @default_year)
                  end

                  div class: "flex justify-end p-4" do
                    content_tag :span, nil, id: :totalPriceSum
                  end

                  render "investments/month_year_container", user_card_id: params[:user_card_id].presence || params.dig(:investment, :user_card_id).presence || @user_card_id,
                                                             search_term: @search_term,
                                                             category_ids: @category_ids,
                                                             entity_ids: @entity_ids,
                                                             from_ct_price: @from_ct_price,
                                                             to_ct_price: @to_ct_price,
                                                             from_price: @from_price,
                                                             to_price: @to_price,
                                                             from_installments_count: @from_installments_count,
                                                             to_installments_count: @to_installments_count,
                                                             active_month_years: @active_month_years
                end

                link_to new_investment_path(user_card_id: @user_card.id, format: :turbo_stream),
                        style: "margin: 30px",
                        class: "block md:hidden fixed bottom-0 right-0 bg-blue-600 text-white rounded-full shadow-lg flex items-center justify-center z-50 active:scale-95 transition-transform",
                        data: { turbo_frame: :center_container } do
                  render_icon :bigger_plus
                end
              end
            end
          end
        end
      end
    end
  end
end
