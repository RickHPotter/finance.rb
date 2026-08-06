# frozen_string_literal: true

class Views::Friendships::Card < Views::Base
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::DOMID

  include TranslateHelper

  attr_reader :friendship, :current_user

  def initialize(friendship:, current_user:)
    @friendship = friendship
    @current_user = current_user
  end

  def view_template
    other_user = friendship.user_id == current_user.id ? friendship.friend : friendship.user

    li(id: dom_id(friendship), class: "flex items-center justify-between p-3 rounded border border-slate-200 dark:border-slate-800") do
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
