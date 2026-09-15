# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("lib/rspec_workflow")

RSpec.describe RspecWorkflow do
  describe ".arguments_for" do
    it "builds disjoint fixed-seed suite profiles" do
      expect(described_class.arguments_for("fast", [])).to eq([ "--tag", "~type:feature", "--tag", "~operational", "--seed", "20260914" ])
      expect(described_class.arguments_for("feature", [])).to eq([ "spec/features", "--seed", "20260914" ])
      expect(described_class.arguments_for("operational", [])).to eq([ "--tag", "operational", "--seed", "20260914" ])
      expect(described_class.arguments_for("full", [])).to eq([ "--seed", "20260914" ])
    end

    it "keeps focused paths unmodified and respects an explicit seed" do
      expect(described_class.arguments_for("focused", [ "spec/models/user_spec.rb:12" ])).to eq([ "spec/models/user_spec.rb:12" ])
      expect(described_class.arguments_for("full", [ "--seed=42" ])).to eq([ "--seed=42" ])
    end

    it "rejects unknown profiles and empty focused runs" do
      expect { described_class.arguments_for("quick", []) }.to raise_error(RspecWorkflow::UnknownProfileError)
      expect { described_class.arguments_for("focused", []) }.to raise_error(RspecWorkflow::MissingFocusedPathError)
    end
  end

  it "identifies coverage and fixed-seed reproduction profiles" do
    expect(described_class.coverage_profile?("coverage")).to be(true)
    expect(described_class.reproduction_profile?("reproduce")).to be(true)
    expect(described_class.coverage_profile?("full")).to be(false)
  end
end
