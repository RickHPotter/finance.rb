# frozen_string_literal: true

class Views::Shared::AddToSubscriptionModal < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::HiddenFieldTag
  include Phlex::Rails::Helpers::SelectTag
  include Phlex::Rails::Helpers::OptionsForSelect

  include TranslateHelper
  include ComponentsHelper

  attr_reader :modal_id, :url, :index_context, :subscriptions

  def initialize(modal_id:, url:, index_context:, subscriptions:)
    @modal_id = modal_id
    @url = url
    @index_context = index_context
    @subscriptions = subscriptions
  end

  def view_template
    ModalShell(id: modal_id, title: action_message(:add_to_subscription)) do
      form_with(url:, method: :post) do |form|
        hidden_field_tag :ids, "", data: { bulk_ids_input: true, bulk_ids_kind: "record" }
        hidden_field_tag :index_context_json, index_context.except(:available_subscriptions).to_json

        div(class: "mx-auto pb-4 text-center") do
          label(for: :subscription_id, class: "font-poetsen-one text-medium font-bold text-gray-500 dark:text-slate-400") do
            I18n.t("bulk_actions.choose_subscription")
          end

          div(class: "relative w-full") do
            select_tag(:subscription_id, class: input_class_without_icon) do
              options_for_select(subscription_options)
            end
          end
        end

        div(class: "grid grid-cols-2 gap-4 justify-between text-md") do
          form.submit I18n.t("confirmation.confirm"),
                      class: modal_confirm_button_class(:purple),
                      data: { modal_hide: modal_id }

          button(
            class: modal_cancel_button_class,
            type: :button,
            data: { modal_hide: modal_id }
          ) do
            I18n.t("confirmation.cancel")
          end
        end
      end
    end
  end

  private

  def subscription_options
    subscriptions.map { |subscription| [ subscription.description, subscription.id ] }
  end
end
