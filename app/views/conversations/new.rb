# frozen_string_literal: true

class Views::Conversations::New < Views::Base
  include Phlex::Rails::Helpers::ButtonTo

  include TranslateHelper

  attr_reader :friendships

  def initialize(friendships:)
    @friendships = friendships
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: compact_crud_shell_class) do
        div(class: compact_crud_header_class) do
          div do
            h1(class: compact_crud_title_class) { model_attribute(Conversation, :start_conversation) }
            render_selected_scenario
          end

          Link(
            href: conversations_path,
            class: secondary_action_class,
            data: { turbo_frame: "_top", turbo_action: "advance", turbo_prefetch: "false" }
          ) { model_attribute(Conversation, :back_to_conversations) }
        end

        if friendships.empty?
          render_empty_state
        else
          div(class: "grid grid-cols-1 gap-3 p-3 sm:grid-cols-2 md:p-4") do
            friendships.each { |friendship| render_friend(friendship) }
          end
        end
      end
    end
  end

  private

  def render_friend(friendship)
    friend = friendship.user_id == current_user.id ? friendship.friend : friendship.user

    div(class: "flex items-center gap-3 rounded-xl border border-stone-200 bg-stone-50 p-3 dark:border-slate-700 dark:bg-slate-800") do
      ProfileAvatar(user: friend, class: "size-12 rounded-full bg-white object-cover ring-2 ring-stone-200 dark:ring-slate-600")

      div(class: "min-w-0 flex-1") do
        p(class: "truncate text-sm font-semibold text-stone-900 dark:text-slate-100") { profile_name(friend) }
        p(class: "truncate text-xs text-stone-500 dark:text-slate-400") { friend.email }
      end

      button_to(
        model_attribute(Conversation, :open),
        conversations_path(friendship_public_id: friendship.public_id),
        method: :post,
        class: primary_action_class,
        form: { data: { turbo_frame: "_top", turbo_action: "advance" } }
      )
    end
  end

  def render_empty_state
    div(class: "p-8 text-center") do
      p(class: "text-sm font-semibold text-stone-700 dark:text-slate-200") { model_attribute(Conversation, :no_available_friends) }
      p(class: "mt-2 text-sm text-stone-500 dark:text-slate-400") { model_attribute(Conversation, :no_available_friends_hint) }
    end
  end

  def render_selected_scenario
    p(class: "mt-2 text-xs font-semibold text-stone-500 dark:text-slate-400", data: { conversation_scenario: scenario_label }) do
      plain(Context.model_name.human)
      plain(": #{scenario_label}")
    end
  end

  def scenario_label
    current_context.main? ? I18n.t("contexts.index.main_label") : current_context.name
  end

  def profile_name(user)
    user.profile&.display_name.presence || user.email
  end

  def primary_action_class
    "rounded-lg border border-emerald-700 bg-emerald-600 px-3 py-2 text-xs font-semibold text-white transition hover:bg-emerald-700"
  end

  def secondary_action_class
    "rounded-lg border border-stone-300 bg-white px-3 py-2 text-xs font-semibold text-stone-700 transition hover:bg-stone-100 " \
      "dark:border-slate-600 dark:bg-slate-900 dark:text-slate-200 dark:hover:bg-slate-800"
  end
end
