# frozen_string_literal: true

# Component to render a tab.
module Components
  class TabsComponent < ViewComponent::Base
    # @includes .................................................................
    # @security (i.e. attr_accessible) ..........................................
    attr_reader :items

    # @public_instance_methods ..................................................

    # Initialises a Tab Component.
    #
    # @param items [Array] Array of Item Structs.
    # @param default [Boolean] Whether the tab is the default tab (default is false).
    # @param dependent [Boolean] Whether the tab is dependent (default is false).
    # @param dependent_no [Integer] The number of the dependent tab (default is nil).
    # @param mobile [Boolean] Whether the tab is for mobile (default is false).
    #
    # @return [TabComponent] A new instance of TabComponent.
    #
    def initialize(items: [ nil, [] ], default: false, dependent: false, dependent_no: nil, mobile: @mobile)
      @items = items.first
      @dependents = items&.second
      @default = default
      @dependent = dependent
      @dependent_no = dependent_no
      @mobile = mobile
      super
    end

    Item = Struct.new(:label, :icon, :link, :default, :turbo_frame)
  end
end
