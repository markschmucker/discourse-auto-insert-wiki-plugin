import { withPluginApi } from "discourse/lib/plugin-api";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";
import { schedule } from "@ember/runloop";
import { htmlSafe } from "@ember/template";

function initWithApi(api) {
  api.decorateCooked(
    (cooked) => {
      Ember.run.next(cooked, function () {
        const el = this.find("strong:contains(wiki_edit_btn)");
        const topic = $("#topic");

        if (el.length && topic.length) {
          const parent = el.parent("p");

          const btn = $(
            `<button class="btn btn-large btn-primary">Add Summary</button>`
          );

          const topicId = topic.data("topic-id");

          btn.click(() => {
            if ($(this).hasClass("disabled")) return;

            const dialogMessage =
              "You are about to add a blank Summary template to this topic. Please do this only if you will contribute to the summary. Are you sure?";
            schedule("afterRender", () => {
              // delay needed so that the dialog service is loaded
              const dialog =
                getOwnerWithFallback(this).lookup("service:dialog");
              dialog.yesNoConfirm({
                message: htmlSafe(dialogMessage),
                didConfirm: () => {
                  $(this).addClass("disabled");

                  ajax("/auto-insert-wiki", {
                    type: "POST",
                    data: { id: topicId },
                  })
                    .then((result) => {
                      //console.log(result);
                    })
                    .catch(popupAjaxError)
                    .finally(() => {
                      $(this).removeClass("disabled");
                    });
                },
              });
            });
          });

          parent.html(btn);
        }
      });
    },
    { onlyStream: true }
  );
}

export default {
  name: "auto-insert-wiki",
  initialize() {
    withPluginApi("0.8", initWithApi);
  },
};
