# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Ledger namespace enforcement", type: :service do
  let(:production_paths) do
    Dir[
      Rails.root.join("app/controllers/ledgers{,/**/*}.rb"),
      Rails.root.join("app/services/ledgers{,/**/*}.rb"),
      Rails.root.join("app/views/ledgers{,/**/*}.rb")
    ]
  end

  it "keeps one ledger namespace without obsolete Lalas production views" do
    expect(Dir[Rails.root.join("app/views/lalas/**/*")].select { |path| File.file?(path) }).to be_empty
    expect(source_for(production_paths)).not_to match(/Views::Lalas|\bLalas(?:Controller|::)/)
  end

  it "keeps unstable identity discovery out of canonical ledger code" do
    canonical_paths = production_paths.excluding(Rails.root.join("app/services/ledgers/access/legacy_internal.rb").to_s)
    canonical_source = source_for(canonical_paths)

    expect(canonical_source).not_to match(/\bUser\.(?:first|take|all\b)/)
    expect(canonical_source).not_to match(/entity_name\.parameterize|Entity\.all/)

    compatibility_source = Rails.root.join("app/services/ledgers/access/legacy_internal.rb").read
    expect(compatibility_source).to include("Entity.where(user_id: user.id)")
    expect(compatibility_source).not_to match(/\bUser\.|Entity\.all/)
  end

  private

  def source_for(paths)
    paths.sort.map { |path| File.read(path) }.join("\n")
  end
end
