# frozen_string_literal: true

class Views::Conversations::Index < Views::Base
  attr_reader :conversations, :active_filter, :page_cursor, :next_cursor

  register_value_helper :current_user
  register_value_helper :current_context

  include Phlex::Rails::Helpers::LinkTo

  include TranslateHelper

  def initialize(conversations:, active_filter: "active", page_cursor: nil, next_cursor: nil)
    @conversations = conversations
    @active_filter = active_filter
    @page_cursor = page_cursor
    @next_cursor = next_cursor
  end

  def view_template
    if page_cursor.present?
      render_conversation_page_frame(page_cursor)
      return
    end

    turbo_frame_tag :center_container do
      div(class: compact_crud_shell_class) do
        div(class: compact_crud_header_class) do
          div(class: "flex flex-col items-start") do
            h1(class: compact_crud_title_class) { action_model(:index, Conversation, 2) }
            render_scenario_badge
          end

          Link(
            href: new_conversation_path,
            class: new_conversation_button_class,
            data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: "false" }
          ) { model_attribute(Conversation, :new_conversation) }
        end

        div(class: compact_crud_panel_class) do
          div(class: "flex flex-wrap gap-2") do
            render_filter_badge("active")
            render_filter_badge("unread")
            render_filter_badge("human")
            render_filter_badge("assistant")
            render_filter_badge("archived")
            render_filter_badge("muted")
          end
        end

        div(class: "space-y-3 p-3 md:p-4") do
          if conversations.empty?
            render_empty_state
          else
            render_conversation_page
          end
        end
      end
    end
  end

  private

  def render_conversation_page
    conversations.each { |conversation| render_conversation_card(conversation) }
    render_next_page_frame
  end

  def render_conversation_page_frame(cursor)
    turbo_frame_tag conversation_page_frame_id(cursor) do
      render_conversation_page
    end
  end

  def render_next_page_frame
    return if next_cursor.blank?

    frame_id = conversation_page_frame_id(next_cursor)
    turbo_frame_tag frame_id do
      Link(
        href: conversations_path(filter: active_filter == "active" ? nil : active_filter, cursor: next_cursor),
        class: "flex w-full items-center justify-center rounded-lg border border-stone-300 bg-white px-4 py-3 text-sm font-semibold text-stone-700 " \
               "hover:bg-stone-100 dark:border-slate-700 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800",
        data: { turbo_frame: frame_id, turbo_prefetch: "false", conversation_page: "next" }
      ) { model_attribute(Conversation, :load_more) }
    end
  end

  def conversation_page_frame_id(cursor)
    "conversations_page_#{cursor}"
  end

  def render_filter_badge(filter)
    selected = active_filter == filter

    link_to(
      filter_path_for(filter),
      class: filter_badge_class(filter, selected),
      data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: "false" }
    ) do
      model_attribute(Conversation, filter)
    end
  end

  def filter_path_for(filter)
    next_filter = active_filter == filter || filter == "active" ? nil : filter

    conversations_path(filter: next_filter)
  end

  def filter_badge_class(filter, selected)
    base_class = "inline-flex items-center rounded-full border px-3 py-1.5 text-xs font-semibold uppercase tracking-[0.16em] transition"

    return "#{base_class} border-stone-900 bg-stone-900 text-white dark:border-slate-100 dark:bg-slate-100 dark:text-slate-950" if selected && filter == "active"
    return "#{base_class} border-red-600 bg-red-600 text-white" if selected && filter == "unread"
    return "#{base_class} border-stone-900 bg-stone-900 text-white dark:border-slate-100 dark:bg-slate-100 dark:text-slate-950" if selected && filter == "human"
    if selected && filter == "assistant"
      return "#{base_class} border-amber-500 bg-amber-500 text-stone-950 dark:border-amber-400 dark:bg-amber-500 dark:text-stone-950"
    end
    return "#{base_class} border-sky-600 bg-sky-600 text-white" if selected && filter == "archived"
    return "#{base_class} border-violet-600 bg-violet-600 text-white" if selected && filter == "muted"

    "#{base_class} #{inactive_badge_class}"
  end

  def render_conversation_card(conversation)
    unread_count = conversation.unread_count_for(current_user)
    latest_message = conversation.latest_message
    participant = conversation.participant_for!(current_user)

    div(class: conversation_card_class(conversation), data: { conversation_id: conversation.public_id }) do
      div(class: "flex items-start justify-between gap-3") do
        link_to(
          conversation_path(conversation),
          class: "flex min-w-0 flex-1 items-center gap-3",
          data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: "false" }
        ) do
          ProfileAvatar(user: conversation.friend_for(current_user), class: conversation_avatar_class(conversation))

          div(class: "min-w-0") do
            p(class: "text-sm font-semibold text-stone-900 dark:text-slate-100") { conversation.title_for(current_user) }
            p(class: "mt-1 text-2xs font-semibold uppercase tracking-[0.15em] text-stone-500 dark:text-slate-400") do
              plain(model_attribute(Conversation, conversation.kind))
              plain(" · #{scenario_label}")
            end
          end
        end

        if unread_count.positive?
          span(class: "inline-flex min-w-6 items-center justify-center rounded-full bg-red-600 px-2 py-1 text-xs font-semibold text-white") { unread_count.to_s }
        end
      end

      p(class: "mt-3 line-clamp-2 text-sm text-stone-600 dark:text-slate-300") { latest_message_preview(latest_message) }
      div(class: conversation_footer_class) do
        span { latest_activity_label(conversation, latest_message) }
        render_participant_controls(conversation, participant)
      end
    end
  end

  def conversation_card_class(conversation)
    base_class = "rounded-lg border px-4 py-3 transition"

    if conversation.assistant?
      "#{base_class} border-amber-200 bg-amber-50 hover:border-amber-300 hover:bg-amber-100 dark:border-amber-500/40 dark:bg-amber-950/30 dark:hover:bg-amber-950/50"
    else
      "#{base_class} #{human_conversation_card_class}"
    end
  end

  def inactive_badge_class
    "border-stone-200 bg-white text-stone-600 hover:border-stone-400 hover:text-stone-900 dark:border-slate-700 dark:bg-slate-900 " \
      "dark:text-slate-300 dark:hover:border-slate-500 dark:hover:text-slate-100"
  end

  def new_conversation_button_class
    "rounded-lg border border-purple-500 bg-purple-100 px-3 py-2 text-xs font-semibold text-purple-900 transition " \
      "hover:bg-purple-500 hover:text-white dark:bg-slate-900 dark:text-purple-300"
  end

  def conversation_footer_class
    "mt-3 flex flex-wrap items-center justify-between gap-2 border-t border-stone-200 pt-2 text-2xs text-stone-500 " \
      "dark:border-slate-700 dark:text-slate-400"
  end

  def human_conversation_card_class
    "border-stone-200 bg-stone-50 hover:border-red-300 hover:bg-red-50 dark:border-slate-700 dark:bg-slate-800 " \
      "dark:hover:border-red-500/50 dark:hover:bg-red-950/30"
  end

  def conversation_avatar_class(conversation)
    ring_class = conversation.assistant? ? "ring-amber-200" : "ring-stone-200"

    "size-11 rounded-full bg-white object-cover ring-2 #{ring_class} dark:ring-slate-600"
  end

  def render_participant_controls(conversation, participant)
    div(class: "flex flex-wrap gap-2") do
      render_state_link(conversation, participant.archived? ? :unarchive : :archive)
      render_state_link(conversation, participant.muted? ? :unmute : :mute)
    end
  end

  def render_state_link(conversation, action)
    Link(
      href: public_send("#{action}_conversation_path", conversation),
      class: "rounded-md border border-stone-300 bg-white px-2 py-1 font-semibold text-stone-700 hover:bg-stone-100 " \
             "dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800",
      data: { turbo_method: :patch, turbo_frame: "_top", turbo_prefetch: "false", conversation_action: action }
    ) { model_attribute(Conversation, action) }
  end

  def render_scenario_badge
    p(class: "mt-2 text-xs font-semibold text-stone-500 dark:text-slate-400", data: { conversation_scenario: scenario_label }) do
      plain(Context.model_name.human)
      plain(": #{scenario_label}")
    end
  end

  def scenario_label
    current_context.main? ? I18n.t("contexts.index.main_label") : current_context.name
  end

  def latest_activity_label(conversation, latest_message)
    timestamp = latest_message&.created_at || conversation.created_at
    I18n.l(timestamp, format: :short)
  end

  def render_empty_state
    div(class: "rounded-xl border border-dashed border-stone-300 p-8 text-center dark:border-slate-700") do
      p(class: "text-sm font-semibold text-stone-700 dark:text-slate-200") { model_attribute(Conversation, :empty_filter) }
      p(class: "mt-2 text-sm text-stone-500 dark:text-slate-400") { model_attribute(Conversation, :empty_filter_hint) }
    end
  end

  def latest_message_preview(message)
    return model_attribute(Conversation, :no_messages_yet) if message.nil?

    message.preview_body.presence || model_attribute(Conversation, :empty_message)
  end
end
