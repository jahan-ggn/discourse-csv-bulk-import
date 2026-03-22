import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class UploadZone extends Component {
  @tracked dragOver = false;

  get fileName() {
    return this.args.file?.name;
  }

  get fileSize() {
    const bytes = this.args.file?.size;
    if (!bytes) {
      return null;
    }
    if (bytes < 1024 * 1024) {
      return `${(bytes / 1024).toFixed(1)} KB`;
    }
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
  }

  @action
  onDragOver(event) {
    event.preventDefault();
    this.dragOver = true;
  }

  @action
  onDragLeave(event) {
    event.preventDefault();
    this.dragOver = false;
  }

  @action
  onDrop(event) {
    event.preventDefault();
    this.dragOver = false;
    const droppedFile = event.dataTransfer.files[0];
    if (droppedFile?.name.endsWith(".zip")) {
      this.args.onFileSelected(droppedFile);
    }
  }

  @action
  onFileChange(event) {
    const file = event.target.files[0];
    if (file) {
      this.args.onFileSelected(file);
    }
  }

  <template>
    <div
      class="upload-zone
        {{if this.dragOver 'drag-over'}}
        {{if this.fileName 'has-file'}}"
      {{on "dragover" this.onDragOver}}
      {{on "dragleave" this.onDragLeave}}
      {{on "drop" this.onDrop}}
    >
      {{#if this.fileName}}
        <div class="upload-zone-selected">
          {{icon "file-zipper"}}
          <div class="file-info">
            <span class="file-name">{{this.fileName}}</span>
            <span class="file-size">{{this.fileSize}}</span>
          </div>
        </div>
      {{else}}
        <div class="upload-zone-empty">
          {{icon "cloud-arrow-up"}}
          <p class="drop-text">{{i18n "csv_bulk_import.drop_zone"}}</p>
          <label class="choose-file-label">
            <input
              type="file"
              accept=".zip"
              class="choose-file-input"
              {{on "change" this.onFileChange}}
            />
            <span class="btn btn-default">{{icon "folder-open"}}
              {{i18n "csv_bulk_import.choose_file"}}</span>
          </label>
        </div>
      {{/if}}
    </div>

    <div class="upload-actions">
      {{#if this.fileName}}
        <DButton
          @icon="upload"
          @label="csv_bulk_import.upload_button"
          @action={{@onUpload}}
          class="btn-primary btn-large"
        />
        <label class="change-file-label">
          <input
            type="file"
            accept=".zip"
            class="choose-file-input"
            {{on "change" this.onFileChange}}
          />
          <span class="btn btn-default">{{i18n
              "csv_bulk_import.change_file"
            }}</span>
        </label>
      {{/if}}
    </div>
  </template>
}
