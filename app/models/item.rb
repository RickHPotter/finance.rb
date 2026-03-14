# frozen_string_literal: true

class Item
  attr_accessor :label, :icon, :link, :default, :notification_type, :turbo_frame

  def initialize(label, icon, link, default, notification_type = 0, turbo_frame = :center_container) # rubocop:disable Metrics/ParameterLists
    @label = label
    @icon = icon
    @link = link
    @default = default
    @notification_type = notification_type
    @turbo_frame = turbo_frame
  end
end
