# frozen_string_literal: true

module CacheHelper
  def render_icon(icon_name)
    Rails.cache.fetch(icon_name, expires_in: 3.days) do
      render "shared/icons/#{icon_name}"
    end
  end
end
