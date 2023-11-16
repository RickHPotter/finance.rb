# frozen_string_literal: true

# Component to render a tab
class TabsComponent < ViewComponent::Base
  attr_reader :items

  def initialize(items: [], dependents: [], default: false, dependent: false, dependent_no: nil)
    @items = items
    @default = default
    @dependent = dependent
    @dependent_no = dependent_no
    @dependents = dependents
    super
  end

  Item = Struct.new(:label, :icon, :link, :turbo_frame)
end
