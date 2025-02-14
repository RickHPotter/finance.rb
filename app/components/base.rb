# frozen_string_literal: true

module Components
  class Base < Phlex::HTML
    include Phlex::Rails::Helpers::Routes

    def initialize(_)
      super()
    end
  end
end
