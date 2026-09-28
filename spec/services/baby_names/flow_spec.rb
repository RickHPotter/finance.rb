# frozen_string_literal: true

require "rails_helper"

RSpec.describe BabyNames::Flow do
  let!(:user) { create(:user, id: 1) }
  let!(:partner) { create(:user, :different, id: 4) }
  let!(:name1) { create(:baby_name, name: "Arthur", position: 1) }
  let!(:name2) { create(:baby_name, name: "Theo", position: 2) }
  let!(:name3) { create(:baby_name, name: "Lucas", position: 3) }

  subject(:flow) { described_class.new(user) }

  describe "#current_phase and sync" do
    it "starts at phase1" do
      expect(flow.current_phase).to eq("phase1")
      expect(flow.phase_completed?).to be(false)
    end

    it "marks user completed when all names have final decisions" do
      create(:baby_name_decision, user:, baby_name: name1, choice: "accepted")
      create(:baby_name_decision, user:, baby_name: name2, choice: "rejected")
      create(:baby_name_decision, user:, baby_name: name3, choice: "accepted")

      expect(flow.phase_completed?).to be(true)
      expect(flow.current_phase).to eq("phase1")
      expect(flow.partner_phase_completed?).to be(false)
    end

    it "transitions to phase2 when both users finish phase1" do
      [ name1, name2, name3 ].each do |bn|
        create(:baby_name_decision, user:, baby_name: bn, choice: "accepted")
        create(:baby_name_decision, user: partner, baby_name: bn, choice: "accepted")
      end

      expect(flow.current_phase).to eq("phase2")
      expect(flow.phase_completed?).to be(false)
    end
  end

  describe "#calculate_n" do
    it "returns 3 if mutual names are 15 or more" do
      names = create_list(:baby_name, 15)
      names.each do |bn|
        create(:baby_name_decision, user:, baby_name: bn, choice: "accepted")
        create(:baby_name_decision, user: partner, baby_name: bn, choice: "accepted")
      end

      expect(flow.calculate_n).to eq(3)
    end

    it "calculates n to make total around 15 or 16 when mutual names are fewer" do
      # If mutual count is 6, (16 - 6) / 2 = 5
      names = create_list(:baby_name, 6)
      names.each do |bn|
        create(:baby_name_decision, user:, baby_name: bn, choice: "accepted")
        create(:baby_name_decision, user: partner, baby_name: bn, choice: "accepted")
      end

      expect(flow.calculate_n).to eq(5)
    end
  end

  describe "Phase II to IV flow" do
    before do
      BabyNameProcessState.for(user).update!(phase: "phase2", phase_completed: false)
      BabyNameProcessState.for(partner).update!(phase: "phase2", phase_completed: false)
    end

    it "skips phase 3 if both accepted lists are identical" do
      create(:baby_name_decision, user:, baby_name: name1, choice: "accepted")
      create(:baby_name_decision, user: partner, baby_name: name1, choice: "accepted")

      flow.complete_phase2!([ name1.id ])
      described_class.new(partner).complete_phase2!([ name1.id ])

      expect(flow.current_phase).to eq("phase4")
    end

    it "transitions to phase 3 if accepted lists are not identical" do
      create(:baby_name_decision, user:, baby_name: name1, choice: "accepted")
      create(:baby_name_decision, user:, baby_name: name2, choice: "accepted")
      create(:baby_name_decision, user: partner, baby_name: name1, choice: "accepted")
      create(:baby_name_decision, user: partner, baby_name: name3, choice: "accepted")

      flow.complete_phase2!([ name1.id, name2.id ])
      described_class.new(partner).complete_phase2!([ name1.id, name3.id ])

      expect(flow.current_phase).to eq("phase3")
    end

    it "positions repescagem names starting at K + 1 in phase 3" do
      create(:baby_name_decision, user:, baby_name: name1, choice: "accepted")
      create(:baby_name_decision, user:, baby_name: name2, choice: "accepted")
      create(:baby_name_decision, user: partner, baby_name: name3, choice: "accepted")

      BabyNameProcessState.for(user).update!(phase: "phase3", phase_completed: false)

      # User 1 accepted 2 names (K = 2). Selected repescagem name gets position 3 (2 + 1)
      flow.complete_phase3!([ name3.id ])

      decision = user.baby_name_decisions.find_by(baby_name_id: name3.id)
      expect(decision.position).to eq(3)
    end
  end

  describe "#final_rankings" do
    before do
      BabyNameProcessState.for(user).update!(phase: "completed", phase_completed: true)
      BabyNameProcessState.for(partner).update!(phase: "completed", phase_completed: true)

      create(:baby_name_decision, user:, baby_name: name1, choice: "accepted", position: 1)
      create(:baby_name_decision, user:, baby_name: name2, choice: "accepted", position: 2)

      create(:baby_name_decision, user: partner, baby_name: name1, choice: "accepted", position: 2)
      create(:baby_name_decision, user: partner, baby_name: name2, choice: "accepted", position: 1)
    end

    it "computes ascending points and returns user positions and names" do
      rankings = flow.final_rankings
      expect(rankings.size).to eq(2)
      first_item = rankings.first
      expect(first_item[:score]).to eq(3)
      expect(first_item[:user_name]).to be_present
      expect(first_item[:partner_name]).to be_present
      expect(first_item[:user_position]).to be_in([ 1, 2 ])
      expect(first_item[:partner_position]).to be_in([ 1, 2 ])
    end
  end
end
