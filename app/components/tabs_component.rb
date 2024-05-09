# frozen_string_literal: true

# Component to render a tab.
class TabsComponent < ViewComponent::Base
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  attr_reader :items

  # @public_instance_methods ..................................................

  # Initialises a Tab Component.
  #
  # @param items [Array] Array of Item Structs.
  # @param dependents [Array] Array of dependent items.
  # @param default [Boolean] Whether the tab is the default tab (default is false).
  # @param dependent [Boolean] Whether the tab is dependent (default is false).
  # @param dependent_no [Integer] The number of the dependent tab (default is nil).
  #
  # @return [TabComponent] A new instance of TabComponent.
  #
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
