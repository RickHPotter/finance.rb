# frozen_string_literal: true

class Views::V1::Messages::Message < Views::Base
  register_value_helper :current_user
  attr_reader :message

  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  include TranslateHelper

  def initialize(message:)
    @message = message
  end

  def view_template
    div(class: "m-2") do
      turbo_frame_tag dom_id(message) do
        div(
          class: "whitespace-pre-wrap break-words text-start",
          data: { user_id: message.user_id, controller: :chat, chat_target: :message }
        ) do
          div(class: "flex", data: { chat_target: :messageAlignment }) do
            div(
              class: "max-w-xs md:max-w-lg px-4 py-2 rounded-2xl shadow-sm text-sm #{'ring-1 ring-red-800' if message.headers}",
              data: { chat_target: :messageColour }
            ) do
              pre(class: "whitespace-pre-wrap") { message.body.html_safe }

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

    if message.headers.blank? # action is :destroy
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

    params = JSON.parse(message.headers)

    id = params["id"]
    type = params["type"]

    reference_transactable = user&.cash_transactions&.find_by(reference_transactable_type: type, reference_transactable_id: id)

    if reference_transactable
      render_edit_action(reference_transactable, params)
    elsif type&.constantize&.find_by(id:)
      render_create_action(params)
    else
      span(class: "mt-3 flex flex-col items-center text-center text-black bg-gray-400 p-3 rounded-xs font-medium shadow select-none") do
        model_attribute(message, :already_deleted)
      end
    end
  end

  def render_edit_action(reference_transactable, params)
    cash_transaction = {
      description: params["description"],
      price: params["price"],
      date: params["date"],
      month: params["month"],
      year: params["year"],
      category_id: params["category_ids"],
      entity_id: params["entity_ids"],
      reference_transactable_type: params["type"],
      reference_transactable_id: params["id"],
      cash_installments_attributes: params["cash_installments_attributes"],
      entity_transactions_attributes: params["entity_transactions_attributes"]
    }

    Link(
      href: edit_v1_cash_transaction_path(id: reference_transactable, cash_transaction: cash_transaction, format: :turbo_stream),
      size: :xs,
      class: "mt-3 flex flex-col items-center text-center text-black bg-lime-400 hover:bg-lime-600 p-3 rounded-xs font-medium shadow",
      data: { turbo_frame: "center_container", turbo_prefetch: "false", chat_target: :messageAction }
    ) do
      span(class: "truncate block max-w-full leading-tight") { action_model(:edit, CashTransaction) }
    end
  end

  def render_create_action(params)
    cash_transaction = {
      description: params["description"],
      price: params["price"],
      date: params["date"],
      month: params["month"],
      year: params["year"],
      category_id: params["category_ids"],
      entity_id: params["entity_ids"],
      reference_transactable_type: params["type"],
      reference_transactable_id: params["id"],
      cash_installments_attributes: params["cash_installments_attributes"],
      entity_transactions_attributes: params["entity_transactions_attributes"]
    }

    Link(
      href: new_v1_cash_transaction_path(cash_transaction:, format: :turbo_stream),
      size: :xs,
      class: "mt-3 flex flex-col items-center text-center text-black bg-orange-400 hover:bg-orange-600 p-3 rounded-xs font-medium shadow",
      data: { turbo_frame: "center_container", turbo_prefetch: "false", chat_target: :messageAction }
    ) do
      span(class: "truncate block max-w-full leading-tight") { action_model(:create, CashTransaction) }
    end
  end

  def render_destroy_action(reference_transactable)
    Link(
      href: v1_cash_transaction_path(id: reference_transactable, format: :turbo_stream),
      size: :xs,
      class: "mt-3 flex flex-col items-center text-center text-black bg-red-500 hover:bg-red-600 p-3 rounded-xs font-medium shadow",
      data: {
        turbo_method: :delete,
        turbo_confirm: "Are you sure you want to destroy this transaction: #{reference_transactable.description}?",
        turbo_frame: "center_container",
        turbo_prefetch: "false",
        chat_target: :messageAction
      }
    ) do
      span(class: "truncate block max-w-full leading-tight") { action_model(:destroy, CashTransaction) }
    end
  end
end
