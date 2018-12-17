# DomainScraper

This application crawls a url provided by the user and finds all the expired domains which exist on that website. It consists of 6 modules which are contained in an umbrella app (find them in `apps/`).

It requires that a Redis server be running on the local machine (no auth), Postgres with credentials set in `apps/web/config/dev.exs` and the `Lmgtfy` dependency requires `phantomjs` be installed on the system's PATH.

To run it for the first time:

- make sure Redis is running
- go to `apps/web` and run `mix ecto.setup`
- go back to `/` and run `iex -S mix phoenix.server` (this is all you need to run in future)

For a bit more info, see `slides.pdf` - I gave a talk about this at the Melbourne Elixir meetup.

Also, know that this is not ready to go deploy to the public internet, since there are Erlang cookies and secret key bases committed to the codebase. This is just something I built for the lols.

## Finisher

`Finisher` is responsible for finishing things up.

- Every 5 seconds a function is run which finds crawls which are done (find all crawls with no end date, no queued urls/domains that haven't inserted any data to the database in 30 seconds), removes any leftover data from Redis and adds a `finished_at` timestamp to the `crawl`. Any crawl with a `finished_at` is finished and this is how we identify the state of the crawl throughout the application.
- Every 5 seconds a function is run which finds all the expired domain names in the database which don't have all the desired metric data. This happens because the API I use for domain data is dodgy af and sells "pirated" metrics I am pretty sure. It's cheap as fuck though so I just keep hitting it till it gives me the data I want.

Finisher essentially exists because there is no "clean" solution to knowing when a crawl has finished. This is because a website has no discoverable number of URLS for us to compare against (compare the amount crawled).

## Scheduler

`Scheduler` exists to make sure that each particular in progress crawl gets an equal share of system resources.

When a worker wants a new url or domain to check, it asks `Scheduler`. `Scheduler` maintains a Redis Set called `in_progress`, which is simply a list of currently in progress crawls. It uses this list to randomise the crawl a url or domain comes from on each request from a worker.

Alice and Bob both kick off crawls. Alice's crawl has 1,000,000 urls queued, while Bob's only has 73. If the workers were just to grab a random url from Redis, Alice would be getting a significantly larger share of system resources, because her urls are statistically much more likely to be randomly selected (because there are more of them).

## Scraper

This is essentially the "core" of the application. It contains the actual web scraping and domain checking functionality. There is no forever running system in this module, it's just some functions that get called from other modules. This also manages the hackney worker pool (for the `HTTPpoison` HTTP library).

## Store

`Store` wraps Redis (with the `Redix` library), maintains a pool of Redis conenctions and provides easy functions to push/pop and get list length of the various Redis Sets. There are four Redis Sets: `domains_to_check`, `domains_checked`, `to_crawl` and `crawled`. These are namespaced with :crawl_id, so to get all of the urls queued to be crawled for the crawl with id 54, you would look at `to_crawl:54`.

## Web

This is the web interface to the application, built with Phoenix. It also handles Ecto and database stuff which is used throughout.

## Workers

Here is where most of the actual functionality happens. There are two kinds of workers, Url workers and Domain workers. The role of a worker is to get a new thing to process (be it a domain or a url), process it, handle it and then call itself again. If there are no things to process, it waits 1 second and looks again.

In `apps/workers/lib/workers/application.ex` you can see the amount of workers being started up (right now, 200 of each kind). Each worker has it's own supervisor and all of those supervisors are supervised by one other supervisor. This is to prevent issues where (for example) a website's firewall thinks we're DoSing them and blocks all connections. Suddenly a lot of workers will crash in quick sucession. This could overload a single supervisor trying to handle restarting all 400 of them at once, so it's better for each to have their own supervisor.
