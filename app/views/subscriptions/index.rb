# frozen_string_literal: true

class Views::Subscriptions::Index < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::TextFieldTag

  include TranslateHelper

  attr_reader :subscriptions, :mobile

  def initialize(subscriptions:, mobile: false)
    @subscriptions = subscriptions
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "bg-white p-4 shadow-md rounded-lg") do
        div(class: "flex justify-between mb-6") do
          link_to(
            action_model(:newa, Subscription),
            new_subscription_path,
            class: "py-2 px-3 rounded-sm border border-sky-900 bg-blue-600 hover:bg-blue-800 transition-colors text-white shadow-lg font-thin",
            data: { turbo_frame: :_top }
          )
        end

        div(data: { controller: "datatable" }) do
          text_field_tag(
            :search,
            nil,
            type: :text,
            placeholder: "#{action_message(:search)}...",
            class: "w-full border border-slate-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent",
            data: { action: "input->datatable#filter" }
          )

          div(class: "mt-4 space-y-3", data: { datatable_target: "table" }) do
            if subscriptions.present?
              subscriptions.each do |subscription|
                render Views::Subscriptions::Subscription.new(subscription:, mobile:)
              end
            else
              div(class: "border border-slate-200 rounded-lg p-4 text-center text-slate-600") { I18n.t(:rows_not_found) }
            end
          end
        end
      end
    end
  end
end
