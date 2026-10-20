# frozen_string_literal: true

class Views::Subscriptions::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::TextFieldTag
  include Phlex::Rails::Helpers::FormWith

  include CacheHelper
  include TranslateHelper
  include ComponentsHelper

  attr_reader :subscriptions, :index_context, :mobile

  def initialize(subscriptions:, index_context: {}, mobile: false)
    @subscriptions = subscriptions
    @index_context = index_context
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      mobile ? mobile_index : desktop_index
    end
  end

  private

  def desktop_index
    div(class: resource_index_shell_class) do
      render_hero

      div(class: "min-w-full flex-1") do
        turbo_frame_tag :subscriptions do
          div(class: "min-h-full", data: { controller: "datatable subscription-bulk" }) do
            render Views::Subscriptions::IndexSearchForm.new(index_context:, mobile: false)
            bulk_action_bar

            div(class: "my-4", data: { datatable_target: :table }) do
              div(class: resource_table_shell_class) do
                render Views::Shared::TableHeader.new(
                  grid_class: "grid grid-cols-12",
                  rows: [
                    [
                      { class: "col-span-3 flex justify-center", label: model_attribute(Subscription, :description) },
                      { class: "flex justify-center", label: model_attribute(Subscription, :status) },
                      { class: "col-span-2 flex justify-center", label: model_attribute(Subscription, :category_id) },
                      { class: "col-span-2 flex justify-center", label: model_attribute(Subscription, :entity_id) },
                      { class: "col-span-2 flex justify-center", label: model_attribute(Subscription, :transactions_count) },
                      { class: "flex items-end justify-end", label: model_attribute(Subscription, :price), align: :right },
                      { class: "flex justify-center", label: I18n.t(:datatable_actions) }
                    ]
                  ]
                )

                if subscriptions.present?
                  subscriptions.each do |subscription|
                    render Views::Subscriptions::Subscription.new(subscription:, mobile: false, return_to: index_context[:return_to])
                  end
                else
                  div(class: resource_empty_row_class) { I18n.t(:rows_not_found) }
                end
              end
            end
          end
        end
      end
    end
  end

  def mobile_index
    div(class: "#{resource_index_shell_class} w-full") do
      render_hero

      div(class: "min-w-full flex-1") do
        turbo_frame_tag :subscriptions do
          div(class: "min-h-full", data: { controller: "datatable subscription-bulk" }) do
            div(class: resource_mobile_filter_shell_class) do
              render Views::Subscriptions::IndexSearchForm.new(index_context:, mobile: true)
            end
            bulk_action_bar

            div(class: "mb-8", data: { datatable_target: :table }) do
              if subscriptions.present?
                subscriptions.each do |subscription|
                  render Views::Subscriptions::Subscription.new(subscription:, mobile: true, return_to: index_context[:return_to])
                end
              else
                div(class: resource_empty_row_class) { I18n.t(:rows_not_found) }
              end
            end
          end

          link_to(
            new_subscription_path(return_to: index_context[:return_to]),
            style: "margin: 30px",
            class: "fixed bottom-0 right-0 bg-blue-600 text-white rounded-full shadow-lg flex items-center justify-center z-50 active:scale-95 transition-transform",
            data: { turbo_frame: "_top" }
          ) { cached_icon(:bigger_plus) }
        end
      end
    end
  end

  def render_hero
    div(class: resource_index_hero_class) do
      h1(class: resource_index_title_class) { action_model(:index, Subscription, 2) }
      next if mobile

      link_to(
        action_model(:newa, Subscription),
        new_subscription_path(return_to: index_context[:return_to]),
        class: index_new_button_class,
        data: { turbo_frame: "_top", turbo_action: "replace" }
      )
    end
  end

  def bulk_action_bar
    form_with(url: bulk_update_subscriptions_path, method: :patch, id: "subscription_bulk_form",
              class: "fixed inset-x-3 bottom-20 z-[60] hidden max-h-[70vh] flex-col gap-3 overflow-y-auto rounded-2xl border " \
                     "border-slate-300 bg-white/95 px-4 py-4 text-sm shadow-2xl backdrop-blur md:inset-x-auto md:bottom-6 " \
                     "md:left-1/2 md:max-w-[calc(100vw-3rem)] md:-translate-x-1/2 md:px-6 dark:border-slate-700 " \
                     "dark:bg-slate-900/95 dark:shadow-slate-950",
              data: { subscription_bulk_target: "bar" }) do |form|
      form.hidden_field :return_to, value: index_context[:bulk_return_to]
      div(class: "text-center text-base font-semibold text-slate-800 dark:text-slate-100") do
        span(data: { subscription_bulk_target: "count" }) { "0" }
        plain " "
        plain I18n.t("dashboards.subscriptions.bulk.selected")
      end

      div(class: "grid grid-cols-2 gap-2 sm:flex sm:flex-wrap sm:items-center sm:justify-center sm:gap-3") do
        select(name: "bulk_action", class: bulk_select_class,
               data: { action: "change->subscription-bulk#changeAction", subscription_bulk_target: "action" }) do
          bulk_actions.each { |label, value| option(value:) { label } }
        end

        select(name: "bulk_value", class: bulk_select_class,
               data: { subscription_bulk_target: "statusValue" }) do
          %w[pause resume finish reopen].each do |event|
            option(value: event) { I18n.t("dashboards.subscriptions.lifecycle.actions.#{event}") }
          end
        end

        select(name: "bulk_value", class: "#{bulk_select_class} hidden", disabled: true,
               data: { subscription_bulk_target: "categoryValue" }) do
          option(value: "") { model_attribute(Subscription, :category_id) }
          index_context[:current_user].categories.active.includes(:parent_category).order(:category_name).each do |category|
            option(value: category.id) { category.hierarchical_name }
          end
        end

        select(name: "bulk_value", class: "#{bulk_select_class} hidden", disabled: true,
               data: { subscription_bulk_target: "entityValue" }) do
          option(value: "") { model_attribute(Subscription, :entity_id) }
          index_context[:current_user].entities.active.order(:entity_name).each do |entity|
            option(value: entity.id) { entity.name }
          end
        end

        button(type: :submit, class: "rounded-md bg-blue-600 px-4 py-2 font-semibold text-white transition-colors " \
                                     "hover:bg-blue-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-blue-300") do
          I18n.t("dashboards.subscriptions.bulk.apply")
        end
        button(type: :button, class: "rounded-md border border-slate-300 bg-white px-4 py-2 font-semibold text-slate-700 " \
                                     "transition-colors hover:bg-slate-100 focus-visible:outline-none focus-visible:ring-2 " \
                                     "focus-visible:ring-blue-300 dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100 " \
                                     "dark:hover:bg-slate-700",
               data: { action: "subscription-bulk#clear" }) { I18n.t("dashboards.subscriptions.bulk.clear_selection") }
      end
    end
  end

  def bulk_actions
    %w[status replace_category clear_category replace_entity clear_entity].map do |action|
      [ I18n.t("dashboards.subscriptions.bulk.actions.#{action}"), action ]
    end
  end

  def bulk_select_class
    "col-span-2 min-w-0 rounded-md border border-slate-300 bg-white px-3 py-2 text-slate-900 sm:min-w-36 " \
      "dark:border-slate-600 dark:bg-slate-800 dark:text-slate-100"
  end
end
