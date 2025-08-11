# frozen_string_literal: true

class Views::CashTransactions::IndexSearchForm < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::CheckBoxTag

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
              :paid, :pending,
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
    @paid = index_context[:paid]
    @pending = index_context[:pending]
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
              data: { controller: "reactive-form price-mask", action: "submit->price-mask#removeMasks" } do |form|
      build_month_year_selector

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

        Sheet(id: "advanced_filter") do
          SheetTrigger do
            Button(type: :button, icon: true) do
              cached_icon(:filter)
            end
          end

          SheetContent(side: :middle, class: "w-4/5 lg:w-1/2", data: { action: "close->reactive-form#submit" }) do
            SheetHeader do
              SheetTitle { pluralise_model(CashTransaction, 2) }
              SheetDescription { I18n.t(:advanced_filter) }
            end

            SheetMiddle do
              div class: "grid grid-cols-1 gap-y-2 mb-2 w-full" do
                form.select :category_id, categories,
                            { multiple: true, selected: category_id },
                            { class: input_class, data: { controller: "select", placeholder: pluralise_model(Category, 2) } }

                form.select :entity_id, entities,
                            { multiple: true, selected: entity_id },
                            { class: input_class, data: { controller: "select", placeholder: pluralise_model(Entity, 2) } }

                div(class: "grid grid-cols-2 gap-y-2 items-center justify-center w-full mx-auto") do
                  thin__label(form, :paid)
                  thin__label(form, :not_paid)

                  div(class: "flex justify-center items-center") do
                    Switch(name: :paid, checked: paid.nil? || paid)
                  end

                  div(class: "flex justify-center items-center") do
                    Switch(name: :pending, checked: pending.nil? || pending)
                  end
                end
              end

              div class: "grid grid-cols-11 gap-y-1 my-auto mb-2" do
                div class: "col-span-11 font-graduate flex gap-1 justify-center" do
                  thin__label(form, :price)
                  thin__label(form, :self)
                end

                div class: "col-span-11 lg:col-span-5 my-auto" do
                  TextFieldTag \
                    :from_ct_price,
                    svg: :money,
                    value: from_ct_price,
                    placeholder: model_attribute(CashTransaction, :from_ct_price),
                    data: { price_mask_target: :input, action: "input->price-mask#applyMask" }
                end

                div(class: "hidden lg:flex m-auto") do
                  cached_icon :exchange
                end

                div class: "col-span-11 lg:col-span-5 my-auto" do
                  TextFieldTag \
                    :to_ct_price,
                    svg: :money,
                    value: to_ct_price,
                    placeholder: model_attribute(CashTransaction, :to_ct_price),
                    data: { price_mask_target: :input, action: "input->price-mask#applyMask" }
                end
              end

              div class: "grid grid-cols-11 gap-y-1 my-auto mb-2" do
                div class: "col-span-11 font-graduate flex gap-1 justify-center" do
                  thin__label(form, :price)
                  thin__label(form, :cash_installment)
                end

                div class: "col-span-11 lg:col-span-5 my-auto" do
                  TextFieldTag \
                    :from_price,
                    svg: :money,
                    value: from_price,
                    placeholder: model_attribute(CashTransaction, :from_price),
                    data: { price_mask_target: :input, action: "input->price-mask#applyMask" }
                end

                div(class: "hidden lg:flex m-auto") do
                  cached_icon :exchange
                end

                div class: "col-span-11 lg:col-span-5 my-auto" do
                  TextFieldTag \
                    :to_price,
                    svg: :money,
                    value: to_price || nil,
                    data: { price_mask_target: :input, action: "input->price-mask#applyMask" }
                end
              end

              div class: "grid grid-cols-11 my-auto mb-1" do
                div class: "col-span-11 font-graduate flex gap-1 justify-center" do
                  thin__label(form, :count)
                  thin__label(form, :cash_installment)
                end

                div class: "col-span-5 my-auto" do
                  TextFieldTag \
                    :from_installments_count,
                    type: :number,
                    svg: :number,
                    min: 1, max: 72,
                    value: from_installments_count || 1
                end

                div(class: "m-auto") do
                  cached_icon :exchange
                end

                div class: "col-span-5 my-auto" do
                  TextFieldTag \
                    :to_installments_count,
                    type: :number,
                    svg: :number,
                    min: 1, max: 72,
                    value: to_installments_count || 72
                end
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
