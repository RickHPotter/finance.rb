# frozen_string_literal: true

class Views::Conversations::Show < Views::Base
  register_value_helper :current_user
  register_value_helper :current_context

  include Phlex::Rails::Helpers::TurboStreamFrom

  include TranslateHelper

  attr_reader :conversation, :messages, :active_message_filter, :active_message_sides, :message_page_cursor, :next_message_cursor, :streamables

  def initialize(
    conversation:,
    streamables:,
    messages: conversation.messages.order(:created_at),
    active_message_filter: "all",
    active_message_sides: %w[mine theirs],
    message_page_cursor: nil,
    next_message_cursor: nil
  )
    @conversation = conversation
    @messages = messages
    @active_message_filter = active_message_filter
    @active_message_sides = active_message_sides
    @message_page_cursor = message_page_cursor
    @next_message_cursor = next_message_cursor
    @streamables = streamables
  end

  def view_template
    if message_page_cursor.present?
      render_message_page_frame(message_page_cursor)
      return
    end

    turbo_frame_tag :center_container do
      div(class: "#{compact_crud_shell_class} ring ring-stone-200 dark:ring-slate-800") do
        div(class: "flex h-[calc(100svh-16rem)] min-h-128 flex-col overflow-hidden rounded-lg sm:min-h-144", data: { controller: :chat }) do
          div(class: "border-b px-4 py-4 md:px-5 #{header_container_class} md:flex md:items-center md:justify-between md:gap-6") do
            div(class: "flex items-center gap-4 md:min-w-0 md:flex-1") do
              Link(
                href: conversations_path,
                class: "shrink-0 rounded-lg border border-stone-300 bg-white px-2 py-2 text-xs font-semibold text-stone-700 hover:bg-stone-100 " \
                       "dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800",
                data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: "false", conversation_back: "true" }
              ) { model_attribute(conversation, :back) }

              ProfileAvatar(user: conversation.friend_for(current_user), class: conversation_avatar_class)

              div(class: "flex min-w-0 flex-1 flex-col items-start") do
                h2(class: "truncate text-left text-base font-semibold text-stone-900 md:text-lg dark:text-slate-100") { conversation.title_for(current_user) }
                p(class: "mt-1 text-left text-2xs font-medium uppercase tracking-[0.18em] text-stone-500 md:text-xs dark:text-slate-400") { subtitle_text }
                render_scenario_badge
              end
            end

            div(class: "mt-4 flex flex-col items-stretch gap-2 md:mt-0 md:shrink-0 md:items-end md:self-start") do
              render_message_filter_badges if conversation.assistant?
              render_participant_controls
            end
          end

          div(class: messages_container_class,
              id: "messages_#{conversation.id}", data: { chat_target: :scroll }) do
            turbo_stream_from(*streamables)
            if messages.empty? && conversation.human?
              render_empty_human_conversation
            else
              render_next_message_page_frame
              render Views::Messages::Index.new(messages:)
            end
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

  def render_message_page_frame(cursor)
    turbo_frame_tag message_page_frame_id(cursor) do
      render_next_message_page_frame
      render Views::Messages::Index.new(messages:)
    end
  end

  def render_next_message_page_frame
    return if next_message_cursor.blank?

    frame_id = message_page_frame_id(next_message_cursor)
    turbo_frame_tag(
      frame_id,
      data: {
        action: "turbo:before-fetch-request->chat#rememberScrollPosition turbo:frame-load->chat#restoreScrollPosition"
      }
    ) do
      Link(
        href: conversation_path(
          conversation,
          message_cursor: next_message_cursor,
          message_filter: active_message_filter,
          message_side: active_message_sides
        ),
        class: "mx-auto mb-3 flex w-fit items-center justify-center rounded-full border border-stone-300 bg-white px-4 py-2 text-xs font-semibold " \
               "text-stone-700 hover:bg-stone-100 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800",
        data: { turbo_frame: frame_id, turbo_prefetch: "false", message_page: "older" }
      ) { model_attribute(Conversation, :load_older) }
    end
  end

  def message_page_frame_id(cursor)
    "older_messages_#{conversation.id}_#{cursor}"
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

  def subtitle_text
    conversation.assistant? ? model_attribute(conversation, :assistant) : model_attribute(conversation, :chat)
  end

  def render_scenario_badge
    badge_class = "mt-2 inline-flex items-center border-l-4 border-red-700 bg-rose-400/30 px-3 py-1 text-2xs font-semibold uppercase"

    div(class: badge_class, data: { conversation_scenario: scenario_label }) do
      plain(Context.model_name.human)
      plain(": ")
      plain(scenario_label)
    end
  end

  def scenario_label
    current_context.main? ? I18n.t("contexts.index.main_label") : current_context.name
  end

  def render_participant_controls
    participant = conversation.participant_for!(current_user)

    div(class: "flex flex-wrap gap-2") do
      render_state_link(participant.archived? ? :unarchive : :archive)
      render_state_link(participant.muted? ? :unmute : :mute)
    end
  end

  def render_state_link(action)
    Link(
      href: public_send("#{action}_conversation_path", conversation),
      class: "rounded-lg border border-stone-300 bg-white px-3 py-1.5 text-2xs font-semibold text-stone-700 hover:bg-stone-100 " \
             "dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800",
      data: { turbo_method: :patch, turbo_frame: "_top", turbo_prefetch: "false", conversation_action: action }
    ) { model_attribute(conversation, action) }
  end

  def render_empty_human_conversation
    div(class: "flex h-full min-h-48 flex-col items-center justify-center px-6 text-center", data: { conversation_empty: "human" }) do
      p(class: "text-sm font-semibold text-stone-700 dark:text-slate-200") { model_attribute(conversation, :empty_human) }
      p(class: "mt-2 max-w-sm text-sm text-stone-500 dark:text-slate-400") { model_attribute(conversation, :empty_human_hint) }
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
      data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: "false" }
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
      data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: "false" }
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
