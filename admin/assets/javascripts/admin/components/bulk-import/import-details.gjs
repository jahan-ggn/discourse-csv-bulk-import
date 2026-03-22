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
      <div class="import-details error-section">
        <div class="details-header">
          {{icon "triangle-exclamation"}}
          <h4>{{i18n "csv_bulk_import.details.errors"}}</h4>
        </div>
        <ul class="details-list">
          {{#each this.groupedDetails.errors as |item|}}
            <li class="detail-error">
              <span class="detail-topic">Topic
                {{item.topic_external_id}}:</span>
              <span class="detail-message">{{item.message}}</span>
            </li>
          {{/each}}
        </ul>
      </div>
    {{/if}}

    {{#if this.hasSkipped}}
      <div class="import-details skipped-section">
        <div class="details-header">
          {{icon "forward"}}
          <h4>{{i18n "csv_bulk_import.details.skipped"}}</h4>
        </div>
        <ul class="details-list">
          {{#each this.groupedDetails.skipped as |item|}}
            <li class="detail-skipped">
              <span class="detail-topic">Topic
                {{item.topic_external_id}}:</span>
              <span class="detail-message">{{item.message}}</span>
            </li>
          {{/each}}
        </ul>
      </div>
    {{/if}}
  </template>
}
