# frozen_string_literal: true

class Views::Subscriptions::Subscription < Views::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::DOMID

  include CacheHelper
  include ColoursHelper
  include TranslateHelper

  attr_reader :subscription, :mobile

  def initialize(subscription:, mobile: false)
    @subscription = subscription
    @mobile = mobile
  end

  def view_template
    turbo_frame_tag dom_id(subscription) do
      mobile ? mobile_card : desktop_row
    end
  end

  private

  def desktop_row
    div(
      class: "grid grid-cols-12 gap-2 border-b border-slate-200 bg-gray-100 hover:bg-white",
      data: { id: subscription.id, datatable_target: :row }
    ) do
      div(class: "col-span-3 px-3 py-3") do
        p(class: "font-lekton text-base font-semibold text-slate-900") { subscription.description }
        p(class: "truncate text-sm text-slate-500") { subscription.comment.presence }
      end

      div(class: "col-span-1 flex items-center justify-center px-2 py-3 text-sm font-semibold text-slate-700") do
        status_badge
      end

      div(class: "col-span-2 flex items-center justify-center px-2 py-3 text-center text-sm text-slate-700") do
        subscription.categories.map(&:name).join(", ").presence || "-"
      end

      div(class: "col-span-2 flex items-center justify-center px-2 py-3 text-center text-sm text-slate-700") do
        subscription.entities.map(&:entity_name).join(", ").presence || "-"
      end

      div(class: "col-span-2 flex items-center justify-center px-2 py-3 font-anonymous text-md font-semibold text-slate-800") do
        subscription.transactions_count
      end

      div(class: "col-span-1 flex items-center justify-center px-2 py-3") do
        span(class: "font-lekton text-lg font-semibold text-slate-900 whitespace-nowrap") do
          from_cent_based_to_float(subscription.price, "R$")
        end
      end

      div(class: "col-span-1 flex items-center justify-center px-2 py-3") do
        link_to(
          edit_subscription_path(subscription),
          id: "edit_subscription_#{subscription.id}",
          class: "mx-1 rounded-4xl bg-sky-200 text-blue-600 hover:text-blue-800",
          data: { turbo_frame: :_top }
        ) { cached_icon(:pencil) }
      end
    end
  end

  def mobile_card
    div(class: "relative my-4 overflow-hidden rounded-lg border border-slate-200 bg-white shadow-sm", data: { id: subscription.id, datatable_target: :row }) do
      div(class: "absolute right-3 top-3 z-10") do
        status_badge
      end

      div(class: "border-b border-slate-200 bg-sky-50/70 px-4 py-5 text-center") do
        link_to(
          subscription.description,
          edit_subscription_path(subscription),
          id: "edit_subscription_#{subscription.id}",
          class: "block text-lg font-semibold text-slate-900 underline underline-offset-[3px]",
          data: { turbo_frame: :_top }
        )

        p(class: "mt-2 text-sm text-slate-500") { subscription.comment } if subscription.comment.present?
      end

      div(class: "space-y-4 p-4") do
        div(class: "grid grid-cols-2 gap-3") do
          mobile_metric(icon: :number, label: model_attribute(Subscription, :transactions_count), value: subscription.transactions_count)
          mobile_metric(icon: :money, label: model_attribute(Subscription, :price), value: from_cent_based_to_float(subscription.price, "R$"))
        end

        if subscription.categories.any? || subscription.entities.any?
          div(class: "grid grid-cols-2 gap-3") do
            render_mobile_categories if subscription.categories.any?
            render_mobile_entities if subscription.entities.any?
          end
        end
      end
    end
  end

  def mobile_metric(icon:, label:, value:)
    mobile_metric_card(icon:, label:) do
      div(class: "mt-1 text-sm font-semibold text-slate-800") do
        value
      end
    end
  end

  def mobile_metric_card(icon:, label:)
    div(class: "rounded-lg border border-slate-200 bg-slate-50 px-3 py-2") do
      div(class: "flex items-center gap-2 text-sm font-medium text-slate-500") do
        cached_icon(icon)
        span { label }
      end

      yield
    end
  end

  def render_mobile_categories
    mobile_metric_card(icon: :category, label: model_attribute(Subscription, :category_id)) do
      render Views::Categories::Popover.new(
        items: subscription_category_popover_items,
        mobile: true,
        target_ids: subscription.categories.map(&:id),
        trigger_label: pluralise_model(Category, subscription.categories.count).upcase,
        variant: :subscription
      )
    end
  end

  def render_mobile_entities
    mobile_metric_card(icon: :user, label: model_attribute(Subscription, :entity_id)) do
      render Views::Entities::Popover.new(
        items: subscription_entity_popover_items,
        mobile: true,
        target_ids: subscription.entities.map(&:id),
        trigger_label: pluralise_model(Entity, subscription.entities.count).upcase,
        variant: :subscription
      )
    end
  end

  def subscription_category_popover_items
    subscription.categories.map do |category|
      {
        name: category.name,
        style: "background: #{category.hex_colour}; #{auto_text_color(category.hex_colour)}"
      }
    end
  end

  def subscription_entity_popover_items
    subscription.entities.map do |entity|
      {
        name: entity.entity_name,
        avatar_name: entity.avatar_name
      }
    end
  end

  def status_badge
    colour = case subscription.status
             when "active" then "bg-emerald-100 text-emerald-800"
             when "paused" then "bg-amber-100 text-amber-800"
             else "bg-slate-200 text-slate-700"
             end

    span(class: "rounded-full px-2.5 py-1 text-xs font-semibold uppercase tracking-wide #{colour}") do
      subscription.status.humanize
    end
  end
end
