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
    div(class: "flex min-h-[calc(100svh-18rem)] flex-col rounded-lg bg-white p-4 shadow-md") do
      render_hero

      div(class: "min-w-full flex-1") do
        turbo_frame_tag :subscriptions do
          div(class: "min-h-full", data: { controller: "datatable" }) do
            render Views::Subscriptions::IndexSearchForm.new(index_context:, mobile: false)

            div(class: "my-4", data: { datatable_target: :table }) do
              div(class: "overflow-hidden rounded-lg border border-slate-300 shadow-sm") do
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
                  div(class: "py-2 text-lg") { I18n.t(:rows_not_found) }
                end
              end
            end
          end
        end
      end
    end
  end

  def mobile_index
    div(class: "flex min-h-[calc(100svh-18rem)] flex-col rounded-lg bg-white p-4 shadow-md w-full") do
      render_hero

      div(class: "min-w-full flex-1") do
        turbo_frame_tag :subscriptions do
          div(class: "min-h-full", data: { controller: "datatable" }) do
            div(class: "mb-6 grid grid-cols-1 gap-2 rounded-lg bg-slate-50 p-3 shadow-sm") do
              render Views::Subscriptions::IndexSearchForm.new(index_context:, mobile: true)
            end

            div(class: "mb-8", data: { datatable_target: :table }) do
              if subscriptions.present?
                subscriptions.each do |subscription|
                  render Views::Subscriptions::Subscription.new(subscription:, mobile: true)
                end
              else
                div(class: "border-b border-slate-200 py-2 my-2 text-lg bg-white") { I18n.t(:rows_not_found) }
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
    div(class: "mb-6 flex items-start justify-between border-b border-stone-200 pb-3") do
      h1(class: "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700") { action_model(:index, Subscription, 2) }
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
