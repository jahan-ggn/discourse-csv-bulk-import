# frozen_string_literal: true

DiscourseCsvBulkImport::Engine.routes.draw do
  get "/examples" => "examples#index"
  # define routes here
end

Discourse::Application.routes.draw { mount ::DiscourseCsvBulkImport::Engine, at: "discourse-csv-bulk-import" }
