// Register only the controllers used by this surface.
import { application } from "./application"

import AccordionController from "./accordion_controller"
import ContactMailController from "./contact_mail_controller"
import EventsSliderController from "./events_slider_controller"
import JobApplicationMailController from "./job_application_mail_controller"
import JobFilterController from "./job_filter_controller"
import JobProfileNavController from "./job_profile_nav_controller"
import LegalPrintController from "./legal_print_controller"
import LegalTabsController from "./legal_tabs_controller"
import MobileMenuController from "./mobile_menu_controller"
import PressLightboxController from "./press_lightbox_controller"
import PressSearchController from "./press_search_controller"
import PressTextCollapseController from "./press_text_collapse_controller"
import ReferenceHeroSliderController from "./reference_hero_slider_controller"
import ReferenceMarqueeController from "./reference_marquee_controller"
import ReferenceMosaicController from "./reference_mosaic_controller"
import ReferenceImageRenderController from "./reference_image_render_controller"
import ScrolledHeaderController from "./scrolled_header_controller"
import ScrollTopController from "./scroll_top_controller"
import ServicesJumpNavController from "./services_jump_nav_controller"
import SliderController from "./slider_controller"
import SmoothAnchorController from "./smooth_anchor_controller"
import TeamCarouselController from "./team_carousel_controller"

application.register("accordion", AccordionController)
application.register("contact-mail", ContactMailController)
application.register("events-slider", EventsSliderController)
application.register("job-application-mail", JobApplicationMailController)
application.register("job-filter", JobFilterController)
application.register("job-profile-nav", JobProfileNavController)
application.register("legal-print", LegalPrintController)
application.register("legal-tabs", LegalTabsController)
application.register("mobile-menu", MobileMenuController)
application.register("press-lightbox", PressLightboxController)
application.register("press-search", PressSearchController)
application.register("press-text-collapse", PressTextCollapseController)
application.register("reference-hero-slider", ReferenceHeroSliderController)
application.register("reference-marquee", ReferenceMarqueeController)
application.register("reference-mosaic", ReferenceMosaicController)
application.register("reference-image-render", ReferenceImageRenderController)
application.register("scrolled-header", ScrolledHeaderController)
application.register("scroll-top", ScrollTopController)
application.register("services-jump-nav", ServicesJumpNavController)
application.register("slider", SliderController)
application.register("smooth-anchor", SmoothAnchorController)
application.register("team-carousel", TeamCarouselController)
