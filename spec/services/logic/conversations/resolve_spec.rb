# frozen_string_literal: true

require "rails_helper"

RSpec.describe Logic::Conversations::Resolve do
  let(:rikki) { create(:user, :random) }
  let(:gigi) { create(:user, :random) }
  let(:friendship) { create(:friendship, :accepted, user: rikki, friend: gigi) }

  it "resolves one canonical conversation from either friendship side" do
    from_rikki = described_class.call(actor: rikki, friendship:, kind: :human)
    from_gigi = described_class.call(actor: gigi, friendship:, kind: :human)

    expect(from_gigi).to eq(from_rikki)
    expect(from_rikki).to have_attributes(friendship:, kind: "human", scenario_key: nil)
    expect(from_rikki.users.order(:id)).to eq([ rikki, gigi ].sort_by(&:id))
  end

  it "keeps human, assistant, main, and exact derived scenarios separate" do
    scenario_key = SecureRandom.uuid
    create(:context, user: rikki, scenario_key:)
    create(:context, user: gigi, scenario_key:)

    main_human = described_class.call(actor: rikki, friendship:, kind: :human)
    main_assistant = described_class.call(actor: rikki, friendship:, kind: :assistant)
    derived_human = described_class.call(actor: rikki, friendship:, kind: :human, scenario_key:)

    expect([ main_human, main_assistant, derived_human ].map(&:id).uniq.size).to eq(3)
    expect(derived_human.scenario_key).to eq(scenario_key)
  end

  it "rejects every non-accepted friendship state" do
    %w[pending rejected blocked removed].each do |state|
      friendship.update!(state:)

      expect { described_class.call(actor: rikki, friendship:, kind: :human) }
        .to raise_error(described_class::UnavailableError) { |error| expect(error.reason).to eq(:friendship_not_accepted) }
    end

    expect(Conversation.where(friendship:)).to be_empty
  end

  it "rejects a missing friendship and an actor outside the friendship" do
    outsider = create(:user, :random)

    expect { described_class.call(actor: rikki, friendship: nil, kind: :human) }
      .to raise_error(described_class::UnavailableError) { |error| expect(error.reason).to eq(:friendship_missing) }
    expect { described_class.call(actor: outsider, friendship:, kind: :human) }
      .to raise_error(described_class::UnavailableError) { |error| expect(error.reason).to eq(:actor_not_participant) }
  end

  it "requires the exact scenario to exist for both friendship users" do
    scenario_key = SecureRandom.uuid
    create(:context, user: rikki, scenario_key:)

    expect { described_class.call(actor: rikki, friendship:, kind: :human, scenario_key:) }
      .to raise_error(described_class::UnavailableError) { |error| expect(error.reason).to eq(:scenario_unavailable) }
    expect(Conversation.where(friendship:, scenario_key:)).to be_empty
  end

  it "rejects unsupported conversation kinds" do
    expect { described_class.call(actor: rikki, friendship:, kind: :group) }
      .to raise_error(described_class::UnavailableError) { |error| expect(error.reason).to eq(:invalid_kind) }
  end
end
