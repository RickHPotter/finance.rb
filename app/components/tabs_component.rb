# frozen_string_literal: true

# Component to render a tab
class TabsComponent < ViewComponent::Base
  attr_reader :items

  def initialize(items: [])
    @items = items
    super
  end

  Item = Struct.new(:label, :icon, :link, :turbo_frame)
end
