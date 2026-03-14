import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "optionContainer", "option", "selectedValue", "indicator",
    "customInput", "hexField"
  ]

  connect() {
    this.apply(this.selectedValueTarget.value)
  }

  toggle() { this.optionContainerTarget.classList.toggle("hidden") }

  selectColour({ target }) {
    const value = target.dataset.value
    this.selectedValueTarget.value = value
    this.apply(value)
    this.optionContainerTarget.classList.add("hidden")
  }

  pickCustom(event) {
    const hex = event.target.value
    this.hexFieldTarget.value = hex
    this.selectedValueTarget.value = hex
    this.apply(hex)
  }

  hexChanged(event) {
    const hex = event.target.value
    if (this.isValidHex(hex)) {
      this.selectedValueTarget.value = hex
      this.apply(hex)
    }
  }

  apply(value) {
    const text = this.autoTextColor(value)
    this.indicatorTarget.style.backgroundColor = value
    this.indicatorTarget.style.color = text
    this.indicatorTarget.dataset.text = text
    this.indicatorTarget.className = "w-10 h-10 rounded-full border border-slate-200"
  }

  autoTextColor(hex) {
    const h = hex.replace('#','');
    const full = h.length === 3 ? h.split('').map(c=>c+c).join('') : h;
    const r = parseInt(full.slice(0,2),16)/255;
    const g = parseInt(full.slice(2,4),16)/255;
    const b = parseInt(full.slice(4,6),16)/255;
    const lin = [r,g,b].map(v => v <= 0.03928 ? v/12.92 : Math.pow((v+0.055)/1.055, 2.4));
    const L = 0.2126*lin + 0.7152*lin[1] + 0.0722*lin[2];
    const cw = (1.05)/(L+0.05);
    const cb = (L+0.05)/0.05;
    return cb >= cw ? '#000000' : '#ffffff';
  }

  hexToRgb(hex) {
    let h = hex.replace("#","")
    if (h.length === 3) h = h.split("").map(c => c+c).join("")
    const num = parseInt(h, 16)
    return { r: (num >> 16) & 255, g: (num >> 8) & 255, b: num & 255 }
  }

  isValidHex(h) { return /^#?([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$/.test(h) }
}
