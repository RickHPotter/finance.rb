# frozen_string_literal: true

class Context < ApplicationRecord
  attr_reader :destroying_for_removal

  belongs_to :user
  belongs_to :source_context, class_name: "Context", optional: true

  has_many :budgets, dependent: :destroy
  has_many :card_transactions, dependent: :destroy
  has_many :card_installments, through: :card_transactions
  has_many :cash_transactions, dependent: :destroy
  has_many :cash_installments, through: :cash_transactions
  has_many :investments, dependent: :destroy
  has_many :references, dependent: :destroy
  has_many :subscriptions, class_name: "Subscription", dependent: :destroy
  has_many :derived_contexts, class_name: "Context", foreign_key: :source_context_id, dependent: :nullify, inverse_of: :source_context

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :main, inclusion: { in: [ true, false ] }

  before_validation :assign_scenario_key
  before_destroy :mark_destroying_for_removal, prepend: true

  scope :main, -> { where(main: true) }
  scope :derived, -> { where(main: false) }
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }

  def derived?
    !main?
  end

  def archived?
    archived_at.present?
  end

  def removable?
    derived? && archived? && derived_contexts.none?
  end

  def destroying_for_removal?
    destroying_for_removal
  end

  private

  def mark_destroying_for_removal
    @destroying_for_removal = true
  end

  def assign_scenario_key
    if main?
      self.scenario_key = nil
      return
    end

    self.scenario_key ||= SecureRandom.uuid
  end
end

# == Schema Information
#
# Table name: contexts
# Database name: primary
#
#  id                :bigint           not null, primary key
#  archived_at       :datetime
#  cloned_at         :datetime
#  description       :text
#  main              :boolean          default(FALSE), not null
#  name              :string           not null, uniquely indexed => [user_id]
#  scenario_key      :string           indexed
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  source_context_id :bigint           indexed
#  user_id           :bigint           not null, uniquely indexed => [name], indexed, uniquely indexed
#
# Indexes
#
#  index_contexts_on_scenario_key             (scenario_key)
#  index_contexts_on_source_context_id        (source_context_id)
#  index_contexts_on_user_and_name            (user_id,name) UNIQUE
#  index_contexts_on_user_id                  (user_id)
#  index_contexts_on_user_id_where_main_true  (user_id) UNIQUE WHERE (main = true)
#
# Foreign Keys
#
#  fk_rails_...  (source_context_id => contexts.id)
#  fk_rails_...  (user_id => users.id)
#
