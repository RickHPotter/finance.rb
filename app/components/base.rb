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
  end
end
