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

      it { should validate_uniqueness_of(:category_name).scoped_to(:user_id) }
    end

    context "( associations )" do
      bt_models = %i[user]
      hm_models = %i[category_transactions card_transactions cash_transactions investments]

      bt_models.each { |model| it { should belong_to(model) } }
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
#  category_name           :string           not null, uniquely indexed => [user_id]
#  colour                  :string           default("#f1f5f9"), not null
#  text_colour             :string
#  text_colour_mode        :string           default("automatic"), not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  user_id                 :bigint           not null, indexed, uniquely indexed => [category_name]
#
# Indexes
#
#  index_categories_on_user_id           (user_id)
#  index_category_name_on_composite_key  (user_id,category_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
