Depstack
========

Configuration
---------------

Create a `config/application.yml` with your credentials:

```yaml
ALGOLIA_APPLICATION_ID: YourApplicationID
ALGOLIA_API_KEY: YourApiKey
ALGOLIA_SEARCH_ONLY_API_KEY: YourSearchOnlyApiKey
GITHUB_KEY: YourClientId
GITHUB_SECRET: YourClientSecret
```

Installation
------------

```sh
bundle install --without production
bundle exec rake db:migrate
bundle exec rake db:seed # TAKES SEVERAL DAYS (Hit Ctrl+C after a few minutes)
bundle exec rails server [-p PORT]
open http://localhost:3000
```

Contribution
-------------

Want to add a new packages manager? Check out how we added Go: [e92db88687](https://github.com/algolia/depstack/commit/e92db88687089769f2d45189a2391f963e2a9de1)
