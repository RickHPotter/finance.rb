# frozen_string_literal: true

class Views::Friendships::Index < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::DOMID

  include CacheHelper
  include TranslateHelper
  include ComponentsHelper

  attr_reader :friendships, :current_user

  def initialize(friendships:, current_user:)
    @friendships = friendships
    @current_user = current_user
  end

  def view_template
    turbo_frame_tag :center_container do
      div(class: resource_index_shell_class) do
        render_hero

        render_request_form

        render_received_requests
        render_sent_requests
        render_active_friends
        render_blocked_friends
      end
    end
  end

  private

  def render_hero
    div(class: resource_index_hero_class) do
      h1(class: resource_index_title_class) { I18n.t("friendships.index.title") }
    end
  end

  def render_request_form
    div(class: "mb-8 p-4 rounded-lg border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-900/50") do
      h2(class: "text-md font-bold mb-3 dark:text-slate-200") { I18n.t("friendships.index.add_friend") }
      form_with(url: friendships_path, method: :post, class: "flex gap-2", data: { turbo_frame: "_top" }) do |form|
        form.text_field :friend_public_id,
                        placeholder: I18n.t("friendships.index.friend_id_placeholder"),
                        class: input_class,
                        required: true
        Button(type: :submit, class: "shrink-0 #{submit_button_class(:new)}") { I18n.t("friendships.index.send_request") }
      end
    end
  end

  def render_received_requests
    received = friendships.select { |f| f.friend_id == current_user.id && f.pending_state? }
    return if received.empty?

    section(class: "mb-8") do
      h2(class: "text-lg font-bold mb-4 dark:text-slate-200") { I18n.t("friendships.index.received_requests") }
      ul(class: "flex flex-col gap-3") do
        received.each do |friendship|
          li(class: "flex items-center justify-between p-3 rounded border border-slate-200 dark:border-slate-800") do
            span { friendship.user.profile&.display_name || friendship.user.email }
            div(class: "flex gap-2") do
              button_to(
                I18n.t("friendships.index.accept"),
                friendship_path(friendship.public_id, state: "accepted"),
                method: :patch,
                data: { turbo_frame: "_top" },
                class: "px-3 py-1 bg-green-500 text-white rounded hover:bg-green-600 text-sm font-semibold"
              )
              button_to(
                I18n.t("friendships.index.reject"),
                friendship_path(friendship.public_id, state: "rejected"),
                method: :patch,
                data: { turbo_frame: "_top" },
                class: "px-3 py-1 bg-red-500 text-white rounded hover:bg-red-600 text-sm font-semibold"
              )
            end
          end
        end
      end
    end
  end

  def render_sent_requests
    sent = friendships.select { |f| f.user_id == current_user.id && f.pending_state? }
    return if sent.empty?

    section(class: "mb-8") do
      h2(class: "text-lg font-bold mb-4 dark:text-slate-200") { I18n.t("friendships.index.sent_requests") }
      ul(class: "flex flex-col gap-3") do
        sent.each do |friendship|
          li(class: "flex items-center justify-between p-3 rounded border border-slate-200 dark:border-slate-800 text-slate-500") do
            span { friendship.friend.profile&.display_name || friendship.friend.email }
            button_to I18n.t("friendships.index.cancel"), friendship_path(friendship.public_id), method: :delete, data: { turbo_frame: "_top" },
                                                                                                 class: "text-sm underline hover:text-red-500"
          end
        end
      end
    end
  end

  def render_active_friends
    active = friendships.select(&:accepted_state?)
    return if active.empty?

    section(class: "mb-8") do
      h2(class: "text-lg font-bold mb-4 dark:text-slate-200") { I18n.t("friendships.index.my_friends") }
      ul(class: "flex flex-col gap-3") do
        active.each do |friendship|
          other_user = friendship.user_id == current_user.id ? friendship.friend : friendship.user
          li(class: "flex items-center justify-between p-3 rounded border border-slate-200 dark:border-slate-800") do
            span(class: "font-medium") { other_user.profile&.display_name || other_user.email }
            div(class: "flex items-center gap-4") do
              form_with(model: friendship, url: friendship_path(friendship.public_id), method: :patch, class: "flex items-center gap-2",
                        data: { turbo_frame: "_top" }) do |form|
                form.label :auto_accept_actionable_messages, I18n.t("friendships.index.auto_accept"), class: "text-sm text-slate-500"
                form.check_box :auto_accept_actionable_messages, onchange: "this.form.requestSubmit()",
                                                                 class: "rounded border-slate-300 text-indigo-600 focus:ring-indigo-500"
              end

              button_to(
                I18n.t("friendships.index.block"),
                friendship_path(friendship.public_id, state: "blocked"),
                method: :patch,
                data: { turbo_frame: "_top" },
                class: "text-sm text-orange-500 hover:underline"
              )

              button_to(
                I18n.t("friendships.index.remove"),
                friendship_path(friendship.public_id),
                method: :delete,
                data: { turbo_frame: "_top" },
                class: "text-sm text-red-500 hover:underline"
              )
            end
          end
        end
      end
    end
  end

  def render_blocked_friends
    blocked = friendships.select(&:blocked_state?)
    return if blocked.empty?

    section(class: "mb-8") do
      h2(class: "text-lg font-bold mb-4 dark:text-slate-200") { I18n.t("friendships.index.blocked_users") }
      ul(class: "flex flex-col gap-3") do
        blocked.each do |friendship|
          other_user = friendship.user_id == current_user.id ? friendship.friend : friendship.user
          li(class: "flex items-center justify-between p-3 rounded border border-slate-200 dark:border-slate-800 text-slate-400 line-through") do
            span(class: "font-medium") { other_user.profile&.display_name || other_user.email }
            button_to(
              I18n.t("friendships.index.remove_block"),
              friendship_path(friendship.public_id),
              method: :delete,
              data: { turbo_frame: "_top" },
              class: "text-sm text-slate-500 hover:underline"
            )
          end
        end
      end
    end
  end
end
