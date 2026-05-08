# frozen_string_literal: true

class Views::CashTransactions::IndexSearchForm < Views::Base # rubocop:disable Metrics/ClassLength
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
              :exchange_bound_type,
              :paid, :pending, :paid_state,
              :sort, :direction,
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
    @exchange_bound_type = index_context[:exchange_bound_type]
    @paid = index_context[:paid]
    @pending = index_context[:pending]
    @paid_state = index_context[:paid_state]
    @sort = index_context[:sort]
    @direction = index_context[:direction]
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
      input type: "hidden", name: :paid_state, value: paid_state || "all", id: "cash_transactions_paid_state"
      input type: "hidden", name: :paid, value: paid, id: "cash_transactions_paid"
      input type: "hidden", name: :pending, value: pending, id: "cash_transactions_pending"
      input type: "hidden", name: :sort, value: sort, id: "cash_transactions_sort"
      input type: "hidden", name: :direction, value: direction, id: "cash_transactions_direction"

      div(class: "flex items-center gap-2") do
        div(class: mobile ? "w-full" : "grid flex-1 grid-cols-3 gap-2") do
          TextFieldTag \
            :search_term,
            svg: :magnifying_glass,
            clearable: true,
            placeholder: "#{action_message(:search)}...",
            value: search_term,
            data: { controller: "cursor", action: "input->reactive-form#submitWithDelay" }

          unless mobile
            render Views::Categories::Combobox.new(name: "cash_transaction[category_id][]", categories:, selected_category_ids:)
            render Views::Entities::Combobox.new(name: "cash_transaction[entity_id][]", entities:, selected_entity_ids:)
          end
        end

        div(class: "flex shrink-0 items-center gap-2") do
          Sheet(id: "advanced_filter") do
            SheetTrigger do
              Button(type: :button, icon: true, class: "scale-105") do
                cached_icon(:filter)
              end
            end

            SheetContent(
              side: :middle,
              class: "w-4/5 lg:w-1/2",
              data: { action: "input->reactive-form#markChanged change->reactive-form#markChanged close->reactive-form#submitIfChanged" }
            ) do
              SheetHeader do
                SheetTitle { pluralise_model(CashTransaction, 2) }
                SheetDescription { I18n.t(:advanced_filter) }
              end

              SheetMiddle do
                if mobile
                  div class: "grid grid-cols-1 gap-y-2 mb-2 w-full" do
                    render Views::Categories::Combobox.new(name: "cash_transaction[category_id][]", categories:, selected_category_ids:)
                    render Views::Entities::Combobox.new(name: "cash_transaction[entity_id][]", entities:, selected_entity_ids:)
                  end
                end

                render Views::CashTransactions::PaidStateFilter.new(current_state: paid_state || "all")

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
                  from_value: from_installments_count,
                  to_value: to_installments_count,
                  subject_label_key: :cash_installment
                )

                DateRangeFields(
                  form:,
                  from_field: :from_date,
                  to_field: :to_date,
                  from_value: from_date,
                  to_value: to_date
                )

                render Views::Shared::ExchangeBoundTypeFilter.new(current_state: exchange_bound_type, form_id: "search_form") if show_exchange_bound_type_filter?
              end
            end
          end

          render Views::Shared::ClearFiltersButton.new(href: clear_filters_path) if filter_summary[:active]
        end

        form.submit :search, class: :hidden
      end

      render_mobile_sort_select

      unless mobile
        render Views::Shared::IndexToolbar.new(
          summary: filter_summary,
          sort_options: sort_toolbar_options,
          current_sort: sort,
          current_direction: direction
        )
      end
    end
  end

  def build_month_year_selector
    div class: "mb-6 flex gap-4 flex-wrap" do
      render Views::Shared::MonthYearSelector.new(current_user:, default_year:, years:, active_month_years:, count_by_month_year:) do
        link_to new_cash_transaction_path(format: :turbo_stream),
                id: "new_cash_transaction",
                class: index_new_button_class,
                data: { turbo_frame: "_top", turbo_prefetch: false } do
          span { action_message(:newa) }
          span { pluralise_model(CashTransaction, 1) }
        end
      end
    end
  end

  private

  def selected_category_ids = Array(category_id).map(&:to_s)

  def selected_entity_ids = Array(entity_id).map(&:to_s)

  def show_exchange_bound_type_filter?
    exchange_bound_type.present? || selected_category_ids.include?(current_user.built_in_category("EXCHANGE RETURN").id.to_s)
  end

  def filter_summary = @filter_summary ||= IndexState::FilterSummary.new(surface: :cash_transactions, index_context:).to_h

  def clear_filters_path = url

  def render_mobile_sort_select
    return unless mobile

    render Views::Shared::SortPresetSelect.new(
      input_id: "cash_transactions_sort_preset",
      options: mobile_sort_options,
      selected_value: "#{sort}:#{direction}"
    )
  end

  def mobile_sort_options
    label = ->(attribute) { model_attribute(CashTransaction, attribute) }
    asc = I18n.t("sorting.direction.asc")
    desc = I18n.t("sorting.direction.desc")

    [
      [ "#{I18n.t('balances.types.default')} (#{asc})", "default:asc" ],
      [ "#{label.call(:cash_installment_date)} (#{asc})", "installment_date:asc" ], [ "#{label.call(:cash_installment_date)} (#{desc})", "installment_date:desc" ],
      [ "#{label.call(:cash_transaction_date)} (#{asc})", "transaction_date:asc" ], [ "#{label.call(:cash_transaction_date)} (#{desc})", "transaction_date:desc" ],
      [ "#{label.call(:description)} (#{asc})", "description:asc" ], [ "#{label.call(:description)} (#{desc})", "description:desc" ],
      [ "#{label.call(:price)} (#{asc})", "price:asc" ], [ "#{label.call(:price)} (#{desc})", "price:desc" ]
    ]
  end

  def sort_toolbar_options
    [
      { label: I18n.t("balances.types.default"), field: "default", reset: true },
      { label: model_attribute(CashTransaction, :cash_installment_date), field: "installment_date" },
      { label: model_attribute(CashTransaction, :cash_transaction_date), field: "transaction_date" },
      { label: model_attribute(CashTransaction, :description), field: "description" },
      { label: model_attribute(CashTransaction, :price), field: "price" }
    ]
  end
end
