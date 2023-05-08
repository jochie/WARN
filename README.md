# Repository Layout

- `src/`
  - `posts/`
	Python code for the `post` Lambda function
  - `report/`
    Python code and requirements for the `report` Lambda function
- `terraform/`
  Terraform that creates infrastructure needed to run this 'serverless' setup
  - An S3 bucket for permanent storage
  - Two SQS queues (the main one, and the dead-letter queue that goes with it)
  - Two Systems Manager Parameter Store entries
  - Two Lambda functions
  - Two CloudWatch log group configurations
  - Various roles/policies that are attached to the Lambda functions to access the resources above
  - A CloudWatch alarm that checks the dead-letter queue
  - An SNS topic to which the alarm sends its alerts
  - An EventBridge "cron" rule for the report Lambda function

# `process_report.py`

This script fetches the California WARN Act listings

https://edd.ca.gov/en/jobs_and_training/Layoff_Services_WARN
https://edd.ca.gov/siteassets/files/jobs_and_training/warn/warn_report.xlsx

# `process_posts`

This is a relatively generic script that is set up as an SQS queue listener and, when there is something there will attempt to post to the Mastodon server of choice, and post a new message to the queue for the next message.

# Logic behind the setup

There are a few reasons behind this setup:

- I'm putting a pause between the posts in a thread (doing one post per notice, and there are have generally been multiple notices on the days that California updates their spreadsheet), to be kind to the server and the folks following the account.
- Lambdas are billed on how long they run, so time is money.
- Lambdas also have limit to how long they can run, so if I put 10-20 seconds each post and there is a crazy number of notices that day, it might run out of time.
- I considered Step Functions but the free limit for state changes per month seems relatively low, and the number of free SQS requests is _much_ higher.

Example:
- On May 4 2023 there were 25 WARN notices.
- The `report` Lambda ran for 8 seconds
- The first 'post' Lambda ran for 2 seconds, the next 23 runs were under a second, and the last one 1.2 seconds.
- All together that that was 34-35 seconds of Lambda runtime, versus 250+ seconds if it had been attempted in a single Lambda run

# Links to WARN Notice websites of other states

* Florida: https://floridajobs.org/office-directory/division-of-workforce-services/workforce-programs/worker-adjustment-and-retraining-notification-(warn)-act
* Kansas: https://www.kansascommerce.gov/program/workforce-services/warn/
  Could potentially check incremental values here and stop when we get a 404 page?
    https://www.kansasworks.com/search/warn_lookups/2192
* Oregon: https://www.oregon.gov/highered/institutions-programs/workforce/Pages/warn.aspx
  https://ccwd.hecc.oregon.gov/Layoff/WARN?page=<d>
  This website may be blocking requests from outside the US?
* Nevada: https://detr.nv.gov/Page/WARN
* Texas: https://www.twc.texas.gov/businesses/worker-adjustment-and-retraining-notification-warn-notices
* Washington: https://esd.wa.gov/about-employees/WARN
