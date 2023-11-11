# frozen_string_literal: true

# PORO Class for creating a Reference of MonthYear
class RefMonthYear
  attr_reader :month, :year

  # TODO: move these to initialiser.rb
  @months_full = %w[Janvier Fevrier Mars Avril Mai June Jui Aout Septembre Octobre Novembre Decembre]
  @months = %w[Jan Fev Mars Avril Mai June Jui Aout Sept Oct Nov Dec]

  def initialize(month, year)
    @month = month
    @year = year
  end

  # Reads the attributes and returns in a given format, uppercase
  #
  # @return [String] Month Year in a MONTH <YEAR> format
  def month_year
    "#{@months[@month + 1].uppercase} <#{@year}>"
  end
end
