# frozen_string_literal: true

class AddFailedLendBorrowReturnBuiltInCategory < ActiveRecord::Migration[8.1]
  def up
    User.find_each do |user|
      category = user.categories.find_or_create_by!(category_name: "FAILED LEND/BORROW RETURN")
      category.update!(built_in: true) unless category.built_in?
    end
  end

  def down
    Category.where(built_in: true, category_name: "FAILED LEND/BORROW RETURN").delete_all
  end
end
