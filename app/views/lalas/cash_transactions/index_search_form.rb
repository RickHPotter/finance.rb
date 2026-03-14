# frozen_string_literal: true

class Views::Lalas::CashTransactions::IndexSearchForm < Views::Base
  include Phlex::Rails::Helpers::FormWith

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :index_context, :current_user,
              :default_year, :years, :active_month_years, :search_term,
              :category_id, :entity_id, :paid, :pending,
              :user_bank_account_id, :categories, :entities,
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
    @paid = index_context[:paid]
    @pending = index_context[:pending]
    @user_bank_account_id = index_context[:user_bank_account_id]
    @count_by_month_year = index_context[:count_by_month_year] || {}
  end

  def view_template
    form_with url: lalas_cash_transactions_path,
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

      form.text_field :user_bank_account_id,
                      value: params[:user_bank_account_id] || params.dig(:cash_transaction, :user_bank_account_id) || user_bank_account_id,
                      class: :hidden

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

        div do
          div(class: "grid grid-cols-2 items-center justify-center w-full mx-auto") do
            div(class: "flex justify-center items-center") do
              Switch(name: :paid, checked: paid.nil? || paid, data: { action: "change->reactive-form#submit" })
            end

            div(class: "flex justify-center items-center") do
              Switch(name: :pending, checked: pending.nil? || pending, data: { action: "change->reactive-form#submit" })
            end

            span(class: "font-poetsen-one font-thin text-xs text-gray-500") { model_attribute(CashTransaction, :paid) }
            span(class: "font-poetsen-one font-thin text-xs text-gray-500") { model_attribute(CashTransaction, :not_paid) }
          end
        end
      end

      form.submit :search, class: :hidden
    end
  end
end
