# frozen_string_literal: true

# Component to render a tab
class TabsComponent < ViewComponent::Base
  # includes ..................................................................
  # security (i.e. attr_accessible) ...........................................
  attr_reader :items

  # public instance methods ...................................................
  def initialize(items: [], dependents: [], default: false, dependent: false, dependent_no: nil)
    @items = items
    @default = default
    @dependent = dependent
    @dependent_no = dependent_no
    @dependents = dependents
    super
  end

  Item = Struct.new(:label, :icon, :link, :turbo_frame)

  # private instance methods ..................................................
end

# TODO: Following features:
# - Make the Item Struct cleaner on the Controller
# - Create MultiCheckBoxComponent
# - Pass in dependents as other structure other than itself (after creating MultiCheckBoxComponent)
