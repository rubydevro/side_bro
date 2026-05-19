# SideBro

A Rack-mountable Sidekiq Web UI alternative with a customizable design.

## Installation

Add to your Gemfile:

```gem "side_bro"```

## Mounting

### Rails

```ruby
# config/routes.rb
require "side_bro"
mount SideBro::Web, at: "/side_bro"
```

### Rack (`config.ru`)

```ruby
require "side_bro"
run SideBro::Web
```

## Authentication

SideBro has no built-in authentication. Wrap it with any Rack middleware:

### HTTP Basic Auth

```ruby
SideBro::Web.use Rack::Auth::Basic, "SideBro" do |user, password|
  [user, password] == ["admin", ENV["SIDE_BRO_PASSWORD"]]
end
```

### Devise (Rails)

```ruby
authenticate :user, ->(u) { u.admin? } do
  mount SideBro::Web, at: "/side_bro"
end
```

## Session Secret

Set `SIDE_BRO_SESSION_SECRET` env var for a stable session secret across restarts.
