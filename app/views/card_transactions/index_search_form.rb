# frozen_string_literal: true

class Views::CardTransactions::IndexSearchForm < Views::Base
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
              :sort, :direction,
              :user_card, :categories, :entities,
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
    @sort = index_context[:sort]
    @direction = index_context[:direction]
    @user_card = index_context[:user_card]
    @count_by_month_year = index_context[:count_by_month_year] || {}
    @mobile = mobile

    set_all_categories
    set_entities
  end

  def view_template
    form_with model: CardTransaction.new,
              url:,
              id: :search_form,
              method: :get,
              class: "w-full",
              data: { controller: "reactive-form price-mask", action: "submit->price-mask#removeMasks" } do |form|
      build_month_year_selector

      TextFieldTag :user_card_id, class: :hidden, value: params[:user_card_id] || params.dig(:card_transaction, :user_card_id) || user_card&.id
      input type: "hidden", name: :sort, value: sort, id: "card_transactions_sort"
      input type: "hidden", name: :direction, value: direction, id: "card_transactions_direction"

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
            render Views::Categories::Combobox.new(name: "card_transaction[category_id][]", categories:, selected_category_ids:)

            render Views::Entities::Combobox.new(name: "card_transaction[entity_id][]", entities:, selected_entity_ids:)
          end
        end

        unless mobile
          div(class: "flex items-center gap-2") do
            Sheet(id: "advanced_filter") do
              SheetTrigger do
                Button(type: :button, icon: true, class: "scale-105") do
                  cached_icon(:filter)
                end
              end

              SheetContent(side: :middle, class: "w-4/5 lg:w-1/2", data: { action: "close->reactive-form#submit" }) do
                SheetHeader do
                  SheetTitle { pluralise_model(CardTransaction, 2) }
                  SheetDescription { I18n.t(:advanced_filter) }
                end

                SheetMiddle do
                  if mobile
                    div class: "grid grid-cols-1 gap-y-2 mb-2 w-full" do
                      div do
                        render Views::Categories::Combobox.new(name: "card_transaction[category_id][]", categories:, selected_category_ids:)
                      end

                      div do
                        render Views::Entities::Combobox.new(name: "card_transaction[entity_id][]", entities:, selected_entity_ids:)
                      end
                    end
                  end

                  PriceRangeFields(
                    form:,
                    object: CardTransaction,
                    from_field: :from_ct_price,
                    to_field: :to_ct_price,
                    from_value: from_ct_price,
                    to_value: to_ct_price,
                    subject_label_key: :self
                  )

                  PriceRangeFields(
                    form:,
                    object: CardTransaction,
                    from_field: :from_price,
                    to_field: :to_price,
                    from_value: from_price,
                    to_value: to_price,
                    subject_label_key: :card_installment
                  )

                  InstallmentsCountRangeFields(
                    form:,
                    from_field: :from_installments_count,
                    to_field: :to_installments_count,
                    from_value: from_installments_count,
                    to_value: to_installments_count,
                    subject_label_key: :card_installment
                  )
                end
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
        link_to new_card_transaction_path(user_card_id: user_card&.id, format: :turbo_stream),
                id: "new_card_transaction",
                class: "hidden md:flex py-2 px-3 rounded-sm shadow-sm border border-purple-600 bg-transparent hover:bg-purple-600 transition-colors
                        text-black hover:text-white font-thin items-center gap-2",
                data: { turbo_frame: "_top", turbo_prefetch: false } do
          span { action_message(:newa) }
          span { pluralise_model(CardTransaction, 1) }
          span(id: "month_year_selector_title") { user_card.user_card_name } if user_card.present?
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

  def filter_summary
    @filter_summary ||= IndexState::FilterSummary.new(surface: :card_transactions, index_context:).to_h
  end

  def clear_filters_path
    user_card.present? ? "#{url}?#{{ user_card_id: user_card.id }.to_query}" : url
  end

  def render_mobile_sort_select
    return unless mobile

    render Views::Shared::SortPresetSelect.new(
      input_id: "card_transactions_sort_preset",
      options: mobile_sort_options,
      selected_value: "#{sort}:#{direction}"
    )
  end

  def mobile_sort_options
    asc = I18n.t("sorting.direction.asc")
    desc = I18n.t("sorting.direction.desc")

    [
      [ "#{model_attribute(CardTransaction, :card_installment_date)} (#{asc})", "installment_date:asc" ],
      [ "#{model_attribute(CardTransaction, :card_installment_date)} (#{desc})", "installment_date:desc" ],
      [ "#{model_attribute(CardTransaction, :card_transaction_date)} (#{asc})", "transaction_date:asc" ],
      [ "#{model_attribute(CardTransaction, :card_transaction_date)} (#{desc})", "transaction_date:desc" ],
      [ "#{model_attribute(CardTransaction, :description)} (#{asc})", "description:asc" ],
      [ "#{model_attribute(CardTransaction, :description)} (#{desc})", "description:desc" ],
      [ "#{model_attribute(CardTransaction, :price)} (#{asc})", "price:asc" ],
      [ "#{model_attribute(CardTransaction, :price)} (#{desc})", "price:desc" ]
    ]
  end

  def sort_toolbar_options
    [
      { label: model_attribute(CardTransaction, :card_installment_date), field: "installment_date" },
      { label: model_attribute(CardTransaction, :card_transaction_date), field: "transaction_date" },
      { label: model_attribute(CardTransaction, :description), field: "description" },
      { label: model_attribute(CardTransaction, :price), field: "price" }
    ]
  end
end
