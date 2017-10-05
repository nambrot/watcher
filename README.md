# Watcher

Watcher was started with the idea that having an expressive cross-platform data modelling layer can enable an ecosystem of more advanced data analysis tools that currently would require significant investments that only happen within larger, more resourceful organizations. Watcher is inspired by [Looker](https://looker.com/), but aims to have an open source foundation. Also see my [blog post](https://nambrot.com/posts/28-higher-level-data-model-wanted/)

# The problem

Let's say you have a traditional CRUD app in Rails or Django. Your model layer will be the representation of real world concepts that your users are entering and querying in the system. The problem now arises if you need to query your data from a different service or platform. More often than not, you'll end up eith either with a hacked-together attempt to mirror the data model or worse with a full error-prone ETL pipeline that transforms your transactional data into a analytical data ware house. How cool would it be if we could specify a reusable data model that can power all these workloads?

# The solution

With an expressive data modelling specification we can:

- Write exporters that can take existing data models in various libraries and frameworks and create a canonical data model from it
- Write importers that can take that specification and automatically create the models in the target framework

The repo provides a proof of concept for this for a Rails -> SQLAlchemy converstion:

The Rails-based exporter that takes your ActiveRecord models, turns them into a JSON-based representation. So for [discourse/discourse](https://github.com/discourse/discourse), that would look like

```ruby
Watcher.new([Post, Topic, Category]).serializable_hash
```

Which can then be turned into SQLAlchemy ORM models via:

```python
from Watcher import produce_models
import json
with open("data.json") as file:
  print(
    produce_models(
      'models',
      json.load(
        file
      )
    )
  )
```

So that you can use those SQLAlchemy models to run:

```python
session
  .query(func.count(Post.id), Category.name)
  .join(Post.topic)
  .join(Topic.category)
  .group_by(Category.id)
  .all()
```

# The opportunity

While the ability to port your data models can be huge for some organizations, I think the really exciting opportunity lies ahead for developers to build applications on top of this data model specification. Whereas nowadays, organizations only build these abstraction with considerable effort and specific to their stack/setup, the community can benefit from this abstraction layer by not having to think about how to model business concepts and how they relate to each other. This opens up exciting applications for tools like metabase/superset to become JOIN aware, but also NLP-like applications that you can query your voice using your native concepts.
