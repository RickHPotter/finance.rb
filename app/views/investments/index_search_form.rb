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
              :user_bank_account_id,
              :user_bank_accounts

  def initialize(index_context: {})
    @index_context = index_context
    @current_user = index_context[:current_user]
    @default_year = index_context[:default_year]
    @years = index_context[:years]
    @active_month_years = index_context[:active_month_years]
    @search_term = index_context[:search_term]
    @user_bank_account_id = index_context[:user_bank_account_id]

    set_user_bank_accounts
  end

  def view_template
    form_with model: Investment.new,
              url: investments_path,
              id: :search_form,
              method: :get,
              class: "w-full",
              data: { controller: "reactive-form price-mask", action: "submit->price-mask#removeMasks" } do |form|
      build_month_year_selector

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

        Sheet do
          SheetTrigger do
            Button(type: :button, icon: true) do
              cached_icon(:filter)
            end
          end

          SheetContent(side: :middle, class: "w-4/5 lg:w-1/2", data: { action: "close->reactive-form#submit" }) do
            SheetHeader do
              SheetTitle { pluralise_model(Investment, 2) }
              SheetDescription { I18n.t(:advanced_filter) }
            end

            SheetMiddle do
              div class: "grid grid-cols-1 gap-y-2 mb-2 w-full" do
                form.select :user_bank_account_id, user_bank_accounts,
                            { multiple: true, selected: user_bank_account_id },
                            { class: input_class, data: { controller: "select", placeholder: pluralise_model(UserBankAccount, 2) } }
              end
            end
          end
        end
      end
    end
  end

  def build_month_year_selector
    div class: "mb-6 flex gap-4 flex-wrap" do
      render Views::Shared::MonthYearSelector.new(current_user:, form_id: :search_form, default_year:, years:, active_month_years:) do
        link_to new_investment_path(format: :turbo_stream),
                id: "new_card_transaction",
                class: "hidden md:flex py-2 px-3 rounded-sm shadow-sm border border-purple-600 bg-transparent hover:bg-purple-600 transition-colors
                        text-black hover:text-white font-thin items-center gap-2",
                data: { turbo_frame: :center_container, turbo_prefetch: false } do
          span { action_message(:new) }
          span { pluralise_model(Investment, 1) }
        end
      end
    end
  end
end
