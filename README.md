# discourse-auto-insert-wiki-plugin

## Requirements
- `Summary` user is exists.

## HOW-TO

### Bulk insert wiki
- Open Rails console
- Enter this code:
```ruby
AutoInsertWiki.new.bulk_insert
```

### Insert wiki to individual topic
- Open Rails console
- Enter this code:
```ruby
AutoInsertWiki.new.insert_wiki(Topic.find(<topic_id>))
```
