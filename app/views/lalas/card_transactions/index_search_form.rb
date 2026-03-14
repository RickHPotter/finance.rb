# frozen_string_literal: true

class Views::Lalas::CardTransactions::IndexSearchForm < Views::Base
  include Phlex::Rails::Helpers::FormWith

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :index_context, :current_user,
              :default_year, :years, :active_month_years, :search_term,
              :category_id, :entity_id,
              :user_card,
              :count_by_month_year

  def initialize(index_context: {})
    @index_context = index_context
    @current_user = index_context[:current_user]
    @default_year = index_context[:default_year]
    @years = index_context[:years]
    @active_month_years = index_context[:active_month_years]
    @search_term = index_context[:search_term]
    @category_id = index_context[:category_id]
    @entity_id = index_context[:entity_id]
    @user_card = index_context[:user_card]
    @count_by_month_year = index_context[:count_by_month_year] || {}
  end

  def view_template
    form_with url: lalas_card_transactions_path,
              id: :search_form,
              method: :get,
              class: "w-full",
              data: { controller: "reactive-form price-mask", action: "submit->price-mask#removeMasks" } do |form|
      div class: "mb-6 flex gap-4 flex-wrap" do
        render Views::Shared::MonthYearSelector.new(
          current_user:,
          default_year:,
          years:,
          active_month_years:,
          count_by_month_year:
        )
      end

      TextFieldTag :user_card_id, class: :hidden, value: params[:user_card_id] || params.dig(:card_transaction, :user_card_id) || user_card&.id

      div(class: "flex justify-between items-center gap-2") do
        div(class: "flex-1") do
          TextFieldTag \
            :search_term,
            svg: :magnifying_glass,
            clearable: true,
            placeholder: "#{action_message(:search)}...",
            value: search_term,
            data: { controller: "cursor", action: "input->reactive-form#submitWithDelay" }
        end
      end

      form.submit :search, class: :hidden
    end
  end
end
