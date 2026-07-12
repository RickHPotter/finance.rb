# frozen_string_literal: true

class Views::Subscriptions::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::TextFieldTag

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
          div(class: "min-h-full", data: { controller: "datatable" }) do
            render Views::Subscriptions::IndexSearchForm.new(index_context:, mobile: false)

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
                    render Views::Subscriptions::Subscription.new(subscription:, mobile: false)
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
          div(class: "min-h-full", data: { controller: "datatable" }) do
            div(class: resource_mobile_filter_shell_class) do
              render Views::Subscriptions::IndexSearchForm.new(index_context:, mobile: true)
            end

            div(class: "mb-8", data: { datatable_target: :table }) do
              if subscriptions.present?
                subscriptions.each do |subscription|
                  render Views::Subscriptions::Subscription.new(subscription:, mobile: true)
                end
              else
                div(class: resource_empty_row_class) { I18n.t(:rows_not_found) }
              end
            end
          end

          link_to(
            new_subscription_path,
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
        new_subscription_path,
        class: index_new_button_class,
        data: { turbo_frame: "_top" }
      )
    end
  end
end
