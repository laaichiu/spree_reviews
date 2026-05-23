import { Application, Controller } from '@hotwired/stimulus'

let application

if (typeof window.Stimulus === 'undefined') {
  application = Application.start()
  application.debug = false
  window.Stimulus = application
} else {
  application = window.Stimulus
}

class SlugFieldController extends Controller {
  static targets = ['source', 'slug']

  connect() {
    this.autoSync = this.hasSlugTarget && this.slugTarget.value.trim() === ''
  }

  sync() {
    if (!this.hasSourceTarget || !this.hasSlugTarget || !this.autoSync) return

    this.slugTarget.value = this.slugify(this.sourceTarget.value)
  }

  markManual() {
    if (!this.hasSlugTarget) return

    this.autoSync = this.slugTarget.value.trim() === ''
  }

  slugify(value) {
    return value
      .normalize('NFKD')
      .replace(/[\u0300-\u036f]/g, '')
      .toLowerCase()
      .trim()
      .replace(/['’]/g, '')
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '')
  }
}

application.register('spree-reviews-slug-field', SlugFieldController)
