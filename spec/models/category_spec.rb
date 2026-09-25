# frozen_string_literal: true

require "rails_helper"

RSpec.describe Category, type: :model do
  let(:subject) { build(:category, :random, built_in: false) }

  describe "[ activerecord validations ]" do
    context "( presence, uniqueness, etc )" do
      it "is valid with valid attributes" do
        expect(subject).to be_valid
      end

      %i[category_name colour].each do |attribute|
        it { should validate_presence_of(attribute) }
      end

      it { should validate_uniqueness_of(:category_name).scoped_to(%i[user_id parent_category_id]) }
    end

    context "( associations )" do
      bt_models = %i[user parent_category]
      hm_models = %i[category_transactions card_transactions cash_transactions investments subcategories]

      bt_models.each { |model| it { should belong_to(model).optional(model == :parent_category) } }
      hm_models.each { |model| it { should have_many(model) } }
    end
  end

  describe "[ business logic ]" do
    context "( public methods )" do
      it "returns built_in value" do
        expect(subject.built_in?).to eq false
        expect(Category.built_in).to_not include(subject)
        subject.update(built_in: true)
        expect(subject.built_in?).to eq true
        expect(Category.built_in).to include(subject)
      end

      it "normalizes background colours and defaults to automatic text colour" do
        subject.colour = " ABC "
        subject.text_colour = "#123456"

        expect(subject).to be_valid
        expect(subject.colour).to eq("#aabbcc")
        expect(subject.text_colour_mode).to eq("automatic")
        expect(subject.text_colour).to be_nil
      end

      it "accepts a sufficiently contrasting manual foreground and exposes its resolved assessment" do
        subject.colour = "#FFFFFF"
        subject.text_colour_mode = "manual"
        subject.text_colour = "767676"

        expect(subject).to be_valid
        expect(subject.colour).to eq("#ffffff")
        expect(subject.text_colour).to eq("#767676")
        expect(subject.resolved_text_colour).to eq("#767676")
        expect(subject.colour_contrast_ratio).to be_within(0.001).of(4.542)
      end

      it "rejects a manual foreground below the minimum contrast with measured guidance" do
        subject.colour = "#ffffff"
        subject.text_colour_mode = "manual"
        subject.text_colour = "#777777"

        expect(subject).not_to be_valid
        expect(subject.errors.details[:text_colour]).to include(
          error: :insufficient_contrast,
          ratio: "4.48:1",
          minimum: "4.50:1",
          suggestion: "#000000"
        )
        expect(subject.errors.full_messages).to include(
          "Text colour must have at least 4.50:1 contrast against the background (measured 4.48:1; try #000000)"
        )
      end

      it "revalidates a manual foreground whenever the background changes" do
        subject.assign_attributes(colour: "#000000", text_colour_mode: "manual", text_colour: "#ffffff")
        expect(subject).to be_valid

        subject.colour = "#ffffff"
        expect(subject).not_to be_valid
        expect(subject.errors.of_kind?(:text_colour, :insufficient_contrast)).to be(true)
      end

      it "rejects named, transparent, alpha, malformed, and invalid mode values" do
        [ "white", "transparent", "#aabbccdd", "#12" ].each do |invalid_colour|
          subject.colour = invalid_colour
          expect(subject).not_to be_valid
          expect(subject.errors.of_kind?(:colour, :invalid)).to be(true)
        end

        subject.assign_attributes(colour: "#ffffff", text_colour_mode: "manual", text_colour: nil)
        expect(subject).not_to be_valid
        expect(subject.errors.of_kind?(:text_colour, :blank)).to be(true)

        subject.text_colour = "transparent"
        expect(subject).not_to be_valid
        expect(subject.errors.of_kind?(:text_colour, :invalid)).to be(true)

        subject.assign_attributes(colour: "#ffffff", text_colour_mode: "sometimes")
        expect(subject).not_to be_valid
        expect(subject.errors.of_kind?(:text_colour_mode, :inclusion)).to be(true)
      end

      it "derives the accessible foreground again after an automatic background change" do
        subject.assign_attributes(colour: "#ffffff", text_colour_mode: "automatic")
        expect(subject.resolved_text_colour).to eq("#000000")

        subject.colour = "#0000ff"
        expect(subject.resolved_text_colour).to eq("#ffffff")
      end

      it "rejects noncanonical backgrounds at the database boundary" do
        subject.save!

        expect { subject.update_columns(colour: "#FFFFFF") }
          .to raise_error(ActiveRecord::StatementInvalid, /categories_colour_hex_format/)
      end

      it "rejects mismatched text-colour modes and payloads at the database boundary" do
        subject.save!

        expect { subject.update_columns(text_colour_mode: "manual", text_colour: nil) }
          .to raise_error(ActiveRecord::StatementInvalid, /categories_text_colour_mode_payload/)
      end
    end
  end

  describe "[ hierarchy & scoping ]" do
    let(:user) { create(:user, :random) }
    let(:parent) { create(:category, :parent_category, user:, category_name: "HSH") }

    describe "scoped uniqueness" do
      it "allows subcategories with the same name under different parents" do
        other_parent = create(:category, :random, user:, category_name: "ASSETS")
        child_one = create(:category, user:, category_name: "SUPPLIES", parent_category: parent)
        child_two = build(:category, user:, category_name: "SUPPLIES", parent_category: other_parent)

        expect(child_one).to be_valid
        expect(child_two).to be_valid
      end

      it "rejects subcategories with the same name under the same parent" do
        create(:category, user:, category_name: "SUPPLIES", parent_category: parent)
        duplicate_child = build(:category, user:, category_name: "SUPPLIES", parent_category: parent)

        expect(duplicate_child).not_to be_valid
        expect(duplicate_child.errors.of_kind?(:category_name, :taken)).to be(true)
      end

      it "rejects top-level categories with the same name" do
        create(:category, user:, category_name: "HSH", parent_category: nil)
        duplicate_top = build(:category, user:, category_name: "HSH", parent_category: nil)

        expect(duplicate_top).not_to be_valid
        expect(duplicate_top.errors.of_kind?(:category_name, :taken)).to be(true)
      end
    end

    describe "depth limit and self-parenting" do
      it "rejects self-parenting via model validation" do
        parent.parent_category_id = parent.id

        expect(parent).not_to be_valid
        expect(parent.errors.of_kind?(:parent_category_id, :cannot_be_self)).to be(true)
      end

      it "rejects self-parenting via database check constraint" do
        standalone = create(:category, :random, user:)

        expect { standalone.update_columns(parent_category_id: standalone.id) }
          .to raise_error(ActiveRecord::StatementInvalid, /categories_no_self_parent/)
      end

      it "rejects a subcategory having subcategories (depth > 2)" do
        child = create(:category, user:, category_name: "SUPPLIES", parent_category: parent)
        grandchild = build(:category, user:, category_name: "SCREWS", parent_category: child)

        expect(grandchild).not_to be_valid
        expect(grandchild.errors.of_kind?(:parent_category_id, :cannot_be_child_of_child)).to be(true)
      end

      it "rejects assigning a parent to a category that already has subcategories" do
        create(:category, user:, category_name: "SUB", parent_category: parent)
        other_parent = create(:category, :random, user:, category_name: "PROPERTIES")
        parent.parent_category = other_parent

        expect(parent).not_to be_valid
        expect(parent.errors.of_kind?(:parent_category_id, :cannot_have_parent_when_has_children)).to be(true)
      end
    end

    describe "user boundary and built-in rules" do
      it "rejects a parent category belonging to another user" do
        other_user = create(:user, :random)
        other_parent = create(:category, :random, user: other_user)
        child = build(:category, user:, category_name: "SUPPLIES", parent_category: other_parent)

        expect(child).not_to be_valid
        expect(child.errors.of_kind?(:parent_category_id, :must_belong_to_same_user)).to be(true)
      end

      it "rejects assigning a built-in category as parent" do
        built_in_cat = create(:category, user:, category_name: "BUILTIN_PARENT", built_in: true)
        child = build(:category, user:, category_name: "SUPPLIES", parent_category: built_in_cat)

        expect(child).not_to be_valid
        expect(child.errors.of_kind?(:parent_category_id, :built_in_cannot_be_parent)).to be(true)
      end

      it "rejects assigning a parent to a built-in category" do
        built_in_cat = build(:category, user:, category_name: "BUILTIN_CHILD", built_in: true, parent_category: parent)

        expect(built_in_cat).not_to be_valid
        expect(built_in_cat.errors.of_kind?(:parent_category_id, :built_in_cannot_have_parent)).to be(true)
      end
    end

    describe "transactions and destruction" do
      it "allows direct transactions on a parent category" do
        create(:category_transaction, category: parent)

        expect(parent.reload.category_transactions.count).to eq(1)
        expect(parent).to be_valid
      end

      it "prevents destroying a parent category while it has subcategories" do
        create(:category, user:, category_name: "LABOUR", parent_category: parent)

        expect(parent.destroy).to be(false)
        expect(parent.errors[:base]).to be_present
        expect(parent.reload).to be_persisted
      end
    end

    describe "active state and cascade deactivation" do
      it "rejects activating a subcategory when its parent is inactive" do
        parent.update_columns(active: false)
        child = build(:category, user:, category_name: "LABOUR", parent_category: parent, active: true)

        expect(child).not_to be_valid
        expect(child.errors.of_kind?(:active, :cannot_be_active_when_parent_inactive)).to be(true)
      end

      it "cascades deactivation to all subcategories when parent is deactivated" do
        child1 = create(:category, user:, category_name: "LABOUR", parent_category: parent, active: true)
        child2 = create(:category, user:, category_name: "SUPPLIES", parent_category: parent, active: true)

        parent.update!(active: false)

        expect(child1.reload.active).to be(false)
        expect(child2.reload.active).to be(false)
      end
    end

    describe "predicates, subtree_ids, and rollups" do
      let!(:child1) do
        create(:category, user:, category_name: "LABOUR", parent_category: parent,
                          card_transactions_count: 3, card_transactions_total: 300,
                          cash_transactions_count: 2, cash_transactions_total: 200)
      end
      let!(:child2) do
        create(:category, user:, category_name: "SUPPLIES", parent_category: parent,
                          card_transactions_count: 5, card_transactions_total: 500,
                          cash_transactions_count: 4, cash_transactions_total: 400)
      end

      before do
        parent.update_columns(card_transactions_count: 1, card_transactions_total: 100,
                              cash_transactions_count: 1, cash_transactions_total: 100)
      end

      it "returns correct predicates" do
        expect(parent.parent?).to be(true)
        expect(parent.subcategory?).to be(false)
        expect(parent.standalone?).to be(false)

        expect(child1.parent?).to be(false)
        expect(child1.subcategory?).to be(true)
        expect(child1.standalone?).to be(false)

        standalone = create(:category, :random, user:)
        expect(standalone.parent?).to be(false)
        expect(standalone.subcategory?).to be(false)
        expect(standalone.standalone?).to be(true)
      end

      it "returns subtree_ids encompassing parent and all subcategories" do
        expect(parent.subtree_ids).to contain_exactly(parent.id, child1.id, child2.id)
      end

      it "calculates rollup counts and totals across direct and subcategory transactions" do
        expect(parent.rollup_card_transactions_count).to eq(1 + 3 + 5)
        expect(parent.rollup_card_transactions_total).to eq(100 + 300 + 500)
        expect(parent.rollup_cash_transactions_count).to eq(1 + 2 + 4)
        expect(parent.rollup_cash_transactions_total).to eq(100 + 200 + 400)
      end

      it "scopes categories by hierarchy level" do
        standalone = create(:category, :random, user:)

        expect(user.categories.where(built_in: false).top_level).to contain_exactly(parent, standalone)
        expect(user.categories.subcategories).to contain_exactly(child1, child2)
        expect(user.categories.parents).to contain_exactly(parent)
        expect(user.categories.where(built_in: false).leaves).to contain_exactly(child1, child2, standalone)
      end
    end
  end
end

# == Schema Information
#
# Table name: categories
# Database name: primary
#
#  id                      :bigint           not null, primary key
#  active                  :boolean          default(TRUE), not null
#  built_in                :boolean          default(FALSE), not null
#  card_transactions_count :integer          default(0), not null
#  card_transactions_total :integer          default(0), not null
#  cash_transactions_count :integer          default(0), not null
#  cash_transactions_total :integer          default(0), not null
#  category_name           :string           not null, uniquely indexed => [user_id, parent_category_id]
#  colour                  :string           default("#f1f5f9"), not null
#  text_colour             :string
#  text_colour_mode        :string           default("automatic"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  parent_category_id      :bigint           indexed, uniquely indexed => [user_id, category_name]
#  user_id                 :bigint           not null, indexed, uniquely indexed => [parent_category_id, category_name]
#
# Indexes
#
#  index_categories_on_parent_category_id       (parent_category_id)
#  index_categories_on_user_id                  (user_id)
#  index_categories_on_user_id_parent_and_name  (user_id,parent_category_id,category_name) UNIQUE NULLS NOT DISTINCT
#
# Foreign Keys
#
#  fk_rails_...  (parent_category_id => categories.id) ON DELETE => restrict
#  fk_rails_...  (user_id => users.id)
#
