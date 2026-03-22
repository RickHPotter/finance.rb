# frozen_string_literal: true

class Views::Conversations::Show < Views::Base
  register_value_helper :current_user
  attr_reader :conversation, :messages, :active_message_filter, :active_message_sides

  include Phlex::Rails::Helpers::TurboStreamFrom
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper

  def initialize(conversation:, messages: conversation.messages.order(:created_at), active_message_filter: "all", active_message_sides: %w[mine theirs])
    @conversation = conversation
    @messages = messages
    @active_message_filter = active_message_filter
    @active_message_sides = active_message_sides
  end

  def view_template
    div(class: "w-full") do
      turbo_frame_tag :center_container do
        div(class: "mx-1 min-h-[calc(100svh-18rem)] rounded-lg border border-stone-200 bg-white shadow-md shadow-red-50") do
          div(class: "flex h-[calc(100svh-18rem)] min-h-[36rem] flex-col overflow-hidden rounded-lg", data: { controller: :chat }) do
            div(class: "border-b px-4 py-4 md:px-5 #{header_container_class} md:flex md:items-center md:justify-between md:gap-6") do
              div(class: "flex items-center gap-4 md:min-w-0 md:flex-1") do
                div(class: "relative shrink-0") do
                  image_tag(asset_path("avatars/#{conversation_avatar_name}"), class: conversation_avatar_class)
                  div(class: "absolute -bottom-1 -right-1 size-3 rounded-full border-2 border-white #{presence_dot_class}")
                end

                div(class: "min-w-0 flex-1") do
                  h2(class: "truncate text-left text-base font-semibold text-stone-900 md:text-lg") { conversation.title_for(current_user) }
                  p(class: "mt-1 text-left text-[10px] font-medium uppercase tracking-[0.18em] text-stone-500 md:text-xs") { subtitle_text }
                end
              end

              if conversation.assistant?
                div(class: "mt-4 md:mt-0 md:shrink-0") do
                  render_message_filter_badges
                end
              end
            end

            div(class: "flex-1 overflow-y-auto bg-[radial-gradient(circle_at_top,_rgba(255,255,255,0.75),_rgba(241,245,249,0.95))] px-3 py-4 md:px-4",
                id: "messages_#{conversation.id}", data: { chat_target: :scroll }) do
              turbo_stream_from conversation
              render Views::Messages::Index.new(messages:)
            end

            unless conversation.assistant?
              div(class: "border-t px-3 py-3 md:px-4 #{composer_container_class}") do
                render Views::Messages::Form.new(conversation:)
              end
            end
          end
        end
      end
    end
  end

  private

  def conversation_avatar_name
    return "people/21.png" if conversation.assistant?

    current_user.entities.that_are_users.find_by(entity_user: conversation.friend_for(current_user))&.avatar_name || "people/0.png"
  end

  def conversation_avatar_class
    ring_class = conversation.assistant? ? "ring-amber-200" : "ring-slate-300"

    "size-12 rounded-full bg-white object-cover ring-2 #{ring_class}"
  end

  def header_container_class
    if conversation.assistant?
      "bg-gradient-to-r from-amber-50 via-amber-100 to-orange-50 border-amber-200"
    else
      "bg-gradient-to-r from-stone-50 via-slate-100 to-stone-100 border-slate-200"
    end
  end

  def composer_container_class
    if conversation.assistant?
      "bg-amber-50/80 border-amber-200"
    else
      "bg-stone-50/90 border-stone-200"
    end
  end

  def presence_dot_class
    conversation.assistant? ? "bg-amber-500" : "bg-emerald-500"
  end

  def subtitle_text
    conversation.assistant? ? model_attribute(conversation, :assistant) : model_attribute(conversation, :chat)
  end

  def render_message_filter_badges
    div(class: "flex flex-wrap items-center gap-2 md:flex-nowrap") do
      div(class: "flex flex-wrap items-center gap-2") do
        render_message_filter_badge("pending")
        render_message_filter_badge("all")
      end

      span(class: "hidden text-stone-400 md:inline") { "|" }

      div(class: "flex flex-wrap items-center gap-2") do
        render_message_side_badge("theirs")
        render_message_side_badge("mine")
      end
    end
  end

  def render_message_filter_badge(filter)
    selected = active_message_filter == filter

    Link(
      href: conversation_path(conversation, message_filter: filter, message_side: active_message_sides),
      class: message_filter_badge_class(selected),
      data: { turbo_frame: "_top", turbo_prefetch: "false" }
    ) do
      model_attribute(conversation, filter)
    end
  end

  def render_message_side_badge(side)
    selected = active_message_sides.include?(side)
    next_sides = toggled_message_sides(side)

    Link(
      href: conversation_path(conversation, message_filter: active_message_filter, message_side: next_sides),
      class: message_side_badge_class(side, selected),
      data: { turbo_frame: "_top", turbo_prefetch: "false" }
    ) do
      model_attribute(conversation, side)
    end
  end

  def message_filter_badge_class(selected)
    base_class = "inline-flex items-center rounded-full border px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.16em] transition"

    return "#{base_class} border-stone-800 bg-stone-900 text-white" if selected

    "#{base_class} border-stone-300 bg-white text-stone-600 hover:border-stone-400 hover:text-stone-900"
  end

  def message_side_badge_class(side, selected)
    base_class = "inline-flex items-center rounded-full border px-3 py-1.5 text-[10px] font-semibold uppercase tracking-[0.16em] transition"

    return "#{base_class} border-amber-600 bg-amber-500 text-white"     if selected && side == "theirs"
    return "#{base_class} border-emerald-600 bg-emerald-500 text-white" if selected && side == "mine"

    "#{base_class} border-stone-200 bg-white text-stone-600 hover:border-stone-400 hover:text-stone-900"
  end

  def toggled_message_sides(side)
    toggled_sides = if active_message_sides.include?(side)
                      active_message_sides - [ side ]
                    else
                      active_message_sides + [ side ]
                    end

    toggled_sides.presence || [ side ]
  end
end
