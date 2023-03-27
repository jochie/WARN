# About `process_report.py`

This script has the ability to fetch the California WARN Act listings

https://edd.ca.gov/en/jobs_and_training/Layoff_Services_WARN
https://edd.ca.gov/siteassets/files/jobs_and_training/warn/warn_report.xlsx

Other states do this slightly differently, so you will probably need to write
something completely new to handle them.

# Other States

* Florida: https://floridajobs.org/office-directory/division-of-workforce-services/workforce-programs/worker-adjustment-and-retraining-notification-(warn)-act
* Kansas: https://www.kansascommerce.gov/program/workforce-services/warn/
  Could potentially check incremental values here and stop when we get a 404 page?
    https://www.kansasworks.com/search/warn_lookups/2192
* Oregon: https://www.oregon.gov/highered/institutions-programs/workforce/Pages/warn.aspx
* Nevada: https://detr.nv.gov/Page/WARN
* Texas: https://www.twc.texas.gov/businesses/worker-adjustment-and-retraining-notification-warn-notices
* Washington: https://esd.wa.gov/about-employees/WARN
