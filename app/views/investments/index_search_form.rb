# frozen_string_literal: true

class Views::Investments::IndexSearchForm < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :index_context, :current_user,
              :default_year, :years, :active_month_years, :search_term,
              :user_bank_account_ids,
              :user_bank_accounts

  def initialize(index_context: {})
    @index_context = index_context
    @current_user = index_context[:current_user]
    @default_year = index_context[:default_year]
    @years = index_context[:years]
    @active_month_years = index_context[:active_month_years]
    @search_term = index_context[:search_term]
    @user_bank_account_ids = index_context[:user_bank_account_ids]

    set_user_bank_accounts
  end

  def view_template
    form_with model: Investment.new,
              url: investments_path,
              id: :search_form,
              method: :get,
              class: "w-full",
              data: { controller: "form-validate reactive-form price-mask", action: "submit->price-mask#removeMasks" } do |form|
      build_month_year_selector

      form.text_field \
        :user_bank_account_id,
        value: params[:user_bank_account_id] || params.dig(:card_transaction, :user_bank_account_id),
        class: :hidden

      div class: "w-full mb-2" do
        TextField \
          form, :search_term,
          svg: :magnifying_glass,
          autofocus: true,
          placeholder: "#{action_message(:search)}...",
          value: search_term,
          data: { controller: "cursor", action: "input->reactive-form#submit" }
      end

      div class: "gap-y-2 mb-2" do
        form.select :user_bank_account_ids, user_bank_accounts,
                    { multiple: true, selected: user_bank_account_ids },
                    { class: input_class, data: { controller: "select", placeholder: pluralise_model(UserBankAccount, 2), action: "change->reactive-form#submit" } }
      end
    end
  end

  def build_month_year_selector
    div class: "mb-6 flex gap-4 flex-wrap" do
      render Views::Shared::MonthYearSelector.new(current_user:, form_id: :search_form, default_year:, years:, active_month_years:) do
        link_to new_investment_path(format: :turbo_stream),
                id: "new_card_transaction",
                class: "py-2 px-3 rounded-sm shadow-sm border border-purple-600 bg-transparent hover:bg-purple-600 transition-colors text-black
                        hover:text-white font-thin",
                data: { turbo_frame: :center_container, turbo_prefetch: false } do
          span { action_message(:new) }
          span { " " }
          span { pluralise_model(Investment, 1) }
        end
      end
    end
  end
end
