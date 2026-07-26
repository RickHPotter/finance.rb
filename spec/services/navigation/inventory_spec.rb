# frozen_string_literal: true

require "rails_helper"
require "yaml"

RSpec.describe "Turbo navigation inventory", type: :service do
  let(:inventory_path) { Rails.root.join("docs/sprints/4-kakashi/kakashi-15/navigation-inventory.yml") }
  let(:format_link_pattern) { /format:\s*:turbo_stream/ }
  let(:center_replacement_pattern) { /turbo_stream\.replace\(:center_container/ }
  let(:classifications) { %w[in_place_stream remove top_level_drive] }
  let(:inventory) { YAML.safe_load_file(inventory_path) }

  it "classifies every explicit stream-format top-level link" do
    expected = inventory.fetch("format_turbo_stream_links").to_h do |entry|
      expect(entry.fetch("classification")).to be_in(classifications)
      expect(entry.fetch("slice")).to be_between(2, 9)

      [ entry.fetch("path"), entry.fetch("occurrences") ]
    end

    expect(occurrences_for(format_link_pattern)).to eq(expected)
  end

  it "classifies every center-container stream replacement without overlapping rules" do
    actual = occurrences_for(center_replacement_pattern)
    rules = inventory.fetch("center_container_replacements")

    actual.each_key do |path|
      expect(rules.count { |rule| rule_matches_path?(rule, path) }).to eq(1), "expected exactly one inventory rule for #{path}"
    end

    rules.each do |rule|
      expect(rule.fetch("classification")).to be_in(classifications)
      expect(rule.fetch("slice")).to be_between(2, 9)
      expect(occurrences_for_rule(actual, rule)).to eq(rule.fetch("expected_occurrences"))
    end
  end

  it "keeps the obsolete custom history shim classified for removal" do
    history_shim = inventory.fetch("legacy_history_shim")
    source = Rails.root.join(history_shim.fetch("path")).read

    expect(history_shim.fetch("classification")).to eq("remove")
    expect(history_shim.fetch("slice")).to eq(10)
    expect(source).to include(*history_shim.fetch("markers"))
  end

  def occurrences_for(pattern)
    Rails.root.glob("app/**/*.{rb,erb}").sort.each_with_object({}) do |path, occurrences|
      count = path.read.scan(pattern).size
      occurrences[path.relative_path_from(Rails.root).to_s] = count if count.positive?
    end
  end

  def occurrences_for_rule(actual, rule)
    actual.sum do |path, count|
      rule_matches_path?(rule, path) ? count : 0
    end
  end

  def rule_matches_path?(rule, path)
    return rule.fetch("paths").include?(path) if rule.key?("paths")

    File.fnmatch?(rule.fetch("glob"), path)
  end
end
