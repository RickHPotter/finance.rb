# frozen_string_literal: true

class Views::Shared::MobileFloatingNav < Views::Base
  include Phlex::Rails::Helpers::LinkTo

  include CacheHelper

  attr_reader :new_href, :new_data

  def initialize(new_href:, new_data: {})
    @new_href = new_href
    @new_data = new_data
  end

  def view_template
    div(class: "md:hidden") do
      link_to(
        "#",
        class: nav_button_class,
        style: hidden_nav_style,
        data: { mobile_scroll_nav: "bottom" }
      ) do
        cached_icon :bigger_bottom
      end

      link_to(
        new_href,
        class: "flex items-center justify-center fixed bottom-4 right-3 h-14 w-14 bg-blue-600 text-white rounded-full shadow-lg z-50",
        data: { turbo_frame: :_top, mobile_scroll_nav: "plus" }.merge(new_data)
      ) do
        cached_icon :bigger_plus
      end

      link_to(
        "#",
        class: nav_button_class,
        style: hidden_nav_style,
        data: { mobile_scroll_nav: "top" }
      ) do
        cached_icon :bigger_top
      end
    end
  end

  private

  def nav_button_class
    "opacity-0 translate-y-2 pointer-events-none flex items-center justify-center fixed bottom-24 right-3
     h-12 w-12 bg-gray-300/95 text-black rounded-full shadow-lg z-50 transition-all duration-200".squish
  end

  def hidden_nav_style
    "display: flex; visibility: hidden;"
  end
end
