# frozen_string_literal: true

module Components
  class FooterLink < Base
    include Phlex::Rails::Helpers::LinkTo

    attr_reader :href, :link_attrs

    def initialize(href:, wrapper_class: nil, **link_attrs)
      @href = href
      @link_attrs = link_attrs
      super(class: wrapper_class || "text-sm text-white hover:bg-gray-600")
    end

    def view_template(&)
      div(**attrs) do
        link_to(href, **link_attrs, &)
      end
    end
  end
end
