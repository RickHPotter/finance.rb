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
              :from_date, :to_date,
              :paid, :pending,
              :user_bank_account_id, :categories, :entities,
              :count_by_month_year,
              :mobile

  def initialize(url:, index_context: {}, mobile: false)
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
    @from_date = index_context[:from_date]
    @to_date = index_context[:to_date]
    @paid = index_context[:paid]
    @pending = index_context[:pending]
    @user_bank_account_id = index_context[:user_bank_account_id]
    @count_by_month_year = index_context[:count_by_month_year] || {}
    @mobile = mobile

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

      form.text_field :user_bank_account_id, value: params[:user_bank_account_id] || user_bank_account_id, class: :hidden

      div(class: "flex justify-between items-center gap-2") do
        TextFieldTag \
          :search_term,
          svg: :magnifying_glass,
          clearable: true,
          placeholder: "#{action_message(:search)}...",
          value: search_term,
          data: { controller: "cursor", action: "input->reactive-form#submitWithDelay" }

        Sheet(id: "advanced_filter") do
          SheetTrigger do
            Button(type: :button, icon: true, class: "scale-105") do
              cached_icon(:filter)
            end
          end

          SheetContent(side: :middle, class: "w-4/5 lg:w-1/2", data: { action: "close->reactive-form#submit" }) do
            SheetHeader do
              SheetTitle { pluralise_model(CashTransaction, 2) }
              SheetDescription { I18n.t(:advanced_filter) }
            end

            SheetMiddle do
              if mobile
                div class: "grid grid-cols-1 gap-y-2 mb-2 w-full" do
                  div do
                    render Views::Categories::Combobox.new(name: "cash_transaction[category_id][]", categories:, selected_category_ids:)
                  end

                  div do
                    render Views::Entities::Combobox.new(name: "cash_transaction[entity_id][]", entities:, selected_entity_ids:)
                  end
                end
              end

              div class: "grid grid-cols-1 gap-y-2 mb-2 w-full" do
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

              PriceRangeFields(
                form:,
                object: CashTransaction,
                from_field: :from_ct_price,
                to_field: :to_ct_price,
                from_value: from_ct_price,
                to_value: to_ct_price,
                subject_label_key: :self
              )

              PriceRangeFields(
                form:,
                object: CashTransaction,
                from_field: :from_price,
                to_field: :to_price,
                from_value: from_price,
                to_value: to_price,
                subject_label_key: :cash_installment
              )

              InstallmentsCountRangeFields(
                form:,
                from_field: :from_installments_count,
                to_field: :to_installments_count,
                from_value: from_installments_count || 1,
                to_value: to_installments_count || 72,
                subject_label_key: :cash_installment
              )

              DateRangeFields(
                form:,
                from_field: :from_date,
                to_field: :to_date,
                from_value: from_date,
                to_value: to_date
              )
            end
          end
        end
      end

      unless mobile
        div(class: "flex gap-2 mt-1") do
          div(class: "w-1/2") do
            render Views::Categories::Combobox.new(name: "cash_transaction[category_id][]", categories:, selected_category_ids:)
          end

          div(class: "w-1/2") do
            render Views::Entities::Combobox.new(name: "cash_transaction[entity_id][]", entities:, selected_entity_ids:)
          end
        end
      end

      form.submit :search, class: :hidden
    end
  end

  def build_month_year_selector
    div class: "mb-6 flex gap-4 flex-wrap" do
      render Views::Shared::MonthYearSelector.new(current_user:, default_year:, years:, active_month_years:, count_by_month_year:) do
        link_to new_cash_transaction_path(format: :turbo_stream),
                id: "new_cash_transaction",
                class: "hidden md:flex py-2 px-3 rounded-sm shadow-sm border border-purple-600 bg-transparent hover:bg-purple-600 transition-colors
                        text-black hover:text-white font-thin items-center gap-2",
                data: { turbo_frame: "_top", turbo_prefetch: false } do
          span { action_message(:newa) }
          span { pluralise_model(CashTransaction, 1) }
        end
      end
    end
  end

  private

  def selected_category_ids
    Array(category_id).map(&:to_s)
  end

  def selected_entity_ids
    Array(entity_id).map(&:to_s)
  end
end
