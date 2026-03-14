# frozen_string_literal: true

module Components
  class Base < RubyUI::Base
    include Phlex::Rails::Helpers::Routes

    include Components

    if Rails.env.development?
      def before_template
        comment { "Before #{self.class.name}" }
        super
      end
    end

    def thin__label(form, field)
      span(class: "font-poetsen-one font-thin text-gray-500") { model_attribute(form.object, field).downcase }
    end
  end
end
