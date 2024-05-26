const MONTHS_FULL = ["Janvier", "Fevrier", "Mars", "Avril", "Mai", "June", "Jui", "Aout", "Septembre", "Octobre", "Novembre", "Decembre"];
const MONTHS_ABBR = ["Jan", "Fev", "Mars", "Avril", "Mai", "June", "Jui", "Aout", "Sept", "Oct", "Nov", "Dec"];

class RefMonthYear {
  constructor(month, year) {
    this.month = month;
    this.year = year % 100;
  }

  monthYear() {
    return `${MONTHS_ABBR[this.month].toUpperCase()} <${this.year}>`;
  }
}

export default RefMonthYear
