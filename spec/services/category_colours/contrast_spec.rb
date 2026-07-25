# frozen_string_literal: true

require "rails_helper"

RSpec.describe CategoryColours::Contrast, type: :service do
  describe ".normalize" do
    it "accepts convenient hex input and returns canonical lowercase six-digit hex" do
      {
        "#abc" => "#aabbcc",
        "ABC" => "#aabbcc",
        "#A1B2C3" => "#a1b2c3",
        "a1b2c3" => "#a1b2c3",
        "  #F0A  " => "#ff00aa"
      }.each do |input, expected|
        expect(described_class.normalize(input)).to eq(expected)
      end
    end

    it "rejects non-strings, malformed values, names, functions, and transparency" do
      invalid_values = [
        nil, :white, 123_456, "", " ", "#12", "#abcd", "#aabbccdd",
        "white", "transparent", "rgb(1, 2, 3)", "##fff", "#ggg"
      ]

      invalid_values.each do |value|
        expect { described_class.normalize(value) }.to raise_error(described_class::InvalidColour)
      end
    end

    it "returns an immutable canonical value" do
      expect(described_class.normalize("#ABC")).to be_frozen
    end
  end

  describe ".relative_luminance" do
    it "calculates known black, white, and saturated luminance values" do
      expect(described_class.relative_luminance("#000000")).to eq(0.0)
      expect(described_class.relative_luminance("#ffffff")).to eq(1.0)
      expect(described_class.relative_luminance("#ff0000")).to be_within(0.000001).of(0.2126)
      expect(described_class.relative_luminance("#00ff00")).to be_within(0.000001).of(0.7152)
      expect(described_class.relative_luminance("#0000ff")).to be_within(0.000001).of(0.0722)
    end

    it "uses the current WCAG sRGB linearization boundary" do
      boundary_channel = "#0a0000"
      above_boundary_channel = "#0b0000"

      expected_boundary = 0.2126 * ((10.0 / 255) / 12.92)
      expected_above = 0.2126 * ((((11.0 / 255) + 0.055) / 1.055)**2.4)

      expect(described_class.relative_luminance(boundary_channel)).to be_within(0.000000001).of(expected_boundary)
      expect(described_class.relative_luminance(above_boundary_channel)).to be_within(0.000000001).of(expected_above)
    end
  end

  describe ".ratio" do
    it "calculates the WCAG contrast ratio symmetrically" do
      expect(described_class.ratio("#000000", "#ffffff")).to eq(21.0)
      expect(described_class.ratio("#ffffff", "#000000")).to eq(21.0)
      expect(described_class.ratio("#123456", "#123456")).to eq(1.0)
    end

    it "retains unrounded precision around the AA boundary" do
      passing_ratio = described_class.ratio("#ffffff", "#767676")
      failing_ratio = described_class.ratio("#ffffff", "#777777")

      expect(passing_ratio).to be > described_class::MINIMUM_RATIO
      expect(passing_ratio).to be_within(0.001).of(4.542)
      expect(failing_ratio).to be < described_class::MINIMUM_RATIO
      expect(failing_ratio).to be_within(0.001).of(4.478)
    end
  end

  describe "#automatic_foreground" do
    it "chooses the higher-contrast neutral for light, dark, middle, and saturated backgrounds" do
      {
        "#ffffff" => "#000000",
        "#f5f5f5" => "#000000",
        "#000000" => "#ffffff",
        "#111111" => "#ffffff",
        "#808080" => "#000000",
        "#ff0000" => "#000000",
        "#00ff00" => "#000000",
        "#0000ff" => "#ffffff"
      }.each do |background, expected|
        expect(described_class.new(background).automatic_foreground).to eq(expected)
      end
    end
  end

  describe "#assess" do
    subject(:contrast) { described_class.new("#FFFFFF") }

    it "returns an immutable passing assessment with normalized values and an accessible suggestion" do
      assessment = contrast.assess("767676")

      expect(assessment.background).to eq("#ffffff")
      expect(assessment.foreground).to eq("#767676")
      expect(assessment.ratio).to be_within(0.001).of(4.542)
      expect(assessment.minimum_ratio).to eq(4.5)
      expect(assessment.suggested_foreground).to eq("#000000")
      expect(assessment.ratio_label).to eq("4.54:1")
      expect(assessment).to be_passing
      expect(assessment).to be_frozen
    end

    it "returns a failing assessment without silently replacing the manual foreground" do
      assessment = contrast.assess("#777777")

      expect(assessment.foreground).to eq("#777777")
      expect(assessment.suggested_foreground).to eq("#000000")
      expect(assessment.ratio_label).to eq("4.48:1")
      expect(assessment).not_to be_passing
    end

    it "accepts a ratio exactly at the unrounded threshold and rejects the next higher threshold" do
      exact_ratio = described_class.ratio("#ffffff", "#767676")

      stub_const("#{described_class}::MINIMUM_RATIO", exact_ratio)
      expect(contrast.assess("#767676")).to be_passing

      stub_const("#{described_class}::MINIMUM_RATIO", exact_ratio.next_float)
      expect(contrast.assess("#767676")).not_to be_passing
    end

    it "rejects an invalid foreground instead of returning a guessed assessment" do
      expect { contrast.assess("transparent") }.to raise_error(described_class::InvalidColour)
    end
  end

  describe "#automatic_assessment" do
    it "returns the resolved foreground and maximum neutral contrast" do
      assessment = described_class.new("#0000ff").automatic_assessment

      expect(assessment.foreground).to eq("#ffffff")
      expect(assessment.suggested_foreground).to eq("#ffffff")
      expect(assessment.ratio).to be_within(0.001).of(8.592)
      expect(assessment).to be_passing
    end
  end
end
