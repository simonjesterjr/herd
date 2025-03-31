# Herd

Herd is a powerful workflow management system that helps you organize and execute complex workflows. It provides a robust framework for defining, managing, and executing workflows with dependencies, making it perfect for complex task orchestration.

## Features

- Workflow definition and management
- Dependency handling
- Redis-based job queue
- Graph visualization of workflows
- CLI interface for workflow management
- JSON-based workflow configuration

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'herd'
```

And then execute:

```bash
$ bundle install
```

Or install it yourself as:

```bash
$ gem install herd
```

## Usage

### Basic Configuration

```ruby
require 'herd'

Herd.configure do |config|
  config.redis_url = 'redis://localhost:6379/0'
  config.herdfile = 'Herdfile'
end
```

### Defining a Workflow

```ruby
# Herdfile
workflow :deploy do
  job :build do
    command 'bundle exec rake build'
  end

  job :test do
    command 'bundle exec rake test'
    depends_on :build
  end

  job :deploy do
    command 'bundle exec rake deploy'
    depends_on :test
  end
end
```

### Running Workflows

```bash
$ herd run deploy
```

## Development

### Prerequisites

- Ruby 2.6.0 or higher
- Redis server running locally (or accessible via network)
- Graphviz (for workflow visualization)

### Local Development Setup

1. Clone the repository:
```bash
git clone https://github.com/yourusername/herd.git
cd herd
```

2. Install dependencies:
```bash
bundle install
```

3. Run the tests:
```bash
bundle exec rake test
```

### Working with the Gem Locally

There are several ways to work with the gem during development:

1. **Using Bundler's Local Path**
   Add this to your application's Gemfile:
   ```ruby
   gem 'herd', path: '/path/to/herd'
   ```
   Then run `bundle install`. This will use the local version of the gem.

2. **Building and Installing the Gem**
   ```bash
   # Build the gem
   gem build herd.gemspec
   
   # Install it locally
   gem install ./herd-0.1.0.gem
   ```

3. **Using Bundler's Git Source**
   Add this to your application's Gemfile:
   ```ruby
   gem 'herd', git: 'https://github.com/yourusername/herd.git'
   ```
   Then run `bundle install`.

### Running Tests

The tests can be run without building the gem by using Bundler's local path feature. The test suite is set up to load the gem directly from the source code.

1. **Run all tests:**
   ```bash
   bundle exec rake test
   ```

2. **Run specific test file:**
   ```bash
   bundle exec ruby -I test test/herd/workflow_test.rb
   ```

3. **Run with specific test:**
   ```bash
   bundle exec ruby -I test test/herd/workflow_test.rb -n test_status_returns_failed_when_failed
   ```

### Test Dependencies

The test suite requires:
- Redis running locally (or accessible via network)
- Sidekiq (for job queue testing)
- Minitest (included in Ruby standard library)

### Debugging

To debug the gem locally:

1. Add the `debug` gem to your Gemfile:
   ```ruby
   gem 'debug'
   ```

2. Add breakpoints in your code:
   ```ruby
   require 'debug'
   debugger
   ```

3. Run your tests or code with the debugger:
   ```bash
   bundle exec ruby -I test test/herd/workflow_test.rb
   ```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -am 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Bug reports and pull requests are welcome on GitHub.

## License

The gem is available as open source under the terms of the MIT License.
