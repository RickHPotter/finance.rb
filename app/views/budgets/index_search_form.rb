# frozen_string_literal: true

class Views::Budgets::IndexSearchForm < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :index_context, :current_user,
              :default_year, :years, :active_month_years, :search_term,
              :category_id, :entity_id,
              :categories, :entities,
              :count_by_month_year,
              :mobile

  def initialize(index_context: {}, mobile: false)
    @index_context = index_context
    @current_user = index_context[:current_user]
    @default_year = index_context[:default_year]
    @years = index_context[:years]
    @active_month_years = index_context[:active_month_years]
    @search_term = index_context[:search_term]
    @category_id = index_context[:category_id]
    @entity_id = index_context[:entity_id]
    @count_by_month_year = index_context[:count_by_month_year] || {}
    @mobile = mobile

    set_all_categories
    set_entities
  end

  def view_template
    form_with model: Budget.new,
              url: budgets_path,
              id: :search_form,
              method: :get,
              class: "w-full",
              data: { controller: "reactive-form price-mask", action: "submit->price-mask#removeMasks" } do |form|
      build_month_year_selector

      div(class: "flex justify-between items-center gap-2") do
        TextFieldTag \
          :search_term,
          svg: :magnifying_glass,
          clearable: true,
          placeholder: "#{action_message(:search)}...",
          value: search_term,
          data: { controller: "cursor", action: "input->reactive-form#submitWithDelay" }

        if mobile
          Sheet(id: "advanced_filter") do
            SheetTrigger do
              Button(type: :button, icon: true, class: "scale-105") do
                cached_icon(:filter)
              end
            end

            SheetContent(side: :middle, class: "w-4/5 lg:w-1/2", data: { action: "close->reactive-form#submit" }) do
              SheetHeader do
                SheetTitle { pluralise_model(Budget, 2) }
                SheetDescription { I18n.t(:advanced_filter) }
              end

              SheetMiddle do
                div class: "grid grid-cols-1 gap-y-2 mb-2 w-full" do
                  div do
                    render Views::Categories::Combobox.new(name: "budget[category_id][]", categories:, selected_category_ids:)
                  end

                  div do
                    render Views::Entities::Combobox.new(name: "budget[entity_id][]", entities:, selected_entity_ids:)
                  end
                end
              end
            end
          end
        end
      end

      unless mobile
        div(class: "flex gap-2 mt-1") do
          div(class: "w-1/2") do
            render Views::Categories::Combobox.new(name: "budget[category_id][]", categories:, selected_category_ids:)
          end

          div(class: "w-1/2") do
            render Views::Entities::Combobox.new(name: "budget[entity_id][]", entities:, selected_entity_ids:)
          end
        end
      end

      form.submit :search, class: :hidden
    end
  end

  def build_month_year_selector
    div class: "mb-6 flex gap-4 flex-wrap" do
      render Views::Shared::MonthYearSelector.new(current_user:, form_id: :search_form, default_year:, years:, active_month_years:, count_by_month_year:) do
        link_to new_budget_path(format: :turbo_stream),
                id: "new_card_transaction",
                class: "hidden md:flex py-2 px-3 rounded-sm shadow-sm border border-purple-600 bg-transparent hover:bg-purple-600 transition-colors
                        text-black hover:text-white font-thin items-center gap-2",
                data: { turbo_frame: :_top, turbo_prefetch: false } do
          span { action_message(:new) }
          span { pluralise_model(Budget, 1) }
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
