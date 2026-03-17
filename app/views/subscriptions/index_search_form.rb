# frozen_string_literal: true

class Views::Subscriptions::IndexSearchForm < Views::Base
  include Phlex::Rails::Helpers::FormWith

  include TranslateHelper
  include ComponentsHelper
  include CacheHelper
  include ContextHelper

  attr_reader :index_context, :current_user,
              :search_term, :category_id, :entity_id, :status,
              :categories, :entities,
              :mobile

  def initialize(index_context: {}, mobile: false)
    @index_context = index_context
    @current_user = index_context[:current_user]
    @search_term = index_context[:search_term]
    @category_id = index_context[:category_id]
    @entity_id = index_context[:entity_id]
    @status = index_context[:status]
    @mobile = mobile

    set_all_categories
    set_entities
  end

  def view_template
    form_with model: Subscription.new,
              url: subscriptions_path,
              id: :search_form,
              method: :get,
              class: "w-full",
              data: { controller: "reactive-form" } do |_form|
      div(class: "flex items-center gap-2") do
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
                SheetTitle { pluralise_model(Subscription, 2) }
                SheetDescription { I18n.t(:advanced_filter) }
              end

              SheetMiddle do
                div(class: "grid grid-cols-1 gap-y-2 mb-2 w-full") do
                  div do
                    render Views::Categories::Combobox.new(name: "subscription[category_id][]", categories:, selected_category_ids:)
                  end

                  div do
                    render Views::Entities::Combobox.new(name: "subscription[entity_id][]", entities:, selected_entity_ids:)
                  end

                  div do
                    render Views::Subscriptions::StatusesCombobox.new(name: "subscription[status][]", selected_statuses:)
                  end
                end
              end
            end
          end
        end
      end

      unless mobile
        div(class: "mt-1 flex gap-2") do
          div(class: "w-1/3") do
            render Views::Categories::Combobox.new(name: "subscription[category_id][]", categories:, selected_category_ids:)
          end

          div(class: "w-1/3") do
            render Views::Entities::Combobox.new(name: "subscription[entity_id][]", entities:, selected_entity_ids:)
          end

          div(class: "w-1/3") do
            render Views::Subscriptions::StatusesCombobox.new(name: "subscription[status][]", selected_statuses:)
          end
        end
      end

      button(type: :submit, class: "hidden")
    end
  end

  private

  def selected_category_ids
    Array(category_id).map(&:to_s)
  end

  def selected_entity_ids
    Array(entity_id).map(&:to_s)
  end

  def selected_statuses
    Array(status).map(&:to_s)
  end
end
