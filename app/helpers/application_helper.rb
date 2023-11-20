# frozen_string_literal: true

# Overall Helper
module ApplicationHelper
  def data_attributes(data)
    data&.map do |key, value|
      "data-#{key.to_s.gsub('_', '-')}=\"#{value}\""
    end&.join(' ')&.html_safe
  end
end
