# frozen_string_literal: true

class Views::Subscriptions::Subscription < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper

  attr_reader :subscription, :mobile

  def initialize(subscription:, mobile: false)
    @subscription = subscription
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag dom_id(subscription) do
      div(class: "border border-slate-200 rounded-lg p-4 bg-slate-50") do
        if mobile
          mobile_card
        else
          desktop_card
        end
      end
    end
  end

  private

  def desktop_card
    div(class: "grid grid-cols-12 gap-3 items-center") do
      div(class: "col-span-4") do
        p(class: "font-semibold text-slate-900") { subscription.description }
        p(class: "text-sm text-slate-500") { subscription.comment.presence || "-" }
      end

      div(class: "col-span-2 text-sm text-slate-700") { subscription.status.humanize }
      div(class: "col-span-2 text-sm text-slate-700") { subscription.categories.map(&:name).join(", ").presence || "-" }
      div(class: "col-span-2 text-sm text-slate-700") { subscription.entities.map(&:entity_name).join(", ").presence || "-" }

      div(class: "col-span-2 text-right") do
        p(class: "text-sm text-slate-500") { "#{subscription.transactions_count} tx" }
        p(class: "font-semibold text-slate-900") { subscription.price }
        link_to(action_model(:edit, subscription), edit_subscription_path(subscription), class: "text-sm text-blue-700", data: { turbo_frame: :_top })
      end
    end
  end

  def mobile_card
    div(class: "space-y-2") do
      p(class: "font-semibold text-slate-900") { subscription.description }
      p(class: "text-sm text-slate-500") { subscription.comment.presence || "-" }
      p(class: "text-sm text-slate-700") { subscription.status.humanize }
      p(class: "text-sm text-slate-700") { subscription.categories.map(&:name).join(", ").presence || "-" }
      p(class: "text-sm text-slate-700") { subscription.entities.map(&:entity_name).join(", ").presence || "-" }
      p(class: "text-sm text-slate-500") { "#{subscription.transactions_count} tx" }
      p(class: "font-semibold text-slate-900") { subscription.price }
      link_to(action_model(:edit, subscription), edit_subscription_path(subscription), class: "text-sm text-blue-700", data: { turbo_frame: :_top })
    end
  end
end
