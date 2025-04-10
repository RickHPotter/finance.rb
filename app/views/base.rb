# frozen_string_literal: true

module Views
  class Base < Components::Base
    include Phlex::Rails::Helpers::TurboFrameTag

    def params
      context[:rails_view_context].params
    end

    def thin__label(form, field)
      span(class: "font-poetsen-one font-thin text-gray-500") { model_attribute(form.object, field).downcase }
    end
  end
end
