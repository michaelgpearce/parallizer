# Parallizer - Execute your service layer in parallel

Parallizer executes service methods in parallel, stores the method results, then creates a proxy of your service with those results. Your application then uses the short-lived service proxy (think of a single request for a web application) and executes your methods without again calling the underlying implementation. For applications that make considerable use of web service calls, Parallizer can give you a considerable performance boost.

## Installation

    gem install parallizer

## Examples

### Parallizing a service object

Here's an example service.

```ruby
require 'net/http'
require 'nokogiri'

class SearchService
  def top_urls_for_foo
    parse_search_result_for_urls(Net::HTTP.get('www.google.com', '/search?q=foo'))
  end
  
  def top_urls_for_bar
    parse_search_result_for_urls(Net::HTTP.get('www.google.com', '/search?q=foo'))
  end
  
  private
  
  def parse_search_result_for_urls(content)
    Nokogiri::HTML.parse(content).search('h3.r > a').collect(&:attributes).collect{ |attrs| attrs['href'].value }
  end
end

$search_service = SearchService.new
```

Now create a Parallizer for that service and add all of the methods you intend to call. Then execute the service methods in parallel and return a service proxy that has the stored results of the method calls.

```ruby
require 'parallizer'

parallizer = Parallizer.new($search_service)
parallizer.add.top_urls_for_foo
parallizer.add.top_urls_for_bar
search_service = parallizer.execute
```

Now use that service proxy in your application logic.

```ruby
puts search_service.top_urls_for_foo
puts search_service.top_urls_for_bar
```

Additional calls in your application logic will not result in an additional call to the underlying service.

```ruby
# Called twice, but no extra service call. (Be careful not to mutate the returned object!)
puts search_service.top_urls_for_foo
puts search_service.top_urls_for_foo
```

If there are additional methods on your service that were not parallized, you can still call them.

```ruby
puts search_service.top_urls_for_foobar # does a Net::HTTP.get call
```

### Parallizing methods with parameters

Parallizing also works on service methods with parameters.

```ruby
require 'net/http'
require 'nokogiri'

class SearchService
  def top_urls(search_term)
    parse_search_result_for_urls(Net::HTTP.get('www.google.com', "/search?q=#{CGI.escape(search_term)}"))
  end
  
  private
  
  def parse_search_result_for_urls(content)
    Nokogiri::HTML.parse(content).search('h3.r > a').collect(&:attributes).collect{ |attrs| attrs['href'].value }
  end
end

$search_service = SearchService.new
```

The parallel execution and proxy creation.

```ruby
require 'parallizer'

parallizer = Parallizer.new($search_service)
parallizer.add.top_urls('foo')
parallizer.add.top_urls('bar')
search_service = parallizer.execute
```

Using the service proxy in your application logic.

```ruby
puts search_service.top_urls('foo') # returns stored value
puts search_service.top_urls('bar') # returns stored value
puts search_service.top_urls('foobar') # does a Net::HTTP.get call
```


### Parallizing class methods

You can even parallize class methods.

```ruby
require 'net/http'
require 'parallizer'

parallizer = Parallizer.new(Net::HTTP)
parallizer.add.get('www.google.com', '/?q=foo')
parallizer.add.get('www.google.com', '/?q=bar')
http_service = parallizer.execute
```

Use the service proxy.

```ruby
# use your service proxy
http_service.get('www.google.com', '/search?q=foo') # returns stored value
http_service.get('www.google.com', '/search?q=bar') # returns stored value
http_service.get('www.google.com', '/search?q=foobar') # does a Net::HTTP.get call
```


# Credits

[Parallizer](https://github.com/michaelgpearce/parallizer) is maintained by [Michael Pearce](http://github.com/michaelgpearce) and is funded by [Rafter](http://www.rafter.com "Rafter").

![Rafter Logo](http://rafter-logos.s3.amazonaws.com/rafter_github_logo.png "Rafter")

# Copyright

Copyright (c) 2012 Michael Pearce, Bookrenter.com. See LICENSE.txt for further details.

