# frozen_string_literal: true

class Views::Messages::Message < Views::Base # rubocop:disable Metrics/ClassLength
  attr_reader :message

  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::DOMID
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::LinkTo

  include ComponentsHelper
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
                p(class: "mb-1 text-[9px] font-semibold uppercase tracking-[0.18em] opacity-75") { assistant_presenter_name }
                p(class: "mb-3 text-[8px] font-medium opacity-60") { "#{actor_subtitle} - #{Message.model_name} #{message.id}" }
              end

              pre(class: "whitespace-pre-wrap") { message.rendered_body.html_safe }
              render_assistant_instruction
              render_completed_state
              render_my_assistant_show_action

              render_message_actions

              span(class: "block text-[8px] mt-1 opacity-70 text-end", data: { chat_target: :messageTime, timestamp: message.created_at.iso8601 })
            end
          end
        end
      end
    end

    render_my_assistant_transaction_modal
  end

  private

  def render_message_actions
    if message.superseded_by_id
      render_outdated_state
    else
      return if message.paid_state_sync_message? && my_assistant_notification?
      return if my_assistant_notification? || message.applied?

      render_transaction_actions
    end
  end

  def render_transaction_actions
    return unless current_context.present?

    if message.paid_state_sync_message?
      render_acknowledge_action
      return
    end

    if message.transaction_destroy_notification_message?
      cash_transaction_to_be_destroyed = message.local_reference_for(context: current_context)

      if cash_transaction_to_be_destroyed
        render_destroy_action(cash_transaction_to_be_destroyed)
      else
        span(class: status_badge_class) do
          model_attribute(message, :already_deleted)
        end
      end

      return
    end

    params = message.replay_payload
    return if params.blank?

    reference_transactable = message.local_reference_for(context: current_context)
    action_button_key = message.action_button_key(local_reference_exists: reference_transactable.present?)

    if reference_transactable
      render_edit_action(reference_transactable, action_button_key)
    elsif params["type"]&.constantize&.find_by(id: params["id"])
      render_create_action(action_button_key)
    else
      span(class: status_badge_class) do
        model_attribute(message, :already_deleted)
      end
    end
  end

  def render_assistant_instruction
    return unless assistant_presented_notification?
    return if message.superseded_by_id.present? || message.applied?
    return unless %w[create update].include?(message.send(:notification_action))

    instruction_key = my_assistant_notification? ? :click_down_below_mine : :click_down_below_theirs

    p(class: "mt-3 text-[11px] font-medium text-sky-700 underline decoration-sky-500 underline-offset-2") do
      model_attribute(message, instruction_key)
    end
  end

  def render_completed_state
    return unless message.applied?
    return if message.superseded_by_id.present?

    p(class: status_badge_class) do
      model_attribute(message, message.completed_message_key)
    end

    return if message.transaction_destroy_notification_message?
    return unless reference_transactable_for_viewer.present?

    render_edit_action(reference_transactable_for_viewer, :edit)
  end

  def render_my_assistant_show_action
    return unless my_assistant_notification?
    return unless showable_my_transaction.present?

    if showable_transaction_destroyed?
      p(class: status_badge_class) do
        model_attribute(message, :already_destroyed)
      end
    end

    Button(
      type: :button,
      size: :xs,
      class: "mt-3 w-full text-black bg-white/70 hover:bg-white border border-black/20",
      data: { modal_target: my_transaction_modal_id, modal_toggle: my_transaction_modal_id }
    ) do
      span(class: "truncate block max-w-full leading-tight") { I18n.t("actions.show") }
    end
  end

  def render_my_assistant_transaction_modal
    return unless my_assistant_notification?
    return unless showable_my_transaction.present?

    transaction = showable_my_transaction

    ModalShell(
      id: my_transaction_modal_id,
      title: transaction.description,
      options: {
        wrapper_class: "px-3 py-6",
        content_class: "w-[calc(100vw-1.5rem)] max-w-5xl max-h-[calc(100svh-3rem)] overflow-hidden"
      }
    ) do
      div(class: "space-y-4 text-sm text-black min-w-[18rem] md:min-w-[44rem] lg:min-w-[56rem]") do
        div(class: "border-b border-stone-200 pb-3") do
          div(class: "flex items-start justify-between gap-3") do
            div(class: "space-y-2") do
              if showable_transaction_destroyed?
                p(class: status_badge_class) do
                  model_attribute(message, :already_destroyed)
                end
              end

              p(class: "text-stone-500 leading-relaxed") { transaction.comment } if transaction.comment.present?
            end

            if showable_transaction_link.present?
              Link(
                href: showable_transaction_link,
                size: :sm,
                class: "shrink-0 min-w-40 justify-center text-black bg-white hover:bg-stone-50 border border-black/20 px-4 py-2 font-medium shadow-sm",
                data: { turbo_frame: "_top", turbo_prefetch: "false", modal_hide: my_transaction_modal_id }
              ) do
                span(class: "truncate block max-w-full leading-tight") { I18n.t("actions.edit") }
              end
            end
          end
        end

        div(class: "grid grid-cols-1 gap-2 md:h-[21rem] md:grid-cols-2 md:items-stretch") do
          div(class: "flex h-full flex-col overflow-hidden rounded-xl border border-stone-200 bg-stone-50 p-2") do
            p(class: "text-xs font-semibold uppercase tracking-[0.18em] text-stone-500 mb-3") do
              "#{I18n.t('gerund.show')} #{transaction.model_name.human}"
            end

            div(class: "flex-1 overflow-y-auto space-y-1 pr-1") do
              render_showable_transaction_details(transaction)
            end
          end

          div(class: "flex max-h-72 flex-col overflow-hidden rounded-xl border border-stone-200 bg-stone-50 p-2 md:h-full md:max-h-none") do
            p(class: "text-xs font-semibold uppercase tracking-[0.18em] text-stone-500 mb-3") do
              showable_installment_label(transaction)
            end

            div(class: "flex-1 overflow-y-auto space-y-1 pr-1") do
              showable_installments(transaction).order(:number).each do |installment|
                div(class: "rounded-md bg-stone-100 shadow-xs border border-stone-200 px-3 py-1") do
                  div(class: "flex items-start justify-between gap-2") do
                    div(class: "min-w-0") do
                      p(class: "text-xs font-semibold uppercase tracking-[0.18em] text-stone-500") { "##{installment.number}" }
                      p(class: "mt-1 text-sm leading-relaxed") { I18n.l(installment.date.to_date, format: :long) }
                    end

                    p(class: "shrink-0 text-sm font-semibold text-end") { from_cent_based_to_float(installment.price, "R$") }
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def render_edit_action(reference_transactable, action_button_key)
    Link(
      href: edit_cash_transaction_path(id: reference_transactable, cash_transaction: { source_message_id: message.id }, format: :turbo_stream),
      size: :xs,
      class: action_button_class(action_button_key),
      data: { turbo_frame: "_top", turbo_prefetch: "false", chat_target: :messageAction }
    ) do
      span(class: "truncate block max-w-full leading-tight") { model_attribute(message, action_button_key) }
    end
  end

  def render_create_action(action_button_key)
    Link(
      href: new_cash_transaction_path(cash_transaction: { source_message_id: message.id }, format: :turbo_stream),
      size: :xs,
      class: action_button_class(action_button_key),
      data: { turbo_frame: "_top", turbo_prefetch: "false", chat_target: :messageAction }
    ) do
      span(class: "truncate block max-w-full leading-tight") { model_attribute(message, action_button_key) }
    end
  end

  def render_acknowledge_action
    Link(
      href: apply_conversation_message_path(
        message.conversation,
        message,
        format: :turbo_stream,
        message_filter: active_message_filter,
        message_side: active_message_sides
      ),
      size: :xs,
      class: action_button_class(:ok),
      data: {
        turbo_method: :patch,
        turbo_frame: "_top",
        turbo_prefetch: "false",
        chat_target: :messageAction
      }
    ) do
      span(class: "truncate block max-w-full leading-tight") { model_attribute(message, :ok) }
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

  def render_outdated_state
    link_to(
      model_attribute(message, :outdated_message),
      "##{dom_id(message.superseded_by)}",
      class: "#{status_badge_class} text-sky-700 underline decoration-sky-500 underline-offset-2 hover:bg-rose-400/40 hover:text-sky-800"
    )
  end

  def status_badge_class
    "mt-3 inline-flex items-center border-l-4 border-red-700 bg-rose-400/30 px-3 py-1 text-[10px] font-semibold uppercase"
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

  def reference_transactable_for_viewer
    return @reference_transactable_for_viewer if defined?(@reference_transactable_for_viewer)
    return @reference_transactable_for_viewer = nil if current_context.blank?

    payload = message.replay_payload || {}
    type = payload["type"]
    id = payload["id"]

    return unless message.transaction_destroy_notification_message? || (type.present? && id.present?)

    @reference_transactable_for_viewer = message.local_reference_for(context: current_context)
  end

  def showable_my_transaction
    return @showable_my_transaction if defined?(@showable_my_transaction)

    return unless message.reference_transactable.is_a?(CashTransaction) || message.reference_transactable.is_a?(CardTransaction)

    @showable_my_transaction = message.reference_transactable
  end

  def my_transaction_modal_id
    "messageTransactionModal_#{message.id}"
  end

  def showable_transaction_destroyed?
    message.transaction_destroy_notification_message? && !message.paid_state_sync_message?
  end

  def showable_transaction_link
    transaction = showable_my_transaction
    return if transaction.blank? || transaction.destroyed?
    return if showable_transaction_destroyed?

    case transaction
    when CashTransaction
      edit_cash_transaction_path(transaction)
    when CardTransaction
      edit_card_transaction_path(transaction)
    end
  end

  def render_showable_transaction_details(transaction)
    case transaction
    when CashTransaction
      transaction_detail_row(model_attribute(CashTransaction, :date), I18n.l(transaction.date, format: :long))
      transaction_detail_row(model_attribute(CashTransaction, :user_bank_account_id), transaction.user_bank_account&.user_bank_account_name)
      transaction_detail_row(model_attribute(CashTransaction, :categories), transaction.categories.order(:category_name).pluck(:category_name).join(", "))
      transaction_detail_row(model_attribute(CashTransaction, :entities), transaction.entities.order(:entity_name).pluck(:entity_name).join(", "))
      transaction_detail_row(model_attribute(CashTransaction, :price), from_cent_based_to_float(transaction.price, "R$"))
    when CardTransaction
      transaction_detail_row(model_attribute(CardTransaction, :date), I18n.l(transaction.date, format: :long))
      transaction_detail_row(model_attribute(CardTransaction, :user_card_id), transaction.user_card&.user_card_name)
      transaction_detail_row(model_attribute(CardTransaction, :categories), transaction.categories.order(:category_name).pluck(:category_name).join(", "))
      transaction_detail_row(model_attribute(CardTransaction, :entities), transaction.entities.order(:entity_name).pluck(:entity_name).join(", "))
      transaction_detail_row(model_attribute(CardTransaction, :price), from_cent_based_to_float(transaction.price, "R$"))
    end
  end

  def showable_installments(transaction)
    case transaction
    when CashTransaction
      transaction.cash_installments
    when CardTransaction
      transaction.card_installments
    else
      Installment.none
    end
  end

  def showable_installment_label(transaction)
    case transaction
    when CashTransaction
      model_attribute(CashInstallment, :self)
    when CardTransaction
      model_attribute(CardInstallment, :self)
    else
      model_attribute(Installment, :self)
    end
  end

  def transaction_detail_row(label, value)
    return if value.blank?

    div(class: "rounded-md bg-stone-100 shadow-xs border border-stone-200 px-3 py-1") do
      p(class: "text-xs font-semibold uppercase tracking-[0.18em] text-stone-500") { label }
      p(class: "mt-1 text-sm leading-relaxed") { value }
    end
  end

  def viewer
    return @viewer if defined?(@viewer)

    @viewer = request.env["warden"].present? ? rails_view_context.current_user : nil
  end

  def active_message_filter
    request.params[:message_filter].presence_in(%w[pending all]) || "pending"
  end

  def active_message_sides
    requested_sides = Array(request.params[:message_side]).presence || %w[mine theirs]
    requested_sides & %w[mine theirs]
  end

  def viewer_cash_transactions
    return CashTransaction.none if viewer.blank?

    current_context.cash_transactions
  end
end
