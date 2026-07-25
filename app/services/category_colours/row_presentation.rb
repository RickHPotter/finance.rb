# frozen_string_literal: true

class CategoryColours::RowPresentation
  APPLICATION_ROW_CLASSES = "bg-white text-slate-900 dark:bg-slate-900 dark:text-slate-100"
  APPLICATION_BACKGROUND_CLASSES = "bg-white dark:bg-slate-900"

  attr_reader :bundle, :mode

  def initialize(categories:, mode: CategoryColours::DisplayMode::DEFAULT)
    @bundle = CategoryColours::Presentation.bundle(categories)
    @mode = CategoryColours::DisplayMode.resolve(mode)
  end

  def row_coloured?
    mode == CategoryColours::DisplayMode::ROW_COLOURED && primary_segment.present?
  end

  def badges_only?
    !row_coloured?
  end

  def row_style
    primary_presentation&.inline_style if row_coloured?
  end

  def row_classes
    APPLICATION_ROW_CLASSES if badges_only?
  end

  def background_classes
    APPLICATION_BACKGROUND_CLASSES if badges_only?
  end

  def badge_style(category)
    CategoryColours::Presentation.for(category).inline_style
  end

  def primary_category_key
    primary_segment&.key
  end

  def metadata
    {
      category_display_mode: mode,
      category_primary_id: primary_category_key
    }.compact
  end

  private

  def primary_segment
    bundle.segments.first
  end

  def primary_presentation
    primary_segment&.presentation
  end
end
