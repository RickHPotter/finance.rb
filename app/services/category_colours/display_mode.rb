# frozen_string_literal: true

class CategoryColours::DisplayMode
  ROW_COLOURED = "row_coloured"
  BADGES_ONLY = "badges_only"
  DEFAULT = ROW_COLOURED
  ALL = [ ROW_COLOURED, BADGES_ONLY ].freeze

  class << self
    def for(user)
      value = user.preference&.row_color_mode if user.respond_to?(:preference)
      resolve(value)
    end

    def resolve(value)
      candidate = value.to_s
      ALL.include?(candidate) ? candidate : DEFAULT
    end
  end
end
