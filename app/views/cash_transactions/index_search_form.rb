# frozen_string_literal: true

class Views::CashTransactions::IndexSearchForm < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :url,
              :index_context, :current_user,
              :default_year, :years, :active_month_years, :search_term,
              :category_id, :entity_id,
              :from_ct_price, :to_ct_price,
              :from_price, :to_price,
              :from_installments_count, :to_installments_count,
              :user_bank_account_id, :categories, :entities

  def initialize(url:, index_context: {})
    @url = url
    @index_context = index_context
    @current_user = index_context[:current_user]
    @default_year = index_context[:default_year]
    @years = index_context[:years]
    @active_month_years = index_context[:active_month_years]
    @search_term = index_context[:search_term]
    @category_id = index_context[:category_id]
    @entity_id = index_context[:entity_id]
    @from_ct_price = index_context[:from_ct_price]
    @to_ct_price = index_context[:to_ct_price]
    @from_price = index_context[:from_price]
    @to_price = index_context[:to_price]
    @from_installments_count = index_context[:from_installments_count]
    @to_installments_count = index_context[:to_installments_count]
    @user_bank_account_id = index_context[:user_bank_account_id]

    set_all_categories
    set_entities
  end

  def view_template
    form_with model: CashTransaction.new,
              url:,
              id: :search_form,
              method: :get,
              class: "w-full",
              data: { controller: "form-validate reactive-form price-mask", action: "submit->price-mask#removeMasks" } do |form|
      build_month_year_selector

      form.text_field :user_bank_account_id,
                      value: params[:user_bank_account_id] || params.dig(:cash_transaction, :user_bank_account_id) || user_bank_account_id,
                      class: :hidden

      div class: "w-full mb-2" do
        TextFieldTag \
          :search_term,
          svg: :magnifying_glass,
          autofocus: true,
          placeholder: "#{action_message(:search)}...",
          value: search_term,
          data: { controller: "cursor", action: "input->reactive-form#submit" }
      end

      details(open: category_id.present? || entity_id.present?) do
        summary(class: "pb-1") { I18n.t(:advanced_filter) }

        div class: "grid grid-cols-1 gap-y-2 mb-2" do
          form.select :category_id, categories,
                      { multiple: true, selected: category_id },
                      { class: input_class, data: { controller: "select", placeholder: pluralise_model(Category, 2), action: "change->reactive-form#submit" } }

          form.select :entity_id, entities,
                      { multiple: true, selected: entity_id },
                      { class: input_class, data: { controller: "select", placeholder: pluralise_model(Entity, 2), action: "change->reactive-form#submit" } }
        end

        div class: "grid grid-cols-38 gap-x-2 font-graduate" do
          div class: "col-span-16 lg:col-span-5 my-auto" do
            TextFieldTag \
              :from_ct_price,
              svg: :money,
              value: from_ct_price || from_cent_based_to_float(0, "R$"),
              data: { price_mask_target: :input, action: "input->price-mask#applyMask change->reactive-form#submit" }
          end

          div class: "col-span-6 lg:col-span-2 flex flex-col items-center justify-self-center scale-75" do
            thin__label(form, :price)
            cached_icon :exchange
            thin__label(form, :self)
          end

          div class: "col-span-16 lg:col-span-5 my-auto" do
            TextFieldTag \
              :to_ct_price,
              svg: :money,
              value: to_ct_price || nil,
              data: { price_mask_target: :input, action: "input->price-mask#applyMask change->reactive-form#submit" }
          end

          hr class: "hidden lg:block transform rotate-90 my-auto border-1 border-slate-300"

          div(class: "col-span-16 lg:col-span-5 my-auto") do
            TextFieldTag \
              :from_price,
              svg: :money,
              value: from_price || from_cent_based_to_float(0, "R$"),
              data: { price_mask_target: :input, action: "input->price-mask#applyMask change->reactive-form#submit" }
          end

          div class: "col-span-6 lg:col-span-2 flex flex-col items-center justify-self-center scale-75 mt-[-0.5rem]" do
            thin__label(form, :price)
            cached_icon :exchange
            thin__label(form, :cash_installment)
          end

          div class: "col-span-16 lg:col-span-5 my-auto" do
            TextFieldTag \
              :to_price,
              svg: :money,
              value: to_price || nil,
              data: { price_mask_target: :input, action: "input->price-mask#applyMask change->reactive-form#submit" }
          end

          hr class: "hidden lg:block transform rotate-90 my-auto border-1 border-slate-300"

          div class: "col-span-16 lg:col-span-5 my-auto" do
            TextFieldTag \
              :from_installments_count,
              type: :number,
              svg: :number,
              min: 1, max: 72, value: from_installments_count || 1,
              data: { action: "input->reactive-form#submit" }
          end

          div class: "col-span-6 lg:col-span-2 flex flex-col items-center justify-self-center scale-75 mt-[-0.5rem]" do
            thin__label(form, :count)
            cached_icon :exchange
            thin__label(form, :cash_installment)
          end

          div class: "col-span-16 lg:col-span-5 my-auto" do
            TextFieldTag \
              :to_installments_count,
              type: :number,
              svg: :number,
              min: 1, max: 72, value: to_installments_count || 72,
              data: { action: "input->reactive-form#submit" }
          end
        end
      end
    end
  end

  def build_month_year_selector
    div class: "mb-6 flex gap-4 flex-wrap" do
      render Views::Shared::MonthYearSelector.new(current_user:, form_id: :search_form, default_year:, years:, active_month_years:) do
        link_to new_cash_transaction_path(format: :turbo_stream),
                id: "new_cash_transaction",
                class: "hidden md:flex py-2 px-3 rounded-sm shadow-sm border border-purple-600 bg-transparent hover:bg-purple-600 transition-colors
                        text-black hover:text-white font-thin items-center gap-2",
                data: { turbo_frame: :center_container, turbo_prefetch: false } do
          span { action_message(:newa) }
          span { pluralise_model(CashTransaction, 1) }
        end
      end
    end
  end
end
