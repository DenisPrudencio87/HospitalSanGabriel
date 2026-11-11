import { Component, input } from '@angular/core';

@Component({
  selector: 'app-errors',
  template: `@if (field()().touched()) {
    @for (error of field()().errors(); track $index) {
      <small class="field-error">{{ error.message || 'Revise este campo' }}</small>
    }
  }`,
})
export class Errors {
  field = input.required<any>();
}
