import Badge from "discourse/models/badge";
import I18n from "I18n";
import Route from "@ember/routing/route";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import { get } from "@ember/object";
import showModal from "discourse/lib/show-modal";

export default Route.extend({
  serialize(m) {
    return { badge_id: get(m, "id") || "new" };
  },

  model(params) {
    if (params.badge_id === "new") {
      return Badge.create({
        name: I18n.t("admin.badges.new_badge"),
      });
    }
    return this.modelFor("adminBadges").findBy(
      "id",
      parseInt(params.badge_id, 10)
    );
  },

  setupController(controller, model) {
    this._super(...arguments);
    if (model.image_url) {
      controller.showImageUploader();
    } else if (model.icon) {
      controller.showIconSelector();
    }
  },

  actions: {
    editGroupings() {
      const model = this.controllerFor("admin-badges").get("badgeGroupings");
      showModal("admin-edit-badge-groupings", { model, admin: true });
    },

    preview(badge, explain) {
      badge.set("preview_loading", true);
      ajax("/admin/badges/preview.json", {
        type: "POST",
        data: {
          sql: badge.get("query"),
          target_posts: !!badge.get("target_posts"),
          trigger: badge.get("trigger"),
          explain,
        },
      })
        .then(function (model) {
          badge.set("preview_loading", false);
          showModal("admin-badge-preview", { model, admin: true });
        })
        .catch(function (error) {
          badge.set("preview_loading", false);
          // eslint-disable-next-line no-console
          console.error(error);
          bootbox.alert("Network error");
        });
    },
  },
});
