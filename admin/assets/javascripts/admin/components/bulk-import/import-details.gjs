import Component from "@glimmer/component";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class ImportDetails extends Component {
  get groupedDetails() {
    const errors = [];
    const skipped = [];
    this.args.details?.forEach((item) => {
      if (item.type === "skipped") {
        skipped.push(item);
      } else {
        errors.push(item);
      }
    });
    return { errors, skipped };
  }

  get hasErrors() {
    return this.groupedDetails.errors.length > 0;
  }

  get hasSkipped() {
    return this.groupedDetails.skipped.length > 0;
  }

  <template>
    {{#if this.hasErrors}}
      <div class="import-details import-details--errors">
        <div class="import-details__header">
          {{icon "triangle-exclamation"}}
          <h4>{{i18n "csv_bulk_import.details.errors"}}</h4>
        </div>
        <ul class="import-details__list">
          {{#each this.groupedDetails.errors as |item|}}
            <li class="import-details__item import-details__item--error">
              <span class="import-details__topic">Topic
                {{item.topic_external_id}}:</span>
              <span class="import-details__message">{{item.message}}</span>
            </li>
          {{/each}}
        </ul>
      </div>
    {{/if}}

    {{#if this.hasSkipped}}
      <div class="import-details import-details--skipped">
        <div class="import-details__header">
          {{icon "forward"}}
          <h4>{{i18n "csv_bulk_import.details.skipped"}}</h4>
        </div>
        <ul class="import-details__list">
          {{#each this.groupedDetails.skipped as |item|}}
            <li class="import-details__item import-details__item--skipped">
              <span class="import-details__topic">Topic
                {{item.topic_external_id}}:</span>
              <span class="import-details__message">{{item.message}}</span>
            </li>
          {{/each}}
        </ul>
      </div>
    {{/if}}
  </template>
}
