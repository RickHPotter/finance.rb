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
    div(class: "flex min-h-[calc(100svh-22rem)] flex-col rounded-lg bg-white p-4 shadow-md") do
      div(class: "flex justify-between mb-6") do
        link_to(
          action_model(:newa, Subscription),
          new_subscription_path,
          class: "py-2 px-3 rounded-sm border border-sky-900 bg-blue-600 hover:bg-blue-800 transition-colors text-white shadow-lg font-thin",
          data: { turbo_frame: :_top }
        )
      end

      div(class: "min-w-full flex-1") do
        turbo_frame_tag :subscriptions do
          div(class: "min-h-full", data: { controller: "datatable" }) do
            render Views::Subscriptions::IndexSearchForm.new(index_context:, mobile: false)

            div(class: "my-4", data: { datatable_target: :table }) do
              div(class: "overflow-hidden rounded-lg border-1 border-slate-300 shadow-sm") do
                div(class: "grid grid-cols-12 gap-2 border-b border-slate-400 bg-slate-300 py-1 font-graduate font-semibold text-black") do
                  div(class: "col-span-3 px-3 text-center") { model_attribute(Subscription, :description) }
                  div(class: "col-span-1 px-2 text-center") { model_attribute(Subscription, :status) }
                  div(class: "col-span-2 px-2 text-center") { model_attribute(Subscription, :category_id) }
                  div(class: "col-span-2 px-2 text-center") { model_attribute(Subscription, :entity_id) }
                  div(class: "col-span-2 px-2 text-center") { model_attribute(Subscription, :transactions_count) }
                  div(class: "col-span-1 px-2 text-center") { model_attribute(Subscription, :price) }
                  div(class: "col-span-1 px-2 text-center") { I18n.t(:datatable_actions) }
                end

                if subscriptions.present?
                  subscriptions.each do |subscription|
                    render Views::Subscriptions::Subscription.new(subscription:, mobile: false)
                  end
                else
                  div(class: "border-b border-slate-200 bg-white py-2 my-2 text-lg") { I18n.t(:rows_not_found) }
                end
              end
            end
          end
        end
      end
    end
  end

  def mobile_index
    div(class: "flex min-h-[calc(100svh-22rem)] flex-col rounded-lg bg-white p-4 shadow-md w-full") do
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
            data: { turbo_frame: :_top }
          ) { cached_icon(:bigger_plus) }
        end
      end
    end
  end
end
