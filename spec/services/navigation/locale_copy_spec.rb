# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Navigation locale copy", type: :service do
  let(:copy_roots) { %i[tabs navigation confirmation] }

  before { I18n.backend.send(:init_translations) }

  it "keeps English and Portuguese navigation copy structurally complete" do
    expect(locale_keys(:en, copy_roots)).to eq(locale_keys(:"pt-BR", copy_roots))
  end

  it "keeps English and Portuguese model validation labels structurally complete" do
    roots = [ %i[activerecord attributes] ]

    expect(locale_keys(:en, roots)).to eq(locale_keys(:"pt-BR", roots))
  end

  def locale_keys(locale, roots)
    translations = I18n.backend.send(:translations).fetch(locale)

    roots.flat_map do |root|
      path = Array(root)
      leaf_keys(translations.dig(*path), path.join("."))
    end.sort
  end

  def leaf_keys(value, prefix)
    value.flat_map do |key, child|
      path = "#{prefix}.#{key}"
      child.is_a?(Hash) ? leaf_keys(child, path) : path
    end
  end
end
