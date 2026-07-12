# frozen_string_literal: true

class Views::Conversations::Show < Views::Base
  register_value_helper :current_user
  register_value_helper :current_context

  include Phlex::Rails::Helpers::TurboStreamFrom
  include Phlex::Rails::Helpers::ImageTag
  include Phlex::Rails::Helpers::AssetPath

  include TranslateHelper

  attr_reader :conversation, :messages, :active_message_filter, :active_message_sides

  def initialize(conversation:, messages: conversation.messages.order(:created_at), active_message_filter: "all", active_message_sides: %w[mine theirs])
    @conversation = conversation
    @messages = messages
    @active_message_filter = active_message_filter
    @active_message_sides = active_message_sides
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: "#{compact_crud_shell_class} ring ring-stone-200 dark:ring-slate-800") do
        div(class: "flex h-[calc(100svh-16rem)] min-h-128 flex-col overflow-hidden rounded-lg sm:min-h-144", data: { controller: :chat }) do
          div(class: "border-b px-4 py-4 md:px-5 #{header_container_class} md:flex md:items-center md:justify-between md:gap-6") do
            div(class: "flex items-center gap-4 md:min-w-0 md:flex-1") do
              div(class: "relative shrink-0") do
                image_tag(asset_path("avatars/#{conversation_avatar_name}"), class: conversation_avatar_class)
                div(class: "absolute -bottom-1 -right-1 size-3 rounded-full border-2 border-white #{presence_dot_class}")
              end

              div(class: "flex min-w-0 flex-1 flex-col items-start") do
                h2(class: "truncate text-left text-base font-semibold text-stone-900 md:text-lg dark:text-slate-100") { conversation.title_for(current_user) }
                p(class: "mt-1 text-left text-2xs font-medium uppercase tracking-[0.18em] text-stone-500 md:text-xs dark:text-slate-400") { subtitle_text }
                render_scenario_badge
              end
            end

            if conversation.assistant?
              div(class: "mt-4 md:mt-0 md:shrink-0 md:self-start") do
                render_message_filter_badges
              end
            end
          end

          div(class: messages_container_class,
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

  private

  def conversation_avatar_name
    return "people/21.png" if conversation.assistant?

    current_user.entities.that_are_users.find_by(entity_user: conversation.friend_for(current_user))&.avatar_name || "people/0.png"
  end

  def messages_container_class
    "flex-1 overflow-y-auto bg-[radial-gradient(circle_at_top,rgba(255,255,255,0.75),rgba(241,245,249,0.95))] px-3 py-4 " \
      "dark:bg-none dark:bg-slate-950 md:px-4"
  end

  def conversation_avatar_class
    ring_class = conversation.assistant? ? "ring-amber-200" : "ring-slate-300"

    "size-12 rounded-full bg-white object-cover ring-2 #{ring_class}"
  end

  def header_container_class
    if conversation.assistant?
      "bg-linear-to-r from-amber-50 via-amber-100 to-orange-50 border-amber-200 dark:border-amber-500/40 dark:from-amber-950/60 dark:via-slate-900 dark:to-slate-900"
    else
      "bg-linear-to-r from-stone-50 via-slate-100 to-stone-100 border-slate-200 dark:border-slate-700 dark:from-slate-900 dark:via-slate-900 dark:to-slate-800"
    end
  end

  def composer_container_class
    if conversation.assistant?
      "bg-amber-50/80 border-amber-200 dark:border-amber-500/40 dark:bg-amber-950/30"
    else
      "bg-stone-50/90 border-stone-200 dark:border-slate-700 dark:bg-slate-900"
    end
  end

  def presence_dot_class
    conversation.assistant? ? "bg-amber-500" : "bg-emerald-500"
  end

  def subtitle_text
    conversation.assistant? ? model_attribute(conversation, :assistant) : model_attribute(conversation, :chat)
  end

  def render_scenario_badge
    return if current_context.main?

    badge_class = "mt-2 inline-flex items-center border-l-4 border-red-700 bg-rose-400/30 " \
                  "px-3 py-1 text-2xs font-semibold uppercase"

    div(class: badge_class) do
      plain(Context.model_name.human)
      plain(": ")
      plain(current_context.main? ? I18n.t("contexts.index.main_label") : current_context.name)
    end
  end

  def render_message_filter_badges
    div(class: "flex flex-col items-stretch gap-2 sm:flex-row sm:flex-wrap sm:items-center md:flex-nowrap") do
      div(class: "flex flex-wrap items-center gap-2") do
        render_message_filter_badge("pending")
        render_message_filter_badge("all")
      end

      span(class: "hidden text-stone-400 dark:text-slate-600 md:inline") { "|" }

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
    base_class = "inline-flex items-center rounded-full border px-3 py-1.5 text-2xs font-semibold uppercase tracking-[0.16em] transition"

    return "#{base_class} border-stone-800 bg-stone-900 text-white dark:border-slate-100 dark:bg-slate-100 dark:text-slate-950" if selected

    "#{base_class} #{inactive_badge_class(:strong)}"
  end

  def message_side_badge_class(side, selected)
    base_class = "inline-flex items-center rounded-full border px-3 py-1.5 text-2xs font-semibold uppercase tracking-[0.16em] transition"

    return "#{base_class} border-amber-600 bg-amber-500 text-white"     if selected && side == "theirs"
    return "#{base_class} border-emerald-600 bg-emerald-500 text-white" if selected && side == "mine"

    "#{base_class} #{inactive_badge_class(:soft)}"
  end

  def inactive_badge_class(strength)
    border = strength == :strong ? "border-stone-300" : "border-stone-200"

    "#{border} bg-white text-stone-600 hover:border-stone-400 hover:text-stone-900 dark:border-slate-700 dark:bg-slate-900 " \
      "dark:text-slate-300 dark:hover:border-slate-500 dark:hover:text-slate-100"
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
