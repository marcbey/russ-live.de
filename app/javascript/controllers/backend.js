// Register only the controllers used by this surface.
import { application } from "./application"

import BackendListFocusController from "./backend_list_focus_controller"
import BackendSortableListController from "./backend_sortable_list_controller"
import FilterClearController from "./filter_clear_controller"
import ReferenceImageCropPreviewController from "./reference_image_crop_preview_controller"

application.register("backend-list-focus", BackendListFocusController)
application.register("backend-sortable-list", BackendSortableListController)
application.register("filter-clear", FilterClearController)
application.register("reference-image-crop-preview", ReferenceImageCropPreviewController)
