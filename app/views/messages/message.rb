# frozen_string_literal: true

class Views::Messages::Message < Views::Base
  register_value_helper :current_user
  attr_reader :message

  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  def initialize(message:)
    @message = message
  end

  def view_template
    div(class: "m-2") do
      turbo_frame_tag dom_id(message) do
        div(
          class: "whitespace-pre-wrap break-words text-start",
          data: { user_id: presented_user_id, presenter_role: presenter_role, presenter_side: presenter_side, controller: :chat, chat_target: :message }
        ) do
          div(class: "flex", data: { chat_target: :messageAlignment }) do
            if assistant_presented_notification?
              div(class: "#{assistant_avatar_wrapper_class} shrink-0 self-end") do
                image_tag(asset_path("avatars/people/21.png"), class: "size-9 rounded-full bg-white object-cover ring-2 ring-amber-200")
              end
            end

            div(
              class: "max-w-xs md:max-w-lg px-4 py-2 rounded-2xl shadow-sm text-sm #{'ring-1 ring-red-800' if message.headers}",
              data: { chat_target: :messageColour }
            ) do
              if assistant_presented_notification?
                p(class: "mb-1 text-[10px] font-semibold uppercase tracking-[0.18em] opacity-75") { assistant_presenter_name }
                p(class: "mb-2 text-[10px] font-medium opacity-70") { actor_subtitle }
              end

              pre(class: "whitespace-pre-wrap") { message.rendered_body.html_safe }

              render_message_actions

              span(class: "block text-[8px] mt-1 opacity-70 text-end", data: { chat_target: :messageTime, timestamp: message.created_at.iso8601 })
            end
          end
        end
      end
    end
  end

  private

  def render_message_actions
    return if my_assistant_notification?

    if message.superseded_by_id
      link_to(
        model_attribute(message, :outdated_message),
        "##{dom_id(message.superseded_by)}",
        class: "mt-3 flex flex-col items-center text-center text-black bg-gray-400 hover:bg-gray-600 p-3 rounded-xs font-medium shadow"
      )
    else
      render_transaction_actions
    end
  end

  def render_transaction_actions
    user = current_user if request.env["warden"].present?

    if message.transaction_destroy_notification_message?
      return if message.reference_transactable_id.nil?

      cash_transaction_to_be_destroyed = user&.cash_transactions&.find_by(id: message.reference_transactable_id)

      if cash_transaction_to_be_destroyed
        render_destroy_action(cash_transaction_to_be_destroyed)
      else
        span(class: "mt-3 flex flex-col items-center text-center text-black bg-gray-400 p-3 rounded-xs font-medium shadow select-none") do
          model_attribute(message, :already_deleted)
        end
      end

      return
    end

    params = message.replay_payload
    return if params.blank?

    id = params["id"]
    type = params["type"]

    reference_transactable = user&.cash_transactions&.find_by(reference_transactable_type: type, reference_transactable_id: id)
    action_button_key = message.action_button_key(local_reference_exists: reference_transactable.present?)

    if reference_transactable
      render_edit_action(reference_transactable, params, action_button_key)
    elsif type&.constantize&.find_by(id:)
      render_create_action(params, action_button_key)
    else
      span(class: "mt-3 flex flex-col items-center text-center text-black bg-gray-400 p-3 rounded-xs font-medium shadow select-none") do
        model_attribute(message, :already_deleted)
      end
    end
  end

  def render_edit_action(reference_transactable, params, action_button_key)
    cash_transaction = {
      description: params["description"],
      price: params["price"],
      date: params["date"],
      month: params["month"],
      year: params["year"],
      category_id: params["category_ids"],
      entity_id: params["entity_ids"],
      friend_notification_intent: params["intent"],
      reference_transactable_type: params["type"],
      reference_transactable_id: params["id"],
      source_message_id: message.id,
      cash_installments_attributes: params["cash_installments_attributes"],
      entity_transactions_attributes: params["entity_transactions_attributes"]
    }

    Link(
      href: edit_cash_transaction_path(id: reference_transactable, cash_transaction: cash_transaction, format: :turbo_stream),
      size: :xs,
      class: action_button_class(action_button_key),
      data: { turbo_frame: "_top", turbo_prefetch: "false", chat_target: :messageAction }
    ) do
      span(class: "truncate block max-w-full leading-tight") { model_attribute(message, action_button_key) }
    end
  end

  def render_create_action(params, action_button_key)
    cash_transaction = {
      description: params["description"],
      price: params["price"],
      date: params["date"],
      month: params["month"],
      year: params["year"],
      category_id: params["category_ids"],
      entity_id: params["entity_ids"],
      friend_notification_intent: params["intent"],
      reference_transactable_type: params["type"],
      reference_transactable_id: params["id"],
      source_message_id: message.id,
      cash_installments_attributes: params["cash_installments_attributes"],
      entity_transactions_attributes: params["entity_transactions_attributes"]
    }

    Link(
      href: new_cash_transaction_path(cash_transaction:, format: :turbo_stream),
      size: :xs,
      class: action_button_class(action_button_key),
      data: { turbo_frame: "_top", turbo_prefetch: "false", chat_target: :messageAction }
    ) do
      span(class: "truncate block max-w-full leading-tight") { model_attribute(message, action_button_key) }
    end
  end

  def render_destroy_action(reference_transactable)
    Link(
      href: cash_transaction_path(id: reference_transactable, format: :turbo_stream, message_id: message.id),
      size: :xs,
      class: "mt-3 flex flex-col items-center text-center text-black bg-red-500 hover:bg-red-600 p-3 rounded-xs font-medium shadow",
      data: {
        turbo_method: :delete,
        turbo_confirm: "Are you sure you want to destroy this transaction: #{reference_transactable.description}?",
        turbo_frame: "_top",
        turbo_prefetch: "false",
        chat_target: :messageAction
      }
    ) do
      span(class: "truncate block max-w-full leading-tight") { model_attribute(message, :destroy) }
    end
  end

  def action_button_class(action_button_key)
    base_class = "mt-3 flex flex-col items-center text-center p-3 rounded-xs font-medium shadow transition-colors"

    case action_button_key.to_sym
    when :create
      "#{base_class} text-white bg-emerald-600 hover:bg-emerald-700"
    when :correct
      "#{base_class} text-black bg-amber-400 hover:bg-amber-500"
    when :edit
      "#{base_class} text-black bg-sky-400 hover:bg-sky-500"
    when :destroy
      "#{base_class} text-white bg-red-500 hover:bg-red-600"
    else
      "#{base_class} text-black bg-stone-300 hover:bg-stone-400"
    end
  end

  def assistant_presented_notification?
    message.conversation.assistant? && !message.human_message?
  end

  def my_assistant_notification?
    assistant_presented_notification? && viewer&.id == message.user_id
  end

  def presented_user_id
    return nil if assistant_presented_notification?

    message.user_id
  end

  def presenter_role
    assistant_presented_notification? ? "assistant" : "user"
  end

  def presenter_side
    return "self" if my_assistant_notification?
    return "other" if assistant_presented_notification?

    nil
  end

  def assistant_presenter_name
    if my_assistant_notification?
      I18n.t("activerecord.attributes.conversation.your_assistant")
    else
      I18n.t("activerecord.attributes.conversation.assistant_of", name: message.user.first_name)
    end
  end

  def actor_subtitle
    I18n.t("activerecord.attributes.message.assistant_actor", name: message.user.first_name)
  end

  def assistant_avatar_wrapper_class
    my_assistant_notification? ? "ml-3 order-last" : "mr-3"
  end

  def viewer
    return @viewer if defined?(@viewer)

    @viewer = request.env["warden"].present? ? current_user : nil
  end
end
