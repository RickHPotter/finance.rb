# frozen_string_literal: true

module Components
  class ProfileAvatar < Base
    include Phlex::Rails::Helpers::AssetPath

    attr_reader :user, :css_class

    def initialize(user:, **attrs)
      @user = user
      @css_class = attrs.delete(:class) || "size-11 rounded-full object-cover"
    end

    def view_template
      img(
        src: avatar_source,
        alt: display_name,
        class: css_class,
        data: { profile_avatar: attached? ? "attached" : "fallback" }
      )
    end

    private

    def attached?
      profile = user&.profile
      profile.present? && profile.avatar.attached?
    end

    def avatar_source
      return rails_blob_path(user.profile.avatar, only_path: true) if attached?

      asset_path("avatars/people/0.png")
    end

    def display_name
      user&.profile&.display_name.presence || user&.email || User.model_name.human
    end
  end
end
