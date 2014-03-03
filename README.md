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
bundle exec rake db:seed
bundle exec rails server [-p PORT]
open http://localhost:3000
```
