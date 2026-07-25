# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Category colour presentation enforcement", type: :service do
  let(:core_surfaces) do
    %w[
      app/views/budgets/budgets.rb
      app/views/budgets/category_fields.rb
      app/views/budgets/form.rb
      app/views/budgets/show.rb
      app/views/card_installments/index.rb
      app/views/card_transactions/form.rb
      app/views/card_transactions/show.rb
      app/views/cash_installments/index.rb
      app/views/cash_transactions/form.rb
      app/views/cash_transactions/show.rb
      app/views/categories/category.rb
      app/views/category_transactions/fields.rb
      app/views/entities/show.rb
      app/views/investments/month_year.rb
      app/views/lalas/card_installments/index.rb
      app/views/lalas/cash_installments/index.rb
      app/views/subscriptions/subscription.rb
      app/views/transactions/standalone_transactions_sheet.rb
      app/views/user_bank_accounts/show.rb
      app/views/user_cards/show.rb
    ]
  end

  let(:locale_keys) do
    %w[
      categories.colour_accessibility.heading
      categories.colour_accessibility.description
      categories.colour_accessibility.background
      categories.colour_accessibility.background_hint
      categories.colour_accessibility.automatic
      categories.colour_accessibility.automatic_hint
      categories.colour_accessibility.manual
      categories.colour_accessibility.manual_hint
      categories.colour_accessibility.manual_foreground
      categories.colour_accessibility.manual_foreground_hint
      categories.colour_accessibility.contrast
      categories.colour_accessibility.passing
      categories.colour_accessibility.failing
      categories.colour_accessibility.invalid
      categories.colour_accessibility.suggestion
      categories.colour_accessibility.fallback_label
      categories.colour_accessibility.light_preview
      categories.colour_accessibility.dark_preview
      categories.colour_accessibility.states
      categories.colour_accessibility.normal
      categories.colour_accessibility.hover
      categories.colour_accessibility.focus
      categories.colour_accessibility.selected
      categories.colour_accessibility.disabled
      activerecord.attributes.category.colour
      activerecord.attributes.category.text_colour_mode
      activerecord.attributes.category.text_colour
      activerecord.errors.models.category.attributes.text_colour.insufficient_contrast
    ]
  end

  it "keeps legacy foreground guesses and gradient helpers out of application code" do
    expect(application_source).not_to match(/\b(?:auto_text_color|solid_or_gradient_style|ColoursHelper)\b/)
  end

  it "keeps raw category colour access behind the presentation boundary" do
    expect(paths_containing(/\.hex_colour\b/)).to eq([ "app/services/category_colours/presentation.rb" ])

    view_source = source_for(Dir[Rails.root.join("app/views/**/*.{rb,erb}")])
    expect(view_source).not_to match(/\.(?:hex_colour|resolved_text_colour)\b/)
    expect(view_source).not_to match(/\b(?:category|category_record)\.colour\b/)
  end

  it "routes every core category-bearing surface through the shared presentation contract" do
    core_surfaces.each do |relative_path|
      expect(Rails.root.join(relative_path).read).to match(
        /CategoryBadge|CategoryColours::Presentation|CategoryColours::RowPresentation/
      ), "#{relative_path} bypasses the shared category colour presentation contract"
    end
  end

  it "keeps all category-colour copy available in English and Portuguese" do
    %i[en pt-BR].product(locale_keys).each do |locale, key|
      expect(I18n.exists?(key, locale)).to be(true), "missing #{locale}.#{key}"
    end
  end

  it "keeps category pairs intact while styling entities from the row foreground" do
    stylesheet = Rails.root.join("app/assets/tailwind/application.css").read

    expect(stylesheet).to include(
      '[data-category-display-mode] [data-entity-colour="true"]',
      "color: var(--category-row-foreground) !important",
      "border-color: var(--category-row-foreground) !important",
      '[data-category-display-mode] [data-entity-info-text="true"]',
      "color: var(--category-row-info-foreground) !important"
    )
    expect(stylesheet).not_to match(/\[data-category-display-mode[^\]]*\]\s+\[data-category-colour="true"\]/)
  end

  def application_source
    source_for(Dir[Rails.root.join("app/**/*.{rb,erb,js,mjs}")])
  end

  def paths_containing(pattern)
    Dir[Rails.root.join("app/**/*.rb")].filter_map do |path|
      Pathname(path).relative_path_from(Rails.root).to_s if File.read(path).match?(pattern)
    end.sort
  end

  def source_for(paths)
    paths.sort.map { |path| File.read(path) }.join("\n")
  end
end
