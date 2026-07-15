# frozen_string_literal: true

class AddPiggyBankBuiltInCategories < ActiveRecord::Migration[8.1]
  class MigrationUser < ActiveRecord::Base
    self.table_name = "users"
  end

  class MigrationCategory < ActiveRecord::Base
    self.table_name = "categories"
  end

  def up
    categories = [ "PIGGY BANK", "PIGGY BANK RETURN" ]
    colours    = %i[oldmoney money]

    MigrationUser.find_each do |user|
      categories.each_with_index do |category_name, index|
        category = MigrationCategory.find_or_initialize_by(user_id: user.id, category_name:)
        category.assign_attributes(built_in: true, active: true, colour: colours[index])
        category.save!
      end
    end
  end

  def down
    MigrationCategory.where(category_name: [ "PIGGY BANK", "PIGGY BANK RETURN" ], built_in: true).delete_all
  end
end
