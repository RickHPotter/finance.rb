# frozen_string_literal: true

require "rails_helper"

RSpec.describe Budget, type: :model do
  let(:subject) { build(:budget) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[month year].each do |attribute|
        it { should validate_presence_of(attribute) }
      end
    end

    context "( associations )" do
      it { should belong_to(:user) }

      hm_models = %i[budget_categories categories budget_entities entities]
      hm_models.each { |model| it { should have_many(model) } }

      it "belongs to context" do
        association = described_class.reflect_on_association(:context)

        expect(association.macro).to eq(:belongs_to)
        expect(association.options[:optional]).to be(false)
      end
    end
  end

  describe "[ business logic ]" do
    it "defaults context to the user's main context" do
      budget = described_class.new(
        user: subject.user,
        description: "Context default",
        month: 3,
        year: 2026,
        value: -100,
        remaining_value: -100
      )

      budget.budget_categories.build(category: subject.user.categories.first)
      budget.valid?

      expect(budget.context).to eq(subject.user.main_context)
    end

    it "remains valid when an inclusive budget adds another entity to itself" do
      user = create(:user, :random)
      category = create(:category, :random, user:)
      first_entity = create(:entity, :random, user:)
      second_entity = create(:entity, :random, user:)

      budget = create(
        :budget,
        user:,
        context: user.main_context,
        month: 5,
        year: 2026,
        inclusive: true,
        budget_categories: [ build(:budget_category, category:) ],
        budget_entities: [ build(:budget_entity, entity: first_entity) ]
      )

      budget.assign_attributes(
        budget_entities_attributes: [
          { id: budget.budget_entities.first.id, entity_id: first_entity.id },
          { entity_id: second_entity.id }
        ]
      )

      expect(budget).to be_valid
    end
  end
end

# == Schema Information
#
# Table name: budgets
# Database name: primary
#
#  id                     :bigint           not null, primary key
#  active                 :boolean          default(TRUE), not null
#  balance                :integer
#  description            :string           not null
#  first_installment_only :boolean          default(FALSE), not null
#  inclusive              :boolean          default(FALSE), not null
#  month                  :integer          not null
#  remaining_value        :integer          not null
#  starting_value         :integer          not null
#  value                  :integer          not null
#  year                   :integer          not null
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#  context_id             :bigint           not null, indexed
#  order_id               :integer          indexed
#  user_id                :bigint           not null, indexed
#
# Indexes
#
#  idx_budgets_order_id         (order_id)
#  index_budgets_on_context_id  (context_id)
#  index_budgets_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (context_id => contexts.id)
#  fk_rails_...  (user_id => users.id)
#
