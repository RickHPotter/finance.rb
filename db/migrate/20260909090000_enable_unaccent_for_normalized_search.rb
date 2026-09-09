# frozen_string_literal: true

class EnableUnaccentForNormalizedSearch < ActiveRecord::Migration[8.1]
  def change
    enable_extension "unaccent"
  end
end
