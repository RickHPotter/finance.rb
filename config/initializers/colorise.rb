# frozen_string_literal: true

class String
  @colors_hash = { red: 31, green: 32, blue: 34, yellow: 33, pink: 35, cyan: 94, white: 97, light_grey: 37, black: 30 }

  @colors_hash.each do |key, value|
    define_method key do
      "\e[#{value}m #{self} \e[0m"
    end
  end
end
