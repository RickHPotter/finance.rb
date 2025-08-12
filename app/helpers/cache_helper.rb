# frozen_string_literal: true

module CacheHelper
  def render_icon(icon_name)
    Rails.cache.fetch(icon_name, expires_in: 7.days) do
      render "shared/icons/#{icon_name}"
    end
  end

  def cached_icon(icon_name)
    cache(icon_name, expires_in: 7.days) do
      render partial "shared/icons/#{icon_name}"
    end
  end
end
