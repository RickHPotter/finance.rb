# frozen_string_literal: true

class Views::Subscriptions::LifecycleActions < Views::Base
  attr_reader :subscription

  def initialize(subscription:)
    @subscription = subscription
  end

  def view_template
    case subscription.status
    when "active"
      lifecycle_action(:pause)
      confirmed_lifecycle_action(:finish)
    when "paused"
      lifecycle_action(:resume)
      confirmed_lifecycle_action(:finish)
    when "finished"
      confirmed_lifecycle_action(:reopen)
    end
  end

  private

  def lifecycle_action(event)
    Button(
      link: transition_path(event),
      variant: :outline,
      id: action_id(event),
      class: action_class(event),
      data: { turbo_method: :patch, turbo_frame: "_top", turbo_prefetch: false }
    ) { action_label(event) }
  end

  def confirmed_lifecycle_action(event)
    LinkWithConfirmation(
      id: action_id(event),
      text: action_label(event),
      link_params: {
        href: transition_path(event),
        id: action_id(event),
        variant: :outline,
        class: action_class(event),
        data: { turbo_method: :patch, turbo_frame: "_top", turbo_action: "replace" }
      }
    )
  end

  def transition_path(event)
    transition_subscription_path(subscription, event:, return_to: subscription_path(subscription))
  end

  def action_id(event) = "subscription_lifecycle_#{event}_#{subscription.id}"

  def action_label(event) = I18n.t("dashboards.subscriptions.lifecycle.actions.#{event}")

  def action_class(event)
    base = "border shadow-sm"
    if event.in?(%i[pause finish])
      return "#{base} border-amber-500 bg-amber-100 text-amber-900 hover:bg-amber-500 hover:text-white dark:bg-amber-950 dark:text-amber-200"
    end

    "#{base} border-emerald-500 bg-emerald-100 text-emerald-900 hover:bg-emerald-500 hover:text-white dark:bg-emerald-950 dark:text-emerald-200"
  end
end
