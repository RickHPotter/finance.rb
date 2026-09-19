# frozen_string_literal: true

class BabyNameProcessState < ApplicationRecord
  # @extends ..................................................................
  # @includes .................................................................
  # @security (i.e. attr_accessible) ..........................................
  # @relationships ............................................................
  belongs_to :user

  # @validations ..............................................................
  validates :user_id, uniqueness: true

  # @callbacks ................................................................
  # @scopes ...................................................................
  # @additional_config ........................................................
  enum :phase, {
    phase1: "phase_1",
    phase2: "phase_2",
    phase3: "phase_3",
    phase4: "phase_4",
    completed: "completed"
  }, validate: true

  # @class_methods ............................................................
  def self.for(user)
    find_or_create_by!(user:)
  end

  # @public_instance_methods ..................................................
  # @protected_instance_methods ...............................................
  # @private_instance_methods .................................................
end

# == Schema Information
#
# Table name: baby_name_process_states
# Database name: primary
#
#  id              :bigint           not null, primary key
#  phase           :string           default("phase1"), not null
#  phase_completed :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  user_id         :bigint           not null, uniquely indexed
#
# Indexes
#
#  index_baby_name_process_states_on_user_id  (user_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
