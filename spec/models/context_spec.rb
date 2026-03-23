# frozen_string_literal: true

require "rails_helper"

RSpec.describe Context, type: :model do
  let(:subject) { build(:context) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      it { should validate_presence_of(:name) }
      it { should validate_uniqueness_of(:name).scoped_to(:user_id) }
    end

    context "( associations )" do
      it { should belong_to(:user) }
      it { should belong_to(:source_context).class_name("Context").optional }
      it { should have_many(:card_transactions).dependent(:destroy) }
      it { should have_many(:cash_transactions).dependent(:destroy) }
      it { should have_many(:derived_contexts).class_name("Context").with_foreign_key(:source_context_id).dependent(:nullify) }
    end
  end

  describe "[ business logic ]" do
    it "flags archived? when archived_at is present" do
      subject.archived_at = Time.zone.now

      expect(subject).to be_archived
    end

    it "exposes main and derived scopes" do
      main_context = create(:user, :random).main_context
      derived_context = create(:context, user: main_context.user, source_context: main_context)

      expect(described_class.main).to include(main_context)
      expect(described_class.derived).to include(derived_context)
    end
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
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  source_context_id :bigint           indexed
#  user_id           :bigint           not null, uniquely indexed => [name], indexed, uniquely indexed
#
# Indexes
#
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
