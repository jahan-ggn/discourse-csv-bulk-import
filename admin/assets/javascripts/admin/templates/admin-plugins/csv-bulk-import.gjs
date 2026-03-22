import { i18n } from "discourse-i18n";
import BulkImportUploader from "../../components/bulk-import-uploader";

export default <template>
  <div class="admin-csv-bulk-import">
    <h2>{{i18n "csv_bulk_import.title"}}</h2>
    <BulkImportUploader />
  </div>
</template>
