# frozen_string_literal: true

module RspecWorkflow
  DEFAULT_SEED = "20260914"
  PROFILES = %w[focused fast feature operational full coverage reproduce].freeze

  class UnknownProfileError < ArgumentError; end
  class MissingFocusedPathError < ArgumentError; end

  def self.arguments_for(profile, arguments, seed: DEFAULT_SEED)
    profile = profile.to_s
    arguments = arguments.dup
    raise UnknownProfileError, profile unless PROFILES.include?(profile)
    raise MissingFocusedPathError if profile == "focused" && arguments.empty?

    profile_arguments = case profile
                        when "fast"
                          [ "--tag", "~type:feature", "--tag", "~operational" ]
                        when "feature"
                          [ "spec/features" ]
                        when "operational"
                          [ "--tag", "operational" ]
                        else
                          []
                        end

    result = profile_arguments + arguments
    result.push("--seed", seed) if seeded_profile?(profile) && result.none? { |argument| argument == "--seed" || argument.start_with?("--seed=") }
    result
  end

  def self.coverage_profile?(profile)
    profile.to_s == "coverage"
  end

  def self.reproduction_profile?(profile)
    profile.to_s == "reproduce"
  end

  def self.seeded_profile?(profile)
    !%w[focused reproduce].include?(profile.to_s)
  end

  private_class_method :seeded_profile?
end
