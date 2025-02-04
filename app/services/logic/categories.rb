# frozen_string_literal: true

module Logic
  class Categories
    def self.create(category_params)
      category = Category.new(category_params)
      _handle_creation(category)
    end

    def self.update(category, category_params)
      category.assign_attributes(category_params)
      _handle_creation(category)
    end

    def self._handle_creation(category)
      category.save
      category
    end
  end
end
