export default {
  resource: "admin.adminPlugins",
  path: "/plugins",
  map() {
    this.route("csv-bulk-import");
  },
};
