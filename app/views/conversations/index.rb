# frozen_string_literal: true

class Views::Conversations::Index < Views::Base
  attr_reader :conversations, :active_filter

  register_value_helper :current_user

  include Phlex::Rails::Helpers::AssetPath
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  def initialize(conversations:, active_filter: "all")
    @conversations = conversations
    @active_filter = active_filter
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "mx-1 min-h-[calc(100svh-22rem)] rounded-lg bg-white shadow-md shadow-red-50") do
        div(class: "flex items-center justify-between border-b border-stone-200 px-4 py-3") do
          h1(class: "text-sm font-semibold uppercase tracking-[0.2em] text-stone-700") { action_model(:index, Conversation) }
        end

        div(class: "border-b border-stone-100 px-3 py-3 md:px-4") do
          div(class: "flex flex-wrap gap-2") do
            render_filter_badge("all")
            render_filter_badge("unread")
            render_filter_badge("human")
            render_filter_badge("assistant")
          end
        end

        div(class: "space-y-3 p-3 md:p-4") do
          conversations.each do |conversation|
            render_conversation_card(conversation)
          end
        end
      end
    end
  end

  private

  def render_filter_badge(filter)
    selected = active_filter == filter

    link_to(
      filter_path_for(filter),
      class: filter_badge_class(filter, selected),
      data: { turbo_frame: "_top", turbo_prefetch: "false" }
    ) do
      model_attribute(Conversation, filter)
    end
  end

  def filter_path_for(filter)
    next_filter = active_filter == filter || filter == "all" ? nil : filter

    conversations_path(filter: next_filter)
  end

  def filter_badge_class(filter, selected)
    base_class = "inline-flex items-center rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.16em] transition"

    return "#{base_class} border-stone-900 bg-stone-900 text-white" if selected && filter == "all"
    return "#{base_class} border-red-600 bg-red-600 text-white" if selected && filter == "unread"
    return "#{base_class} border-stone-900 bg-stone-900 text-white" if selected && filter == "human"
    return "#{base_class} border-amber-500 bg-amber-500 text-stone-950" if selected && filter == "assistant"

    "#{base_class} border-stone-200 bg-white text-stone-600 hover:border-stone-400 hover:text-stone-900"
  end

  def render_conversation_card(conversation)
    unread_count = conversation.unread_count_for(current_user)
    latest_message = conversation.latest_message

    link_to(
      conversation_path(conversation),
      class: conversation_card_class(conversation),
      data: { turbo_frame: "_top", turbo_prefetch: "false" }
    ) do
      div(class: "flex items-start justify-between gap-3") do
        div(class: "flex min-w-0 items-center gap-3") do
          image_tag asset_path("avatars/#{conversation_avatar_name(conversation)}"), class: conversation_avatar_class(conversation)

          div(class: "min-w-0") do
            p(class: "text-sm font-semibold text-stone-900") { conversation.title_for(current_user) }
          end
        end

        if unread_count.positive?
          span(class: "inline-flex min-w-6 items-center justify-center rounded-full bg-red-600 px-2 py-1 text-xs font-semibold text-white") { unread_count.to_s }
        end
      end

      p(class: "mt-3 line-clamp-2 text-sm text-stone-600") { latest_message_preview(latest_message) }
    end
  end

  def conversation_card_class(conversation)
    base_class = "block rounded-lg border px-4 py-3 transition"

    if conversation.assistant?
      "#{base_class} border-amber-200 bg-amber-50 hover:border-amber-300 hover:bg-amber-100"
    else
      "#{base_class} border-stone-200 bg-stone-50 hover:border-red-300 hover:bg-red-50"
    end
  end

  def conversation_avatar_name(conversation)
    return "people/21.png" if conversation.assistant?

    counterpart_entities[conversation.friend_for(current_user)&.id]&.avatar_name || "people/0.png"
  end

  def conversation_avatar_class(conversation)
    ring_class = conversation.assistant? ? "ring-amber-200" : "ring-stone-200"

    "size-11 rounded-full bg-white object-cover ring-2 #{ring_class}"
  end

  def counterpart_entities
    @counterpart_entities ||= current_user.entities.that_are_users.index_by(&:entity_user_id)
  end

  def latest_message_preview(message)
    return model_attribute(Conversation, :no_messages_yet) if message.nil?

    message.preview_body.presence || model_attribute(Conversation, :empty_message)
  end
end
