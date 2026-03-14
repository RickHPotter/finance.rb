# frozen_string_literal: true

module Views
  class Base < Components::Base
    include Phlex::Rails::Helpers::TurboFrameTag

    register_output_helper :combobox_tag

    def rails_view_context
      context[:rails_view_context]
    end

    def params
      rails_view_context.params
    end

    def request
      rails_view_context.request
    end
  end
end
